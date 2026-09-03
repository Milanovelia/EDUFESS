-- Fix helpful/bookmark trigger to correctly block on deleted post regardless of RLS
-- Original function was not SECURITY DEFINER, so SELECT on posts was RLS-filtered
-- and couldn't see deleted posts for non-owners, allowing helpful on removed content.
-- Make it SECURITY DEFINER so it can always see deleted_at.

begin;

create or replace function public.check_helpful_post_not_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted timestamptz;
begin
  select deleted_at into v_deleted from public.posts where id = new.post_id;
  if not found then raise exception 'Post not found.'; end if;
  if v_deleted is not null then raise exception 'Post has been deleted.'; end if;
  return new;
end;
$$;

comment on function public.check_helpful_post_not_deleted() is 'Prevents helpful/bookmark on deleted post. SECURITY DEFINER to bypass RLS and see deleted_at.';

-- Re-apply grants
revoke execute on function public.check_helpful_post_not_deleted() from public, anon;
grant execute on function public.check_helpful_post_not_deleted() to authenticated;

commit;
