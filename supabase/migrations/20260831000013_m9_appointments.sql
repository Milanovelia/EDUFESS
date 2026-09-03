-- ==========================================================================
-- EduFess — M9 Appointments (BK)
-- Creates counselor_availability and bk_appointments with privacy-safe
-- projections and role-separated RPCs.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- counselor_availability
-- --------------------------------------------------------------------------
create table public.counselor_availability (
  id uuid primary key default gen_random_uuid(),
  counselor_id uuid not null references public.profiles (id) on delete cascade,
  available_date date not null,
  start_time time not null,
  end_time time not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_time < end_time),
  check (available_date >= '2020-01-01'::date)
);

comment on table public.counselor_availability is 'Counselor available slots, BK only.';

create unique index counselor_availability_no_dup on public.counselor_availability (counselor_id, available_date, start_time, end_time) where is_active;
create index counselor_availability_counselor_id_idx on public.counselor_availability (counselor_id);
create index counselor_availability_date_idx on public.counselor_availability (available_date) where is_active;

create trigger counselor_availability_touch_updated_at
  before update on public.counselor_availability
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------------------
-- bk_appointments
-- --------------------------------------------------------------------------
create table public.bk_appointments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  counselor_id uuid not null references public.profiles (id) on delete cascade,
  conversation_id uuid references public.counseling_conversations (id) on delete set null,
  availability_id uuid references public.counselor_availability (id) on delete set null,
  requested_start_at timestamptz not null,
  requested_end_at timestamptz not null,
  scheduled_start_at timestamptz,
  scheduled_end_at timestamptz,
  status text not null check (status in ('pending','accepted','rejected','cancelled','completed')),
  student_note text check (student_note is null or char_length(student_note) between 1 and 1000),
  counselor_note text check (counselor_note is null or char_length(counselor_note) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  completed_at timestamptz,
  check (requested_start_at < requested_end_at),
  check (scheduled_start_at is null or scheduled_end_at is null or scheduled_start_at < scheduled_end_at),
  check (char_length(student_note) <= 1000),
  check (char_length(counselor_note) <= 1000)
);

comment on table public.bk_appointments is 'BK appointments, private to participants, alias-only for counselor queue.';

create index bk_appointments_student_id_idx on public.bk_appointments (student_id);
create index bk_appointments_counselor_id_idx on public.bk_appointments (counselor_id);
create index bk_appointments_status_idx on public.bk_appointments (status);
create index bk_appointments_availability_id_idx on public.bk_appointments (availability_id) where availability_id is not null;
-- Prevent double booking same availability while active
create unique index bk_appointments_one_active_per_availability
  on public.bk_appointments (availability_id)
  where availability_id is not null and status in ('pending','accepted');

create trigger bk_appointments_touch_updated_at
  before update on public.bk_appointments
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.counselor_availability enable row level security;
alter table public.bk_appointments enable row level security;

-- counselor_availability: counselor own, student via RPC only (no direct select for student)
create policy counselor_availability_select_own on public.counselor_availability for select to authenticated using (counselor_id = auth.uid());
create policy counselor_availability_insert_own on public.counselor_availability for insert to authenticated with check (counselor_id = auth.uid());
create policy counselor_availability_update_own on public.counselor_availability for update to authenticated using (counselor_id = auth.uid()) with check (counselor_id = auth.uid());
create policy counselor_availability_delete_own on public.counselor_availability for delete to authenticated using (counselor_id = auth.uid());

-- bk_appointments: student own, counselor own
create policy bk_appointments_select_student on public.bk_appointments for select to authenticated using (student_id = auth.uid());
create policy bk_appointments_select_counselor on public.bk_appointments for select to authenticated using (counselor_id = auth.uid());
create policy bk_appointments_insert_student on public.bk_appointments for insert to authenticated with check (student_id = auth.uid());
-- No direct update/delete; use RPCs

-- --------------------------------------------------------------------------
-- Helper: check counselor role
-- --------------------------------------------------------------------------
create or replace function public.is_counselor(p_uid uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(select 1 from public.profiles where id = p_uid and role = 'counselor');
$$;

create or replace function public.is_student(p_uid uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select exists(select 1 from public.profiles where id = p_uid and role = 'student');
$$;

-- --------------------------------------------------------------------------
-- create_counselor_availability
-- --------------------------------------------------------------------------
create or replace function public.create_counselor_availability(p_available_date date, p_start_time time, p_end_time time)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  if p_available_date is null or p_start_time is null or p_end_time is null then raise exception 'Invalid slot.'; end if;
  if p_start_time >= p_end_time then raise exception 'Invalid time.'; end if;
  if p_available_date < current_date then raise exception 'Past slot.'; end if;
  -- also check time not in past if today
  if p_available_date = current_date and p_start_time <= current_time then raise exception 'Past slot.'; end if;
  insert into public.counselor_availability (counselor_id, available_date, start_time, end_time, is_active)
  values (v_uid, p_available_date, p_start_time, p_end_time, true) returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'Slot sudah ada.';
end;
$$;

-- --------------------------------------------------------------------------
-- get_available_counseling_slots
-- --------------------------------------------------------------------------
create or replace function public.get_available_counseling_slots()
returns table (availability_id uuid, available_date date, start_time time, end_time time, counselor_display text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  -- Only student with consent can see slots (enforce consent)
  if not exists(select 1 from public.profiles where id=v_uid and role='student') then
    -- allow student only, but also counselor/admin might call? For now allow any authenticated student
    if not public.is_student(v_uid) then raise exception 'Not authorized.'; end if;
  end if;
  if not exists(select 1 from public.bk_consents where student_id=v_uid and version='bk-consent-v1' and revoked_at is null) then
    raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
  end if;
  return query
    select ca.id as availability_id, ca.available_date, ca.start_time, ca.end_time, 'Guru BK'::text as counselor_display
    from public.counselor_availability ca
    where ca.is_active = true
      and ca.available_date >= current_date
      and not exists (select 1 from public.bk_appointments ba where ba.availability_id = ca.id and ba.status in ('pending','accepted'))
    order by ca.available_date asc, ca.start_time asc;
end;
$$;

-- --------------------------------------------------------------------------
-- get_student_bk_appointments
-- --------------------------------------------------------------------------
create or replace function public.get_student_bk_appointments()
returns table (appointment_id uuid, status text, requested_start_at timestamptz, requested_end_at timestamptz, scheduled_start_at timestamptz, scheduled_end_at timestamptz, student_note text, counselor_display text, created_at timestamptz, cancelled_at timestamptz, completed_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  return query
    select ba.id as appointment_id, ba.status, ba.requested_start_at, ba.requested_end_at, ba.scheduled_start_at, ba.scheduled_end_at, ba.student_note, 'Guru BK'::text as counselor_display, ba.created_at, ba.cancelled_at, ba.completed_at
    from public.bk_appointments ba
    where ba.student_id = v_uid
    order by ba.created_at desc;
end;
$$;

-- --------------------------------------------------------------------------
-- get_counselor_bk_appointments
-- --------------------------------------------------------------------------
create or replace function public.get_counselor_bk_appointments()
returns table (appointment_id uuid, status text, requested_start_at timestamptz, requested_end_at timestamptz, scheduled_start_at timestamptz, scheduled_end_at timestamptz, student_note text, counselor_note text, student_alias text, created_at timestamptz, cancelled_at timestamptz, completed_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  return query
    select ba.id as appointment_id, ba.status, ba.requested_start_at, ba.requested_end_at, ba.scheduled_start_at, ba.scheduled_end_at, ba.student_note, ba.counselor_note,
           coalesce(cc.student_alias, 'Siswa BK #XXXX') as student_alias, ba.created_at, ba.cancelled_at, ba.completed_at
    from public.bk_appointments ba
    left join public.counseling_conversations cc on cc.id = ba.conversation_id
    where ba.counselor_id = v_uid
    order by
      case when ba.status = 'pending' then 1 when ba.status='accepted' then 2 else 3 end,
      ba.created_at asc;
end;
$$;

-- --------------------------------------------------------------------------
-- request_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.request_bk_appointment(p_availability_id uuid, p_student_note text, p_conversation_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_has_consent boolean; v_avail public.counselor_availability%rowtype; v_requested_start timestamptz; v_requested_end timestamptz; v_counselor_id uuid; v_conv_student uuid; v_conv_counselor uuid; v_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'student' then raise exception 'Not authorized.'; end if;
  select exists(select 1 from public.bk_consents where student_id=v_uid and version='bk-consent-v1' and revoked_at is null) into v_has_consent;
  if not v_has_consent then raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.'; end if;
  if p_student_note is not null and char_length(p_student_note) > 1000 then raise exception 'Note too long.'; end if;
  -- Validate availability
  select * into v_avail from public.counselor_availability where id = p_availability_id and is_active = true;
  if not found then raise exception 'Slot tidak tersedia.'; end if;
  if v_avail.available_date < current_date then raise exception 'Past slot.'; end if;
  if v_avail.available_date = current_date and v_avail.start_time <= current_time then raise exception 'Past slot.'; end if;
  -- Check not already booked (pending/accepted)
  if exists(select 1 from public.bk_appointments where availability_id = p_availability_id and status in ('pending','accepted')) then
    raise exception 'Slot sudah dipesan.';
  end if;
  -- Convert date+time to timestamptz (assume Asia/Jakarta, but store as UTC? Use date+time as timestamptz at local)
  v_requested_start := (v_avail.available_date + v_avail.start_time)::timestamptz;
  v_requested_end := (v_avail.available_date + v_avail.end_time)::timestamptz;
  if v_requested_start >= v_requested_end then raise exception 'Invalid time.'; end if;
  if extract(epoch from (v_requested_end - v_requested_start))/60 > 120 then raise exception 'Duration too long.'; end if;
  if v_requested_start <= now() then raise exception 'Past slot.'; end if;
  v_counselor_id := v_avail.counselor_id;
  -- Conversation linkage check
  if p_conversation_id is not null then
    select student_id, counselor_id into v_conv_student, v_conv_counselor from public.counseling_conversations where id = p_conversation_id;
    if not found then raise exception 'Conversation not found.'; end if;
    if v_conv_student <> v_uid then raise exception 'Conversation not owned.'; end if;
    -- If conversation has counselor, it should match appointment counselor
    if v_conv_counselor is not null and v_conv_counselor <> v_counselor_id then raise exception 'Conversation counselor mismatch.'; end if;
  end if;
  insert into public.bk_appointments (student_id, counselor_id, conversation_id, availability_id, requested_start_at, requested_end_at, status, student_note)
  values (v_uid, v_counselor_id, p_conversation_id, p_availability_id, v_requested_start, v_requested_end, 'pending', nullif(btrim(coalesce(p_student_note,'')), ''))
  returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'Slot sudah dipesan.';
end;
$$;

-- --------------------------------------------------------------------------
-- accept_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.accept_bk_appointment(p_appointment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_app public.bk_appointments%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_app from public.bk_appointments where id = p_appointment_id for update;
  if not found then raise exception 'Appointment not found.'; end if;
  if v_app.counselor_id <> v_uid then raise exception 'Not authorized.'; end if;
  if v_app.status <> 'pending' then raise exception 'Only pending can be accepted.'; end if;
  -- Check slot still valid and no conflict (already handled by unique index, but check time)
  if v_app.requested_start_at <= now() then raise exception 'Past slot.'; end if;
  update public.bk_appointments set status='accepted', scheduled_start_at=v_app.requested_start_at, scheduled_end_at=v_app.requested_end_at, updated_at=now() where id=p_appointment_id;
end;
$$;

-- --------------------------------------------------------------------------
-- reject_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.reject_bk_appointment(p_appointment_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_app public.bk_appointments%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_app from public.bk_appointments where id=p_appointment_id for update;
  if not found then raise exception 'Appointment not found.'; end if;
  if v_app.counselor_id <> v_uid then raise exception 'Not authorized.'; end if;
  if v_app.status <> 'pending' then raise exception 'Only pending can be rejected.'; end if;
  if p_reason is not null and char_length(p_reason) > 1000 then raise exception 'Reason too long.'; end if;
  update public.bk_appointments set status='rejected', counselor_note=nullif(btrim(coalesce(p_reason,'')), ''), updated_at=now() where id=p_appointment_id;
end;
$$;

-- --------------------------------------------------------------------------
-- reschedule_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.reschedule_bk_appointment(p_appointment_id uuid, p_new_start_at timestamptz, p_new_end_at timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_app public.bk_appointments%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  if p_new_start_at is null or p_new_end_at is null then raise exception 'Invalid schedule.'; end if;
  if p_new_start_at >= p_new_end_at then raise exception 'Invalid time.'; end if;
  if p_new_start_at <= now() then raise exception 'Past schedule.'; end if;
  if extract(epoch from (p_new_end_at - p_new_start_at))/60 > 120 then raise exception 'Duration too long.'; end if;
  select * into v_app from public.bk_appointments where id=p_appointment_id for update;
  if not found then raise exception 'Appointment not found.'; end if;
  if v_app.counselor_id <> v_uid then raise exception 'Not authorized.'; end if;
  if v_app.status not in ('pending','accepted') then raise exception 'Only pending or accepted can be rescheduled.'; end if;
  -- Check no overlap with other accepted appointments for same counselor (simple: check any other accepted appointment overlapping)
  if exists(select 1 from public.bk_appointments where counselor_id=v_uid and id <> p_appointment_id and status='accepted' and scheduled_start_at < p_new_end_at and scheduled_end_at > p_new_start_at) then
    raise exception 'Conflicting schedule.';
  end if;
  update public.bk_appointments set scheduled_start_at=p_new_start_at, scheduled_end_at=p_new_end_at, status='accepted', updated_at=now() where id=p_appointment_id;
end;
$$;

-- --------------------------------------------------------------------------
-- cancel_student_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.cancel_student_bk_appointment(p_appointment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_app public.bk_appointments%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select * into v_app from public.bk_appointments where id=p_appointment_id for update;
  if not found then raise exception 'Appointment not found.'; end if;
  if v_app.student_id <> v_uid then raise exception 'Not authorized.'; end if;
  if v_app.status not in ('pending','accepted') then raise exception 'Cannot cancel.'; end if;
  update public.bk_appointments set status='cancelled', cancelled_at=now(), updated_at=now() where id=p_appointment_id;
end;
$$;

-- --------------------------------------------------------------------------
-- cancel_counselor_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.cancel_counselor_bk_appointment(p_appointment_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_app public.bk_appointments%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_app from public.bk_appointments where id=p_appointment_id for update;
  if not found then raise exception 'Appointment not found.'; end if;
  if v_app.counselor_id <> v_uid then raise exception 'Not authorized.'; end if;
  if v_app.status not in ('pending','accepted') then raise exception 'Cannot cancel.'; end if;
  if p_reason is not null and char_length(p_reason) > 1000 then raise exception 'Reason too long.'; end if;
  update public.bk_appointments set status='cancelled', cancelled_at=now(), counselor_note=nullif(btrim(coalesce(p_reason,'')), ''), updated_at=now() where id=p_appointment_id;
end;
$$;

-- --------------------------------------------------------------------------
-- complete_bk_appointment
-- --------------------------------------------------------------------------
create or replace function public.complete_bk_appointment(p_appointment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_app public.bk_appointments%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_app from public.bk_appointments where id=p_appointment_id for update;
  if not found then raise exception 'Appointment not found.'; end if;
  if v_app.counselor_id <> v_uid then raise exception 'Not authorized.'; end if;
  if v_app.status <> 'accepted' then raise exception 'Only accepted can be completed.'; end if;
  -- Optionally require scheduled time <= now, but allow for MVP
  update public.bk_appointments set status='completed', completed_at=now(), updated_at=now() where id=p_appointment_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.counselor_availability from anon, authenticated, public;
revoke all privileges on public.bk_appointments from anon, authenticated, public;
grant select, insert, update, delete on public.counselor_availability to authenticated;
grant select, insert on public.bk_appointments to authenticated;

revoke all privileges on function public.create_counselor_availability(date,time,time) from public, anon;
revoke all privileges on function public.get_available_counseling_slots() from public, anon;
revoke all privileges on function public.get_student_bk_appointments() from public, anon;
revoke all privileges on function public.get_counselor_bk_appointments() from public, anon;
revoke all privileges on function public.request_bk_appointment(uuid,text,uuid) from public, anon;
revoke all privileges on function public.accept_bk_appointment(uuid) from public, anon;
revoke all privileges on function public.reject_bk_appointment(uuid,text) from public, anon;
revoke all privileges on function public.reschedule_bk_appointment(uuid,timestamptz,timestamptz) from public, anon;
revoke all privileges on function public.cancel_student_bk_appointment(uuid) from public, anon;
revoke all privileges on function public.cancel_counselor_bk_appointment(uuid,text) from public, anon;
revoke all privileges on function public.complete_bk_appointment(uuid) from public, anon;
grant execute on function public.create_counselor_availability(date,time,time) to authenticated;
grant execute on function public.get_available_counseling_slots() to authenticated;
grant execute on function public.get_student_bk_appointments() to authenticated;
grant execute on function public.get_counselor_bk_appointments() to authenticated;
grant execute on function public.request_bk_appointment(uuid,text,uuid) to authenticated;
grant execute on function public.accept_bk_appointment(uuid) to authenticated;
grant execute on function public.reject_bk_appointment(uuid,text) to authenticated;
grant execute on function public.reschedule_bk_appointment(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.cancel_student_bk_appointment(uuid) to authenticated;
grant execute on function public.cancel_counselor_bk_appointment(uuid,text) to authenticated;
grant execute on function public.complete_bk_appointment(uuid) to authenticated;

revoke execute on function public.is_counselor(uuid) from public, anon;
revoke execute on function public.is_student(uuid) from public, anon;
grant execute on function public.is_counselor(uuid) to authenticated;
grant execute on function public.is_student(uuid) to authenticated;

commit;
