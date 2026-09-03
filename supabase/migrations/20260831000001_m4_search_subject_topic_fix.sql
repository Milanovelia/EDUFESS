-- ==========================================================================
-- EduFess — M4 corrective: search also matches subject/topic names
--
-- Fixes:
--   public.search_posts predicate previously only matched title/content.
--   Requirement is to also match subject name and topic name.
--
-- Changes:
--   - Recreates function public.search_posts to include:
--       s.name ILIKE '%q%' OR t.name ILIKE '%q%'
--     alongside title/content. Uses already-joined public.subjects s
--     and public.topics t; no dynamic SQL.
--   - Keeps all existing behavior: filters, sorting, pagination, privacy-safe
--     projection, SECURITY DEFINER with fixed search_path, auth check, grants.
--
-- Objects modified:
--   function public.search_posts(text, uuid, uuid, text, text, int, int)
--
-- Design notes:
--   - SECURITY DEFINER + SET search_path = '' retained (safe, consistent
--     with project conventions). All table references remain schema-qualified
--     (public.posts, public.subjects, public.topics, public.profiles,
--     public.post_helpful, public.bookmarks, public.comments).
--   - No extensions, no FTS, no dynamic SQL. ILIKE remains sequential scan MVP.
-- ==========================================================================

begin;

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
  join public.subjects s on s.id = p.subject_id
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

-- Grants: authenticated only, no anon/public
revoke all privileges on function public.search_posts(text, uuid, uuid, text, text, int, int) from public, anon;
grant execute on function public.search_posts(text, uuid, uuid, text, text, int, int) to authenticated;

commit;
