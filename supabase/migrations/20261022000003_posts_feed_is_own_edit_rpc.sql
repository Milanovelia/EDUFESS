-- ==========================================================================
-- EduFess — P2: posts_feed is_own + update_post RPC for owner edit
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- 1. Rebuild posts_feed to add is_own column
--    is_own = true only for the row's author when they are the caller.
--    Safe: no identity leak — it's a scalar boolean only true for self.
-- --------------------------------------------------------------------------
drop view if exists public.posts_feed;

create view public.posts_feed
with (security_invoker = false) as
select
  p.id,
  p.type,
  p.title,
  p.content,
  p.is_pseudonymous,
  case when p.is_pseudonymous then p.anonymous_alias else pr.pseudonym end as display_author,
  p.author_id,
  p.subject_id,
  s.name  as subject_name,
  s.slug  as subject_slug,
  p.topic_id,
  t.name  as topic_name,
  t.slug  as topic_slug,
  p.created_at,
  p.updated_at,
  coalesce(h.cnt, 0)::int as helpful_count,
  exists (select 1 from public.post_helpful ph where ph.post_id = p.id and ph.user_id = auth.uid()) as current_user_helpful,
  exists (select 1 from public.bookmarks  b  where b.post_id  = p.id and b.user_id  = auth.uid()) as current_user_bookmarked,
  coalesce(c.cnt, 0)::int as comment_count,
  exists (select 1 from public.comments cm where cm.post_id = p.id and cm.is_best_answer = true and cm.deleted_at is null) as has_best_answer,
  (p.author_id = auth.uid()) as is_own
from public.posts p
left join public.subjects s on s.id = p.subject_id
left join public.topics   t on t.id = p.topic_id
left join public.profiles pr on pr.id = p.author_id
left join (select post_id, count(*) as cnt from public.post_helpful group by post_id) h on h.post_id = p.id
left join (select post_id, count(*) as cnt from public.comments where deleted_at is null group by post_id) c on c.post_id = p.id
where p.deleted_at is null;

comment on view public.posts_feed is
  'Privacy-safe feed with aggregates. display_author resolved server-side. '
  'is_own=true only when auth.uid() is the author. helpful/bookmark columns are per auth.uid().';

revoke all privileges on public.posts_feed from anon, public;
grant select on public.posts_feed to authenticated;

-- --------------------------------------------------------------------------
-- 2. update_post RPC — owner-only title/content/type edit
--    Validates ownership and field constraints; no RLS bypass.
-- --------------------------------------------------------------------------
create or replace function public.update_post(
  p_post_id uuid,
  p_title   text,
  p_content text,
  p_type    text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid;
  v_owner  uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select author_id into v_owner
    from public.posts
   where id = p_post_id and deleted_at is null;

  if not found then
    raise exception 'Post not found.';
  end if;

  if v_owner is distinct from v_uid then
    raise exception 'Not authorized. You can only edit your own posts.';
  end if;

  -- Validate type
  if p_type not in ('note','question','summary','tip','request') then
    raise exception 'Invalid post type.';
  end if;

  -- Validate lengths (matches table CHECK constraints)
  if p_title  is null or char_length(btrim(p_title))  < 1 then
    raise exception 'Title is required.';
  end if;
  if p_content is null or char_length(btrim(p_content)) < 1 then
    raise exception 'Content is required.';
  end if;
  if char_length(p_title)   > 200   then raise exception 'Title too long.';   end if;
  if char_length(p_content) > 10000 then raise exception 'Content too long.'; end if;

  update public.posts
     set title   = btrim(p_title),
         content = btrim(p_content),
         type    = p_type
   where id = p_post_id;
end;
$$;

revoke all privileges on function public.update_post(uuid, text, text, text) from public, anon;
grant execute on function public.update_post(uuid, text, text, text) to authenticated;

commit;
