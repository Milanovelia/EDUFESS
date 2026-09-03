-- ==========================================================================
-- EduFess — M10 Mood Check-In (non-diagnostic)
-- Creates bk_mood_checkins with student-only private history and
-- counselor assignment-scoped access.
-- ==========================================================================

begin;

create table public.bk_mood_checkins (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  mood_level smallint not null check (mood_level between 1 and 5),
  note text check (note is null or char_length(note) between 1 and 1000),
  checked_in_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.bk_mood_checkins is 'Student private mood check-ins 1..5, optional note 1..1000, append-only, BK-private.';
comment on column public.bk_mood_checkins.mood_level is '1=Sangat Buruk .. 5=Sangat Baik (self-reported, non-diagnostic)';

create index bk_mood_checkins_student_checked_idx on public.bk_mood_checkins (student_id, checked_in_at desc);
create index bk_mood_checkins_created_at_idx on public.bk_mood_checkins (created_at desc);

create trigger bk_mood_checkins_touch_updated_at
  before update on public.bk_mood_checkins
  for each row execute function public.touch_updated_at();

-- RLS
alter table public.bk_mood_checkins enable row level security;

-- Student own only
create policy bk_mood_checkins_select_own on public.bk_mood_checkins for select to authenticated using (student_id = auth.uid());
create policy bk_mood_checkins_insert_own on public.bk_mood_checkins for insert to authenticated with check (student_id = auth.uid());
-- No update/delete for normal client (append-only)
-- No policies for counselor/admin direct select — use RPCs

-- --------------------------------------------------------------------------
-- submit_bk_mood_checkin
-- --------------------------------------------------------------------------
create or replace function public.submit_bk_mood_checkin(p_mood_level smallint, p_note text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_has_consent boolean; v_id uuid; v_note text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Not authorized.'; end if;
  select exists(select 1 from public.bk_consents where student_id = v_uid and version='bk-consent-v1' and revoked_at is null) into v_has_consent;
  if not v_has_consent then raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.'; end if;
  if p_mood_level is null or p_mood_level < 1 or p_mood_level > 5 then raise exception 'Invalid mood level.'; end if;
  v_note := nullif(btrim(coalesce(p_note,'')), '');
  if v_note is not null and char_length(v_note) > 1000 then raise exception 'Note too long.'; end if;
  insert into public.bk_mood_checkins (student_id, mood_level, note, checked_in_at)
  values (v_uid, p_mood_level, v_note, now()) returning id into v_id;
  return v_id;
end;
$$;

-- --------------------------------------------------------------------------
-- get_student_bk_mood_history
-- --------------------------------------------------------------------------
create or replace function public.get_student_bk_mood_history(p_limit int default 30, p_offset int default 0)
returns table (checkin_id uuid, mood_level smallint, note text, checked_in_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_limit int; v_offset int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  v_limit := coalesce(p_limit, 30);
  if v_limit < 1 then v_limit := 1; end if;
  if v_limit > 100 then v_limit := 100; end if;
  v_offset := coalesce(p_offset, 0);
  if v_offset < 0 then v_offset := 0; end if;
  return query
    select mc.id as checkin_id, mc.mood_level, mc.note, mc.checked_in_at
    from public.bk_mood_checkins mc
    where mc.student_id = v_uid
    order by mc.checked_in_at desc
    limit v_limit offset v_offset;
end;
$$;

-- --------------------------------------------------------------------------
-- get_counselor_student_mood_history
-- --------------------------------------------------------------------------
create or replace function public.get_counselor_student_mood_history(p_conversation_id uuid, p_limit int default 30, p_offset int default 0)
returns table (checkin_id uuid, mood_level smallint, note text, checked_in_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_student uuid; v_counselor uuid; v_status text; v_limit int; v_offset int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  if p_conversation_id is null then raise exception 'Conversation required.'; end if;
  select cc.student_id, cc.counselor_id, cc.status into v_student, v_counselor, v_status
    from public.counseling_conversations cc where cc.id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_counselor is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_status <> 'assigned' then raise exception 'Conversation not assigned.'; end if;
  v_limit := coalesce(p_limit, 30);
  if v_limit < 1 then v_limit := 1; end if;
  if v_limit > 100 then v_limit := 100; end if;
  v_offset := coalesce(p_offset, 0);
  if v_offset < 0 then v_offset := 0; end if;
  return query
    select mc.id as checkin_id, mc.mood_level, mc.note, mc.checked_in_at
    from public.bk_mood_checkins mc
    where mc.student_id = v_student
    order by mc.checked_in_at desc
    limit v_limit offset v_offset;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.bk_mood_checkins from anon, authenticated, public;
grant select, insert on public.bk_mood_checkins to authenticated;

revoke all privileges on function public.submit_bk_mood_checkin(smallint,text) from public, anon;
revoke all privileges on function public.get_student_bk_mood_history(int,int) from public, anon;
revoke all privileges on function public.get_counselor_student_mood_history(uuid,int,int) from public, anon;
grant execute on function public.submit_bk_mood_checkin(smallint,text) to authenticated;
grant execute on function public.get_student_bk_mood_history(int,int) to authenticated;
grant execute on function public.get_counselor_student_mood_history(uuid,int,int) to authenticated;

commit;
