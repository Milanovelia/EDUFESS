-- ==========================================================================
-- EduFess — M11 Peer Concern / Peduli Teman (BK-private)
-- Creates bk_peer_concerns with privacy-safe RPCs and strict RLS.
-- ==========================================================================

begin;

create table public.bk_peer_concerns (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_student_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (reason in ('emotional','social','academic','family','bullying','safety_concern','other')),
  details text check (details is null or char_length(details) between 1 and 2000),
  status text not null default 'pending' check (status in ('pending','reviewing','resolved','dismissed')),
  handled_by uuid references public.profiles (id) on delete set null,
  handled_at timestamptz,
  resolution_note text check (resolution_note is null or char_length(resolution_note) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (reporter_id <> target_student_id)
);

comment on table public.bk_peer_concerns is 'BK-private peer concerns, reporter is student, target is another student, alias-only for counselor queue.';

create index bk_peer_concerns_reporter_created_idx on public.bk_peer_concerns (reporter_id, created_at desc);
create index bk_peer_concerns_target_created_idx on public.bk_peer_concerns (target_student_id, created_at desc);
create index bk_peer_concerns_status_created_idx on public.bk_peer_concerns (status, created_at asc);
create index bk_peer_concerns_handled_by_status_idx on public.bk_peer_concerns (handled_by, status, updated_at desc) where handled_by is not null;

-- Prevent duplicate active concern from same reporter about same target
create unique index bk_peer_concerns_one_active_per_reporter_target
  on public.bk_peer_concerns (reporter_id, target_student_id)
  where status in ('pending','reviewing');

create trigger bk_peer_concerns_touch_updated_at
  before update on public.bk_peer_concerns
  for each row execute function public.touch_updated_at();

-- RLS
alter table public.bk_peer_concerns enable row level security;

-- Student own reports only
create policy bk_peer_concerns_select_own on public.bk_peer_concerns for select to authenticated using (reporter_id = auth.uid());
create policy bk_peer_concerns_insert_own on public.bk_peer_concerns for insert to authenticated with check (reporter_id = auth.uid());
-- No direct update/delete for normal client; use RPCs (definer)

-- --------------------------------------------------------------------------
-- Helper: force reporter_id and validate target
-- --------------------------------------------------------------------------
create or replace function public.set_bk_peer_concern_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_target_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if new.reporter_id is distinct from v_uid then new.reporter_id := v_uid; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Not authorized.'; end if;
  -- target must exist and be student and not self
  select role into v_target_role from public.profiles where id = new.target_student_id;
  if not found then raise exception 'Target not found.'; end if;
  if v_target_role is distinct from 'student' then raise exception 'Target must be student.'; end if;
  if new.target_student_id = v_uid then raise exception 'Cannot report self.'; end if;
  if new.reason not in ('emotional','social','academic','family','bullying','safety_concern','other') then raise exception 'Invalid reason.'; end if;
  if new.details is not null then
    new.details := nullif(btrim(new.details), '');
    if new.details is not null and char_length(new.details) > 2000 then raise exception 'Details too long.'; end if;
  end if;
  -- Check BK consent for reporter
  if not exists(select 1 from public.bk_consents where student_id = v_uid and version='bk-consent-v1' and revoked_at is null) then
    raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.';
  end if;
  new.status := 'pending';
  new.handled_by := null;
  new.handled_at := null;
  new.resolution_note := null;
  return new;
end;
$$;

create trigger bk_peer_concerns_set_fields
  before insert on public.bk_peer_concerns
  for each row execute function public.set_bk_peer_concern_fields();

-- --------------------------------------------------------------------------
-- search_peer_students
-- --------------------------------------------------------------------------
create or replace function public.search_peer_students(p_query text, p_limit int default 10)
returns table (student_ref uuid, display_pseudonym text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_q text; v_lim int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  v_q := btrim(coalesce(p_query,''));
  if char_length(v_q) < 2 then raise exception 'Query too short.'; end if;
  v_lim := coalesce(p_limit, 10);
  if v_lim < 1 then v_lim := 1; end if;
  if v_lim > 20 then v_lim := 20; end if;
  return query
    select p.id as student_ref, p.pseudonym as display_pseudonym
    from public.profiles p
    where p.role = 'student'
      and p.id <> v_uid
      and p.pseudonym ilike '%' || v_q || '%'
    order by p.pseudonym asc
    limit v_lim;
end;
$$;

-- --------------------------------------------------------------------------
-- submit_bk_peer_concern
-- --------------------------------------------------------------------------
create or replace function public.submit_bk_peer_concern(p_target_student_id uuid, p_reason text, p_details text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_target_role text; v_has_consent boolean; v_id uuid; v_reason text; v_details text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Not authorized.'; end if;
  select exists(select 1 from public.bk_consents where student_id=v_uid and version='bk-consent-v1' and revoked_at is null) into v_has_consent;
  if not v_has_consent then raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.'; end if;
  if p_target_student_id is null then raise exception 'Target required.'; end if;
  if p_target_student_id = v_uid then raise exception 'Cannot report self.'; end if;
  select role into v_target_role from public.profiles where id = p_target_student_id;
  if not found then raise exception 'Target not found.'; end if;
  if v_target_role is distinct from 'student' then raise exception 'Target must be student.'; end if;
  v_reason := lower(btrim(coalesce(p_reason,'')));
  if v_reason not in ('emotional','social','academic','family','bullying','safety_concern','other') then raise exception 'Invalid reason.'; end if;
  v_details := nullif(btrim(coalesce(p_details,'')), '');
  if v_details is not null and char_length(v_details) > 2000 then raise exception 'Details too long.'; end if;
  -- Check duplicate active
  if exists(select 1 from public.bk_peer_concerns where reporter_id=v_uid and target_student_id=p_target_student_id and status in ('pending','reviewing')) then
    raise exception 'Kamu sudah memiliki laporan aktif untuk teman ini.';
  end if;
  insert into public.bk_peer_concerns (reporter_id, target_student_id, reason, details, status)
  values (v_uid, p_target_student_id, v_reason, v_details, 'pending') returning id into v_id;
  return v_id;
end;
$$;

-- --------------------------------------------------------------------------
-- get_student_peer_concerns
-- --------------------------------------------------------------------------
create or replace function public.get_student_peer_concerns()
returns table (concern_id uuid, target_display text, reason text, details text, status text, created_at timestamptz, handled_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  return query
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.details, pc.status, pc.created_at, pc.handled_at
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.reporter_id = v_uid
    order by pc.created_at desc;
end;
$$;

-- --------------------------------------------------------------------------
-- get_counselor_peer_concern_queue
-- --------------------------------------------------------------------------
create or replace function public.get_counselor_peer_concern_queue()
returns table (concern_id uuid, target_display text, reason text, status text, created_at timestamptz, details_preview text)
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
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.status, pc.created_at,
           left(pc.details, 100) as details_preview
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.status = 'pending' and pc.handled_by is null
    order by pc.created_at asc;
end;
$$;

-- --------------------------------------------------------------------------
-- claim_bk_peer_concern
-- --------------------------------------------------------------------------
create or replace function public.claim_bk_peer_concern(p_concern_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id for update;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.status <> 'pending' then raise exception 'Only pending can be claimed.'; end if;
  if v_rec.handled_by is not null then raise exception 'Laporan ini sudah ditangani guru BK lain.'; end if;
  update public.bk_peer_concerns set status='reviewing', handled_by=v_uid, handled_at=now(), updated_at=now() where id=p_concern_id;
end;
$$;

-- --------------------------------------------------------------------------
-- get_counselor_peer_concern_detail
-- --------------------------------------------------------------------------
create or replace function public.get_counselor_peer_concern_detail(p_concern_id uuid)
returns table (concern_id uuid, target_display text, reason text, details text, status text, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.handled_by is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  return query
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.details, pc.status, pc.created_at
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.id = p_concern_id;
end;
$$;

-- --------------------------------------------------------------------------
-- get_counselor_peer_concern_history
-- --------------------------------------------------------------------------
create or replace function public.get_counselor_peer_concern_history()
returns table (concern_id uuid, target_display text, reason text, status text, created_at timestamptz, handled_at timestamptz)
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
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.status, pc.created_at, pc.handled_at
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.handled_by = v_uid and pc.status in ('reviewing','resolved','dismissed')
    order by pc.updated_at desc;
end;
$$;

-- --------------------------------------------------------------------------
-- resolve/dismiss
-- --------------------------------------------------------------------------
create or replace function public.resolve_bk_peer_concern(p_concern_id uuid, p_resolution_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype; v_note text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  v_note := nullif(btrim(coalesce(p_resolution_note,'')), '');
  if v_note is not null and char_length(v_note) > 2000 then raise exception 'Note too long.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id for update;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.handled_by is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_rec.status not in ('pending','reviewing') then raise exception 'Only pending/reviewing can be resolved.'; end if;
  update public.bk_peer_concerns set status='resolved', handled_at=now(), resolution_note=v_note, updated_at=now() where id=p_concern_id;
end;
$$;

create or replace function public.dismiss_bk_peer_concern(p_concern_id uuid, p_resolution_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype; v_note text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  v_note := nullif(btrim(coalesce(p_resolution_note,'')), '');
  if v_note is not null and char_length(v_note) > 2000 then raise exception 'Note too long.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id for update;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.handled_by is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_rec.status not in ('pending','reviewing') then raise exception 'Only pending/reviewing can be dismissed.'; end if;
  update public.bk_peer_concerns set status='dismissed', handled_at=now(), resolution_note=v_note, updated_at=now() where id=p_concern_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.bk_peer_concerns from anon, authenticated, public;
grant select, insert on public.bk_peer_concerns to authenticated;

revoke all privileges on function public.search_peer_students(text,int) from public, anon;
revoke all privileges on function public.submit_bk_peer_concern(uuid,text,text) from public, anon;
revoke all privileges on function public.get_student_peer_concerns() from public, anon;
revoke all privileges on function public.get_counselor_peer_concern_queue() from public, anon;
revoke all privileges on function public.claim_bk_peer_concern(uuid) from public, anon;
revoke all privileges on function public.get_counselor_peer_concern_detail(uuid) from public, anon;
revoke all privileges on function public.get_counselor_peer_concern_history() from public, anon;
revoke all privileges on function public.resolve_bk_peer_concern(uuid,text) from public, anon;
revoke all privileges on function public.dismiss_bk_peer_concern(uuid,text) from public, anon;
grant execute on function public.search_peer_students(text,int) to authenticated;
grant execute on function public.submit_bk_peer_concern(uuid,text,text) to authenticated;
grant execute on function public.get_student_peer_concerns() to authenticated;
grant execute on function public.get_counselor_peer_concern_queue() to authenticated;
grant execute on function public.claim_bk_peer_concern(uuid) to authenticated;
grant execute on function public.get_counselor_peer_concern_detail(uuid) to authenticated;
grant execute on function public.get_counselor_peer_concern_history() to authenticated;
grant execute on function public.resolve_bk_peer_concern(uuid,text) to authenticated;
grant execute on function public.dismiss_bk_peer_concern(uuid,text) to authenticated;

revoke execute on function public.set_bk_peer_concern_fields() from public, anon;
grant execute on function public.set_bk_peer_concern_fields() to authenticated;

commit;
