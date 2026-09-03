-- Fix counselor assignment guard to allow legitimate claim via function
-- Original guard blocked all counselor_id changes, including via claim_counseling_conversation (definer).
-- New logic: allow only when new.counselor_id = auth.uid() and caller is counselor and conversation was open unassigned.

begin;

create or replace function public.guard_counseling_counselor_assign()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  if new.counselor_id is distinct from old.counselor_id then
    v_uid := auth.uid();
    if v_uid is null then raise exception 'Not authenticated.'; end if;
    select role into v_role from public.profiles where id = v_uid;
    -- Allow counselor self-claim of open unassigned conversation
    if v_role = 'counselor' and new.counselor_id = v_uid and old.counselor_id is null and old.status = 'open' then
      return new;
    end if;
    raise exception 'Counselor assignment must use claim function.';
  end if;
  return new;
end;
$$;

comment on function public.guard_counseling_counselor_assign() is 'Guards direct counselor assignment, allows only claim function self-claim.';

revoke execute on function public.guard_counseling_counselor_assign() from public, anon;
grant execute on function public.guard_counseling_counselor_assign() to authenticated;

commit;
