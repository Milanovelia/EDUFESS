-- Allow post author to update is_best_answer on comments
begin;
drop policy if exists comments_update_best_answer on public.comments;
create policy comments_update_best_answer on public.comments for update to authenticated
  using (exists (select 1 from public.posts where posts.id = post_id and posts.author_id = auth.uid()))
  with check (true);
commit;
