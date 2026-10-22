-- Migration: allow counselors (and students) to soft-delete their own
-- counseling messages via a security-definer RPC.
--
-- Scope: sender can only delete their own messages (sender_id = auth.uid()).
-- Counselors do NOT gain any broader delete rights.
-- Admin can already manage data via the Supabase Dashboard.
--
-- Implementation uses a security-definer function so the table never
-- needs a bare UPDATE RLS policy granted to authenticated users.
-- The function checks:
--   1. Caller is authenticated.
--   2. Message exists and belongs to caller (sender_id = auth.uid()).
--   3. Message is not already deleted.

create or replace function public.delete_counseling_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_sender uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select sender_id into v_sender
    from public.counseling_messages
   where id = p_message_id
     and deleted_at is null;

  if not found then
    raise exception 'Message not found or already deleted.';
  end if;

  if v_sender is distinct from v_uid then
    raise exception 'Not your message.';
  end if;

  update public.counseling_messages
     set deleted_at = now()
   where id = p_message_id;
end;
$$;

comment on function public.delete_counseling_message(uuid) is
  'Soft-delete a counseling message. Caller must be the original sender. Security-definer; no direct UPDATE access granted.';

-- Revoke public execution; only authenticated users may call it.
revoke all on function public.delete_counseling_message(uuid) from public, anon;
grant execute on function public.delete_counseling_message(uuid) to authenticated;
