-- Fix ambiguous student_id in reveal_counseling_identity

begin;

create or replace function public.reveal_counseling_identity(p_conversation_id uuid, p_reason text)
returns table (student_id uuid, pseudonym text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_student uuid; v_counselor uuid; v_status text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if p_reason is null or btrim(p_reason) = '' then raise exception 'Reason required.'; end if;
  if char_length(p_reason) > 500 then raise exception 'Reason too long.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select cc.student_id, cc.counselor_id, cc.status into v_student, v_counselor, v_status from public.counseling_conversations cc where cc.id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_counselor is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_status = 'closed' then raise exception 'Conversation closed.'; end if;
  insert into public.bk_identity_access_log (counselor_id, student_id, conversation_id, reason) values (v_uid, v_student, p_conversation_id, btrim(p_reason));
  update public.counseling_conversations set identity_revealed_at = now(), updated_at = now() where id = p_conversation_id;
  return query select p.id, p.pseudonym from public.profiles p where p.id = v_student;
end;
$$;

comment on function public.reveal_counseling_identity(uuid,text) is 'Assigned counselor reveal with reason, audited.';

revoke all privileges on function public.reveal_counseling_identity(uuid,text) from public, anon;
grant execute on function public.reveal_counseling_identity(uuid,text) to authenticated;

commit;
