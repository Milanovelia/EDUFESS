-- ==========================================================================
-- EduFess — M3: social interaction
--
-- Creates:
--   public.comments
--   public.post_helpful
--   public.bookmarks
--   view public.comments_feed (privacy-safe, security_invoker = false)
--   recreates view public.posts_feed with helpful/bookmark aggregates
--   functions/triggers for reply depth, author alias, best answer
--   RLS + grants
--
-- Design:
--   - comments: fk posts CASCADE, fk profiles CASCADE, parent_id fk comments CASCADE,
--     is_pseudonymous, anonymous_alias, is_best_answer, soft delete
--   - replies max 1 level enforced server-side via trigger
--   - author_id forced to auth.uid(), alias server-generated
--   - comments_feed privacy-safe: display_author = CASE is_pseudonymous THEN alias ELSE pseudonym
--   - post_helpful: PK(user_id, post_id), one per user/post, toggle via insert/delete
--   - bookmarks: PK(user_id, post_id), private per user
--   - best answer: only question post, only post author, max 1 per post, comment must belong to post and not deleted
--   - posts_feed enriched with helpful_count, current_user_helpful, current_user_bookmarked, comment_count, has_best_answer
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- comments
-- --------------------------------------------------------------------------
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  parent_id uuid references public.comments (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 5000),
  is_pseudonymous boolean not null default false,
  anonymous_alias text check (anonymous_alias is null or char_length(anonymous_alias) between 1 and 64),
  is_best_answer boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.comments is 'Comments and 1-level replies. Pseudonymous uses anonymous_alias generated server-side.';
create index comments_post_id_idx on public.comments (post_id);
create index comments_parent_id_idx on public.comments (parent_id) where parent_id is not null;
create index comments_author_id_idx on public.comments (author_id);
create index comments_created_at_idx on public.comments (created_at);
-- Only one best answer per post (when not deleted)
create unique index comments_one_best_per_post on public.comments (post_id) where is_best_answer = true and deleted_at is null;

create trigger comments_touch_updated_at
  before update on public.comments
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------------------
-- post_helpful
-- --------------------------------------------------------------------------
create table public.post_helpful (
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index post_helpful_post_id_idx on public.post_helpful (post_id);
create index post_helpful_user_id_idx on public.post_helpful (user_id);
comment on table public.post_helpful is 'One Helpful per user per post. Toggle via insert/delete.';

-- --------------------------------------------------------------------------
-- bookmarks
-- --------------------------------------------------------------------------
create table public.bookmarks (
  user_id uuid not null references public.profiles (id) on delete cascade,
  post_id uuid not null references public.posts (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create index bookmarks_post_id_idx on public.bookmarks (post_id);
create index bookmarks_user_id_idx on public.bookmarks (user_id);
comment on table public.bookmarks is 'Private bookmarks per user.';

-- --------------------------------------------------------------------------
-- Comment author + alias enforcement
-- --------------------------------------------------------------------------
create or replace function public.set_comment_author_and_alias()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid;
  v_alias text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  if new.author_id is distinct from v_uid then
    new.author_id := v_uid;
  end if;

  if new.is_pseudonymous then
    if tg_op = 'INSERT' or old.anonymous_alias is null then
      v_alias := 'Siswa Anonim #' || upper(substring(encode(extensions.digest(gen_random_uuid()::text || clock_timestamp()::text, 'sha256'), 'hex') from 1 for 4));
      new.anonymous_alias := v_alias;
    else
      if new.anonymous_alias is distinct from old.anonymous_alias then
        new.anonymous_alias := old.anonymous_alias;
      end if;
    end if;
  else
    new.anonymous_alias := null;
  end if;

  if tg_op = 'INSERT' and new.deleted_at is not null then
    raise exception 'Cannot set deleted_at on insert.';
  end if;

  return new;
end;
$$;

create trigger comments_set_author_alias
  before insert or update on public.comments
  for each row execute function public.set_comment_author_and_alias();

create or replace function public.guard_comment_author()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.author_id is distinct from old.author_id then
    raise exception 'Cannot change comment author.';
  end if;
  return new;
end;
$$;

create trigger comments_guard_author
  before update on public.comments
  for each row execute function public.guard_comment_author();

-- --------------------------------------------------------------------------
-- Reply depth + parent integrity (max 1 level)
-- --------------------------------------------------------------------------
create or replace function public.check_comment_parent()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_post uuid;
  v_parent_parent uuid;
  v_parent_deleted timestamptz;
  v_post_deleted timestamptz;
begin
  -- Ensure post not deleted
  select deleted_at into v_post_deleted from public.posts where id = new.post_id;
  if not found then
    raise exception 'Post not found.';
  end if;
  if v_post_deleted is not null then
    raise exception 'Post has been deleted.';
  end if;

  if new.parent_id is not null then
    select post_id, parent_id, deleted_at into v_parent_post, v_parent_parent, v_parent_deleted
      from public.comments where id = new.parent_id;
    if not found then
      raise exception 'Parent comment not found.';
    end if;
    if v_parent_deleted is not null then
      raise exception 'Parent comment has been deleted.';
    end if;
    if v_parent_post <> new.post_id then
      raise exception 'Parent comment does not belong to same post.';
    end if;
    if v_parent_parent is not null then
      raise exception 'Replies only allowed one level deep.';
    end if;
  end if;
  return new;
end;
$$;

create trigger comments_check_parent
  before insert or update on public.comments
  for each row execute function public.check_comment_parent();

-- --------------------------------------------------------------------------
-- Best Answer enforcement
-- --------------------------------------------------------------------------
create or replace function public.check_best_answer()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_post_type text;
  v_post_author uuid;
  v_post_deleted timestamptz;
begin
  if new.is_best_answer = false then
    return new;
  end if;

  -- Must be set on not-deleted comment
  if new.deleted_at is not null then
    raise exception 'Deleted comment cannot be best answer.';
  end if;

  select type, author_id, deleted_at into v_post_type, v_post_author, v_post_deleted
    from public.posts where id = new.post_id;
  if not found then
    raise exception 'Post not found.';
  end if;
  if v_post_deleted is not null then
    raise exception 'Post has been deleted.';
  end if;
  if v_post_type <> 'question' then
    raise exception 'Only question posts can have best answer.';
  end if;
  if v_post_author <> auth.uid() then
    raise exception 'Only post author can mark best answer.';
  end if;

  -- uniqueness enforced by partial unique index, but provide friendly error
  -- If trigger runs before index, we let index raise; trigger just ensures owner/type
  return new;
end;
$$;

create trigger comments_check_best_answer
  before insert or update on public.comments
  for each row execute function public.check_best_answer();

-- --------------------------------------------------------------------------
-- Prevent helpful/bookmark on deleted post
-- --------------------------------------------------------------------------
create or replace function public.check_helpful_post_not_deleted()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_deleted timestamptz;
begin
  select deleted_at into v_deleted from public.posts where id = new.post_id;
  if v_deleted is not null then
    raise exception 'Post has been deleted.';
  end if;
  return new;
end;
$$;

create trigger post_helpful_check_post
  before insert on public.post_helpful
  for each row execute function public.check_helpful_post_not_deleted();

create trigger bookmarks_check_post
  before insert on public.bookmarks
  for each row execute function public.check_helpful_post_not_deleted();

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.comments enable row level security;
alter table public.post_helpful enable row level security;
alter table public.bookmarks enable row level security;

-- comments: authenticated can read active comments
create policy comments_select_active
  on public.comments for select to authenticated
  using ((deleted_at is null) or (author_id = auth.uid()));

create policy comments_insert_own
  on public.comments for insert to authenticated
  with check (author_id = auth.uid() and deleted_at is null);

create policy comments_update_own
  on public.comments for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

-- No hard DELETE policy for comments — soft delete only.

-- post_helpful
create policy post_helpful_select_all
  on public.post_helpful for select to authenticated
  using (true);

create policy post_helpful_insert_own
  on public.post_helpful for insert to authenticated
  with check (user_id = auth.uid());

create policy post_helpful_delete_own
  on public.post_helpful for delete to authenticated
  using (user_id = auth.uid());

-- bookmarks: only own rows
create policy bookmarks_select_own
  on public.bookmarks for select to authenticated
  using (user_id = auth.uid());

create policy bookmarks_insert_own
  on public.bookmarks for insert to authenticated
  with check (user_id = auth.uid());

create policy bookmarks_delete_own
  on public.bookmarks for delete to authenticated
  using (user_id = auth.uid());

-- --------------------------------------------------------------------------
-- Privacy-safe comments feed view
-- --------------------------------------------------------------------------
create view public.comments_feed
with (security_invoker = false) as
select
  c.id,
  c.post_id,
  c.parent_id,
  c.content,
  c.is_pseudonymous,
  case when c.is_pseudonymous then c.anonymous_alias else pr.pseudonym end as display_author,
  c.is_best_answer,
  c.created_at,
  c.updated_at
from public.comments c
left join public.profiles pr on pr.id = c.author_id
where c.deleted_at is null;

comment on view public.comments_feed is 'Privacy-safe comments. display_author = pseudonym for public, anonymous_alias for pseudonymous. SECURITY DEFINER so it can read profiles, but never exposes real pseudonym for pseudonymous.';

-- --------------------------------------------------------------------------
-- Recreate posts_feed with helpful/bookmark aggregates
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
join public.subjects s on s.id = p.subject_id
left join public.topics t on t.id = p.topic_id
left join public.profiles pr on pr.id = p.author_id
left join (select post_id, count(*) as cnt from public.post_helpful group by post_id) h on h.post_id = p.id
left join (select post_id, count(*) as cnt from public.comments where deleted_at is null group by post_id) c on c.post_id = p.id
where p.deleted_at is null;

comment on view public.posts_feed is 'Privacy-safe feed with aggregates. display_author = pseudonym or anonymous_alias. helpful/bookmark columns are per auth.uid().';

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.comments from anon, authenticated, public;
revoke all privileges on public.post_helpful from anon, authenticated, public;
revoke all privileges on public.bookmarks from anon, authenticated, public;

grant select, insert, update on public.comments to authenticated;
grant select, insert, delete on public.post_helpful to authenticated;
grant select, insert, delete on public.bookmarks to authenticated;

revoke all privileges on public.comments_feed from anon, public;
grant select on public.comments_feed to authenticated;

revoke all privileges on public.posts_feed from anon, public;
grant select on public.posts_feed to authenticated;

grant execute on function public.set_comment_author_and_alias() to authenticated;
grant execute on function public.guard_comment_author() to authenticated;
grant execute on function public.check_comment_parent() to authenticated;
grant execute on function public.check_best_answer() to authenticated;
grant execute on function public.check_helpful_post_not_deleted() to authenticated;

revoke execute on function public.set_comment_author_and_alias() from public, anon;
revoke execute on function public.guard_comment_author() from public, anon;
revoke execute on function public.check_comment_parent() from public, anon;
revoke execute on function public.check_best_answer() from public, anon;
revoke execute on function public.check_helpful_post_not_deleted() from public, anon;

commit;
