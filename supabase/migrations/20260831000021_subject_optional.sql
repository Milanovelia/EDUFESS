-- ==========================================================================
-- EduFess — Social-First: posts.subject_id becomes optional
--
-- Decision: SUBJECT OPTIONAL — CONFIRMED (no hidden/default subject).
--
-- Changes (non-destructive, no backfill, no data delete):
--   1. posts.subject_id: DROP NOT NULL. FK to subjects (ON DELETE RESTRICT)
--      is preserved: it only fires for non-null values.
--   2. check_topic_subject: NULL subject + non-null topic is now rejected
--      explicitly ('Topic requires a subject.'). All other branches keep
--      existing behavior for INSERT and UPDATE (trigger unchanged).
--   3. posts_feed: JOIN subjects -> LEFT JOIN subjects so subject-less
--      posts still appear. Column names/order/types/semantics preserved.
--   4. search_posts: JOIN subjects -> LEFT JOIN subjects so subject-less
--      posts are findable when p_subject_id is null. Signature, return
--      contract, ordering, and search semantics preserved.
--
-- Moderation queue views already use LEFT JOIN + coalesce and need no
-- change. RLS, policies, grants, and RPC security are untouched.
-- Existing posts/subjects/topics keep their values.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- 1. posts.subject_id nullable (FK preserved)
-- --------------------------------------------------------------------------
alter table public.posts
  alter column subject_id drop not null;

-- --------------------------------------------------------------------------
-- 2. check_topic_subject: reject topic without subject
-- --------------------------------------------------------------------------
create or replace function public.check_topic_subject()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_topic_subject uuid;
begin
  if new.topic_id is null then
    return new;
  end if;
  if new.subject_id is null then
    raise exception 'Topic requires a subject.';
  end if;
  select subject_id into v_topic_subject
    from public.topics where id = new.topic_id;
  if not found then
    raise exception 'Topic not found.';
  end if;
  if v_topic_subject <> new.subject_id then
    raise exception 'Topic does not belong to the selected subject.';
  end if;
  return new;
end;
$$;

-- Trigger binding unchanged (before insert or update on public.posts):
-- posts_check_topic_subject already exists and calls this function.

-- --------------------------------------------------------------------------
-- 3. posts_feed: LEFT JOIN subjects (keeps M3 aggregate shape)
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
  s.name as subject_name,
  s.slug as subject_slug,
  p.topic_id,
  t.name as topic_name,
  t.slug as topic_slug,
  p.created_at,
  p.updated_at,
  coalesce(h.cnt, 0)::int as helpful_count,
  exists (select 1 from public.post_helpful ph where ph.post_id = p.id and ph.user_id = auth.uid()) as current_user_helpful,
  exists (select 1 from public.bookmarks b where b.post_id = p.id and b.user_id = auth.uid()) as current_user_bookmarked,
  coalesce(c.cnt, 0)::int as comment_count,
  exists (select 1 from public.comments cm where cm.post_id = p.id and cm.is_best_answer = true and cm.deleted_at is null) as has_best_answer
from public.posts p
left join public.subjects s on s.id = p.subject_id
left join public.topics t on t.id = p.topic_id
left join public.profiles pr on pr.id = p.author_id
left join (select post_id, count(*) as cnt from public.post_helpful group by post_id) h on h.post_id = p.id
left join (select post_id, count(*) as cnt from public.comments where deleted_at is null group by post_id) c on c.post_id = p.id
where p.deleted_at is null;

comment on view public.posts_feed is 'Privacy-safe feed with aggregates. display_author = pseudonym or anonymous_alias. helpful/bookmark columns are per auth.uid().';

revoke all privileges on public.posts_feed from anon, public;
grant select on public.posts_feed to authenticated;

-- --------------------------------------------------------------------------
-- 4. search_posts: LEFT JOIN subjects (contract preserved)
-- --------------------------------------------------------------------------
create or replace function public.search_posts(
  p_query text default null,
  p_subject_id uuid default null,
  p_topic_id uuid default null,
  p_post_type text default null,
  p_sort text default 'terbaru',
  p_limit int default 20,
  p_offset int default 0
)
returns table (
  id uuid,
  type text,
  title text,
  content text,
  is_pseudonymous boolean,
  display_author text,
  subject_id uuid,
  subject_name text,
  subject_slug text,
  topic_id uuid,
  topic_name text,
  topic_slug text,
  created_at timestamptz,
  updated_at timestamptz,
  helpful_count int,
  current_user_helpful boolean,
  current_user_bookmarked boolean,
  comment_count int,
  has_best_answer boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit int;
  v_offset int;
  v_query text;
  v_sort text;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  if p_post_type is not null and p_post_type not in ('note','question','summary','tip','request') then
    raise exception 'Invalid post type.';
  end if;

  v_sort := lower(coalesce(p_sort, 'terbaru'));
  if v_sort not in ('terbaru','paling_membantu','membantu','helpful','paling_banyak_dikomentari','comments','most_commented') then
    v_sort := 'terbaru';
  end if;
  if v_sort in ('paling_membantu','membantu','helpful') then
    v_sort := 'helpful';
  elsif v_sort in ('paling_banyak_dikomentari','comments','most_commented') then
    v_sort := 'comments';
  else
    v_sort := 'terbaru';
  end if;

  v_limit := coalesce(p_limit, 20);
  if v_limit < 1 then v_limit := 1; end if;
  if v_limit > 50 then v_limit := 50; end if;
  v_offset := coalesce(p_offset, 0);
  if v_offset < 0 then v_offset := 0; end if;

  v_query := nullif(btrim(coalesce(p_query, '')), '');

  return query
  select
    p.id,
    p.type,
    p.title,
    p.content,
    p.is_pseudonymous,
    case when p.is_pseudonymous then p.anonymous_alias else pr.pseudonym end as display_author,
    p.subject_id,
    s.name as subject_name,
    s.slug as subject_slug,
    p.topic_id,
    t.name as topic_name,
    t.slug as topic_slug,
    p.created_at,
    p.updated_at,
    coalesce(h.cnt, 0)::int as helpful_count,
    exists (select 1 from public.post_helpful ph where ph.post_id = p.id and ph.user_id = v_uid) as current_user_helpful,
    exists (select 1 from public.bookmarks b where b.post_id = p.id and b.user_id = v_uid) as current_user_bookmarked,
    coalesce(c.cnt, 0)::int as comment_count,
    exists (select 1 from public.comments cm where cm.post_id = p.id and cm.is_best_answer = true and cm.deleted_at is null) as has_best_answer
  from public.posts p
  left join public.subjects s on s.id = p.subject_id
  left join public.topics t on t.id = p.topic_id
  left join public.profiles pr on pr.id = p.author_id
  left join (select post_id, count(*) as cnt from public.post_helpful group by post_id) h on h.post_id = p.id
  left join (select post_id, count(*) as cnt from public.comments where deleted_at is null group by post_id) c on c.post_id = p.id
  where p.deleted_at is null
    and (v_query is null
         or p.title ilike '%' || v_query || '%'
         or p.content ilike '%' || v_query || '%'
         or s.name ilike '%' || v_query || '%'
         or t.name ilike '%' || v_query || '%')
    and (p_subject_id is null or p.subject_id = p_subject_id)
    and (p_topic_id is null or p.topic_id = p_topic_id)
    and (p_post_type is null or p.type = p_post_type)
  order by
    case when v_sort = 'helpful' then coalesce(h.cnt, 0) end desc,
    case when v_sort = 'comments' then coalesce(c.cnt, 0) end desc,
    p.created_at desc
  limit v_limit offset v_offset;
end;
$$;

comment on function public.search_posts(text, uuid, uuid, text, text, int, int) is 'Privacy-safe search. Returns display_author only (alias for pseudonymous). Authenticated only. Supports ILIKE on title/content/subject/topic, subject/topic/type filters, sorting, pagination. SECURITY DEFINER with fixed search_path.';

revoke all privileges on function public.search_posts(text, uuid, uuid, text, text, int, int) from public, anon;
grant execute on function public.search_posts(text, uuid, uuid, text, text, int, int) to authenticated;

commit;
