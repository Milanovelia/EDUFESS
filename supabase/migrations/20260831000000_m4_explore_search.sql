-- ==========================================================================
-- EduFess — M4: explore & search
--
-- Creates:
--   function public.search_posts (privacy-safe search RPC)
--   index public.posts_type_idx (for post_type filter)
--
-- Design:
--   - Privacy-safe: returns same display_author logic as posts_feed
--     (anonymous_alias for pseudonymous, pseudonym otherwise). Never
--     exposes email or raw author_id for pseudonymous post.
--   - Only authenticated users may call; raises if auth.uid() is null.
--   - SECURITY DEFINER with fixed search_path to prevent search_path hijack.
--   - No dynamic SQL; ILIKE uses bound parameter with || concatenation
--     in plain SQL (not EXECUTE), so no SQL injection.
--   - Deleted posts excluded (deleted_at is null).
--   - Supports filters: query (title/content ILIKE), subject_id,
--     topic_id, post_type, sort (terbaru/helpful/comments), limit/offset.
--   - Pagination bounded: limit clamped 1..50, offset >=0.
--   - Sort: terbaru = created_at DESC (default), helpful = helpful_count DESC,
--     comments = comment_count DESC. Tie-breaker always created_at DESC.
--   - Indexes: adds posts_type_idx for type filter; existing subject/topic/
--     created_at indexes already cover other filters. ILIKE '%q%' is
--     sequential scan for MVP (documented tradeoff) — acceptable for small
--     dataset without pg_trgm / FTS.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- Index for post_type filter (justified: search filter on type)
-- --------------------------------------------------------------------------
create index if not exists posts_type_idx on public.posts (type) where deleted_at is null;

-- --------------------------------------------------------------------------
-- Search RPC — privacy-safe, authenticated only
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

  -- Validate post_type if provided
  if p_post_type is not null and p_post_type not in ('note','question','summary','tip','request') then
    raise exception 'Invalid post type.';
  end if;

  -- Normalize sort
  v_sort := lower(coalesce(p_sort, 'terbaru'));
  if v_sort not in ('terbaru','paling_membantu','membantu','helpful','paling_banyak_dikomentari','comments','most_commented') then
    v_sort := 'terbaru';
  end if;
  -- Map Indonesian labels to canonical
  if v_sort in ('paling_membantu','membantu','helpful') then
    v_sort := 'helpful';
  elsif v_sort in ('paling_banyak_dikomentari','comments','most_commented') then
    v_sort := 'comments';
  else
    v_sort := 'terbaru';
  end if;

  -- Clamp pagination
  v_limit := coalesce(p_limit, 20);
  if v_limit < 1 then v_limit := 1; end if;
  if v_limit > 50 then v_limit := 50; end if;
  v_offset := coalesce(p_offset, 0);
  if v_offset < 0 then v_offset := 0; end if;

  -- Normalize query: trim, null if empty
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
    and (v_query is null or p.title ilike '%' || v_query || '%' or p.content ilike '%' || v_query || '%')
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

comment on function public.search_posts(text, uuid, uuid, text, text, int, int) is 'Privacy-safe search. Returns display_author only (alias for pseudonymous). Authenticated only. Supports ILIKE on title/content, subject/topic/type filters, sorting, pagination. SECURITY DEFINER with fixed search_path.';

-- Grants: authenticated only, no anon
revoke all privileges on function public.search_posts(text, uuid, uuid, text, text, int, int) from public, anon;
grant execute on function public.search_posts(text, uuid, uuid, text, text, int, int) to authenticated;

-- Also ensure posts_type_idx is accessible (no extra grants needed; on table)

commit;
