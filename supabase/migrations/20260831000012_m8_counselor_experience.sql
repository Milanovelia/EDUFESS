-- ==========================================================================
-- EduFess — M8 Counselor Experience
--
-- Adds:
--   get_counselor_assigned_conversations() — privacy-safe assigned list
--   close_counseling_conversation(p_conversation_id) — assigned counselor only
--
-- Keeps M6/M7 invariants: one-active, alias-only queue, participant messages,
-- reveal audit, admin BK denial, counselor no moderation.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- Assigned conversations for counselor (own only, minimal)
-- --------------------------------------------------------------------------
create or replace function public.get_counselor_assigned_conversations()
returns table (conversation_id uuid, student_alias text, status text, created_at timestamptz, updated_at timestamptz, closed_at timestamptz, identity_revealed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  return query
    select cc.id as conversation_id, cc.student_alias, cc.status, cc.created_at, cc.updated_at, cc.closed_at, (cc.identity_revealed_at is not null) as identity_revealed
    from public.counseling_conversations cc
    where cc.counselor_id = v_uid
    order by cc.updated_at desc, cc.created_at desc;
end;
$$;

comment on function public.get_counselor_assigned_conversations() is 'Counselor own assigned conversations, minimal alias-only, ordered updated_at desc.';

revoke all privileges on function public.get_counselor_assigned_conversations() from public, anon;
grant execute on function public.get_counselor_assigned_conversations() to authenticated;

-- --------------------------------------------------------------------------
-- Close conversation (assigned counselor only)
-- --------------------------------------------------------------------------
create or replace function public.close_counseling_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_counselor uuid; v_status text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select counselor_id, status into v_counselor, v_status from public.counseling_conversations where id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_counselor is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_status = 'closed' then raise exception 'Conversation already closed.'; end if;
  if v_status <> 'assigned' then raise exception 'Only assigned conversation can be closed.'; end if;
  update public.counseling_conversations set status='closed', closed_at=now(), updated_at=now() where id = p_conversation_id;
end;
$$;

comment on function public.close_counseling_conversation(uuid) is 'Assigned counselor closes conversation, sets closed_at, releases one-active.';

revoke all privileges on function public.close_counseling_conversation(uuid) from public, anon;
grant execute on function public.close_counseling_conversation(uuid) to authenticated;

commit;
