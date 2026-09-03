-- ==========================================================================
-- EduFess — M7 BK Student Experience
--
-- Changes:
--   - Enforce one active BK conversation per student (open/assigned) via
--     partial unique index + trigger check (server-side, not Flutter only).
--   - Minimal student projections:
--       get_student_bk_conversations() now returns only
--       conversation_id, student_alias, status, created_at, updated_at, closed_at
--       (no student_id, counselor_id, identity_revealed_at)
--       get_counseling_messages() now returns id, content, is_mine, created_at
--       (no sender_id, conversation_id raw)
--   - Closed conversation handling already server-enforced (trigger + RPC check
--     for status='closed'), kept explicit.
--   - No new BK tables, no destructive operations, M6 invariants preserved.
--
-- Privacy impact:
--   - Student projection no longer exposes student_id/counselor_id/identity_revealed_at
--   - Message projection no longer exposes sender_id/conversation_id raw
--   - BK alias preserved as student-facing identity
--   - One-active constraint prevents accidental duplicate sessions (UX)
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- One active conversation per student (open or assigned)
-- --------------------------------------------------------------------------
create unique index if not exists counseling_conversations_one_active_per_student
  on public.counseling_conversations (student_id)
  where status in ('open','assigned');

-- Also enforce via trigger for friendly error (unique violation is already clear,
-- but we provide Indonesian message via trigger before insert)
create or replace function public.check_one_active_conversation()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_exists boolean;
begin
  select exists(
    select 1 from public.counseling_conversations
    where student_id = new.student_id
      and status in ('open','assigned')
      and id <> new.id
  ) into v_exists;
  if v_exists then
    raise exception 'Kamu sudah memiliki percakapan aktif. Buka percakapan yang ada.';
  end if;
  return new;
end;
$$;

drop trigger if exists counseling_conversations_one_active on public.counseling_conversations;
create trigger counseling_conversations_one_active
  before insert on public.counseling_conversations
  for each row execute function public.check_one_active_conversation();

-- --------------------------------------------------------------------------
-- Minimal student projection: get_student_bk_conversations
-- --------------------------------------------------------------------------
drop function if exists public.get_student_bk_conversations();

create or replace function public.get_student_bk_conversations()
returns table (conversation_id uuid, student_alias text, status text, created_at timestamptz, updated_at timestamptz, closed_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  return query
    select cc.id as conversation_id, cc.student_alias, cc.status, cc.created_at, cc.updated_at, cc.closed_at
    from public.counseling_conversations cc
    where cc.student_id = v_uid
    order by cc.updated_at desc, cc.created_at desc;
end;
$$;

comment on function public.get_student_bk_conversations() is 'Student-only minimal projection: alias, status, timestamps, no ids.';

revoke all privileges on function public.get_student_bk_conversations() from public, anon;
grant execute on function public.get_student_bk_conversations() to authenticated;

-- --------------------------------------------------------------------------
-- Minimal message projection: is_mine instead of sender_id
-- --------------------------------------------------------------------------
drop function if exists public.get_counseling_messages(uuid);

create or replace function public.get_counseling_messages(p_conversation_id uuid)
returns table (id uuid, content text, is_mine boolean, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_student uuid; v_counselor uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select cc.student_id, cc.counselor_id into v_student, v_counselor from public.counseling_conversations cc where cc.id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if not (v_uid = v_student or v_uid = v_counselor) then raise exception 'Kamu tidak memiliki akses ke percakapan ini.'; end if;
  return query
    select cm.id, cm.content, (cm.sender_id = v_uid) as is_mine, cm.created_at
    from public.counseling_messages cm
    where cm.conversation_id = p_conversation_id and cm.deleted_at is null
    order by cm.created_at asc;
end;
$$;

comment on function public.get_counseling_messages(uuid) is 'Participant-only messages, returns is_mine, no raw sender_id.';

revoke all privileges on function public.get_counseling_messages(uuid) from public, anon;
grant execute on function public.get_counseling_messages(uuid) to authenticated;

-- Ensure closed check remains in send path (already in trigger + send_counseling_message, but keep explicit)
-- No change to send_counseling_message; it already checks status='closed'

commit;
