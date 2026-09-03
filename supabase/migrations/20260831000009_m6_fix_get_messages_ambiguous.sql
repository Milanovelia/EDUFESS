-- Fix ambiguous id in get_counseling_messages due to RETURNS TABLE id column

begin;

create or replace function public.get_counseling_messages(p_conversation_id uuid)
returns table (id uuid, conversation_id uuid, sender_id uuid, content text, created_at timestamptz)
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
  return query select cm.id, cm.conversation_id, cm.sender_id, cm.content, cm.created_at from public.counseling_messages cm where cm.conversation_id = p_conversation_id and cm.deleted_at is null order by cm.created_at asc;
end;
$$;

comment on function public.get_counseling_messages(uuid) is 'Participant-only messages, privacy-safe.';

revoke all privileges on function public.get_counseling_messages(uuid) from public, anon;
grant execute on function public.get_counseling_messages(uuid) to authenticated;

commit;
