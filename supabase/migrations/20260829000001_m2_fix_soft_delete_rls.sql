-- Fix soft-delete RLS: allow own deleted posts to be visible for UPDATE's WITH CHECK
-- Original posts_select_active was USING (deleted_at IS NULL) which caused
-- new row with deleted_at = now() to violate RLS on UPDATE (WITH CHECK).
-- Fixed to allow own posts regardless of deleted_at, while feed view still
-- filters deleted_at IS NULL for normal feed.

begin;

drop policy if exists posts_select_active on public.posts;
create policy posts_select_active
  on public.posts for select to authenticated
  using ((deleted_at is null) or (author_id = auth.uid()));

-- Ensure profiles RLS is enabled (was disabled during debug)
alter table public.profiles enable row level security;

commit;
