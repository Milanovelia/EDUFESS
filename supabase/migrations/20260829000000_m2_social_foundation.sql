-- ==========================================================================
-- EduFess — M2: social foundation
--
-- Creates:
--   public.subjects
--   public.topics
--   public.posts
--   view public.posts_feed (privacy-safe, security_invoker = false)
--   triggers/functions for topic/subject consistency + alias generation
--   RLS + grants for social domain
--   seed: 3 subjects + 8 topics (idempotent)
--
-- Design decisions:
--   - subjects: id uuid pk, name, slug unique, created_at
--   - topics: fk subjects ON DELETE CASCADE, unique (subject_id, slug)
--           and unique (subject_id, lower(name))
--   - posts: fk profiles ON DELETE CASCADE, fk subjects RESTRICT,
--           fk topics SET NULL, type CHECK, soft delete via deleted_at
--   - topic/subject mismatch rejected via trigger (server-side)
--   - pseudonymous alias generated server-side, not from client
--   - display_author via posts_feed view: CASE is_pseudonymous
--           THEN anonymous_alias ELSE profiles.pseudonym END
--   - posts_feed is SECURITY DEFINER (security_invoker=false) so it can
--           read profiles.pseudonym for public posts while raw profiles
--           RLS (own-row only) still blocks direct resolution of
--           pseudonymous author_id -> pseudonym (privacy invariant)
--   - author_id forced to auth.uid() via trigger + RLS WITH CHECK
--   - reuse public.touch_updated_at() for updated_at
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- subjects
-- --------------------------------------------------------------------------
create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 64),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  created_at timestamptz not null default now()
);

comment on table public.subjects is 'Master subjects (mata pelajaran). Seeded, not user-creatable.';

-- --------------------------------------------------------------------------
-- topics
-- --------------------------------------------------------------------------
create table public.topics (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects (id) on delete cascade,
  name text not null check (char_length(name) between 2 and 64),
  slug text not null check (slug ~ '^[a-z0-9-]+$'),
  created_at timestamptz not null default now(),
  unique (subject_id, slug)
);

comment on table public.topics is 'Topics per subject. Seeded, not user-creatable.';
create unique index topics_subject_lower_name_key on public.topics (subject_id, lower(name));
create index topics_subject_id_idx on public.topics (subject_id);

-- --------------------------------------------------------------------------
-- posts
-- --------------------------------------------------------------------------
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles (id) on delete cascade,
  subject_id uuid not null references public.subjects (id) on delete restrict,
  topic_id uuid references public.topics (id) on delete set null,
  type text not null check (type in ('note','question','summary','tip','request')),
  title text not null check (char_length(title) between 1 and 200),
  content text not null check (char_length(content) between 1 and 10000),
  is_pseudonymous boolean not null default false,
  anonymous_alias text check (anonymous_alias is null or char_length(anonymous_alias) between 1 and 64),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.posts is 'Social posts. author_id always = auth.uid(). Pseudonymous posts use anonymous_alias generated server-side.';
comment on column public.posts.anonymous_alias is 'Server-generated display name for pseudonymous posts, e.g. Siswa Anonim #A1B2. Null for public posts.';

create index posts_subject_id_idx on public.posts (subject_id);
create index posts_topic_id_idx on public.posts (topic_id);
create index posts_author_id_idx on public.posts (author_id);
create index posts_created_at_idx on public.posts (created_at desc);
create index posts_feed_idx on public.posts (subject_id, topic_id, created_at desc) where deleted_at is null;

-- updated_at reuse
create trigger posts_touch_updated_at
  before update on public.posts
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------------------
-- Topic/subject consistency (server-side)
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

create trigger posts_check_topic_subject
  before insert or update on public.posts
  for each row execute function public.check_topic_subject();

-- --------------------------------------------------------------------------
-- Author + alias enforcement (server-side)
-- --------------------------------------------------------------------------
create or replace function public.set_post_author_and_alias()
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

  -- Force author_id to the authenticated user (prevents spoofing).
  if new.author_id is distinct from v_uid then
    new.author_id := v_uid;
  end if;

  -- Alias generation: server-side only.
  if new.is_pseudonymous then
    -- Always generate if null or client tried to inject arbitrary value
    -- that does not match expected pattern. Overwrite unconditionally
    -- to guarantee server control, but keep existing alias on UPDATE
    -- if already set (stable per post).
    if tg_op = 'INSERT' or old.anonymous_alias is null then
      -- Generate 4 hex chars from md5 of random + clock
      v_alias := 'Siswa Anonim #' || upper(substring(encode(extensions.digest(gen_random_uuid()::text || clock_timestamp()::text, 'sha256'), 'hex') from 1 for 4));
      new.anonymous_alias := v_alias;
    else
      -- On update, preserve existing alias; prevent client from changing it
      if new.anonymous_alias is distinct from old.anonymous_alias then
        new.anonymous_alias := old.anonymous_alias;
      end if;
    end if;
  else
    new.anonymous_alias := null;
  end if;

  -- Prevent client from setting deleted_at on insert (soft-delete only via update)
  if tg_op = 'INSERT' and new.deleted_at is not null then
    raise exception 'Cannot set deleted_at on insert.';
  end if;

  return new;
end;
$$;

create trigger posts_set_author_alias
  before insert or update on public.posts
  for each row execute function public.set_post_author_and_alias();

-- --------------------------------------------------------------------------
-- Prevent author_id change on update
-- --------------------------------------------------------------------------
create or replace function public.guard_post_author()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.author_id is distinct from old.author_id then
    raise exception 'Cannot change post author.';
  end if;
  return new;
end;
$$;

create trigger posts_guard_author
  before update on public.posts
  for each row execute function public.guard_post_author();

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.subjects enable row level security;
alter table public.topics enable row level security;
alter table public.posts enable row level security;

-- subjects: authenticated can read, no insert/update/delete for authenticated
create policy subjects_select_all
  on public.subjects for select to authenticated
  using (true);

-- topics: authenticated can read
create policy topics_select_all
  on public.topics for select to authenticated
  using (true);

-- posts: select active posts for any authenticated user
create policy posts_select_active
  on public.posts for select to authenticated
  using (deleted_at is null);

-- posts: insert own posts
create policy posts_insert_own
  on public.posts for insert to authenticated
  with check (author_id = auth.uid() and deleted_at is null);

-- posts: update own posts (allows soft-delete via deleted_at)
create policy posts_update_own
  on public.posts for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

-- No hard DELETE policy — soft delete only.

-- --------------------------------------------------------------------------
-- Privacy-safe feed view (SECURITY DEFINER via security_invoker=false)
-- Only this view returns display_author correctly; direct JOIN on
-- profiles is blocked by profiles RLS (own-row only) so raw author_id
-- cannot be resolved to pseudonym for pseudonymous posts.
-- --------------------------------------------------------------------------
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
  p.updated_at
from public.posts p
join public.subjects s on s.id = p.subject_id
left join public.topics t on t.id = p.topic_id
left join public.profiles pr on pr.id = p.author_id
where p.deleted_at is null;

comment on view public.posts_feed is 'Privacy-safe feed. display_author = pseudonym for public posts, anonymous_alias for pseudonymous posts. SECURITY DEFINER so it can read profiles bypassing own-row RLS, but never exposes real pseudonym for pseudonymous posts.';

-- --------------------------------------------------------------------------
-- Grants (defence in depth; RLS remains enforcement layer)
-- --------------------------------------------------------------------------
revoke all privileges on public.subjects from anon, authenticated, public;
revoke all privileges on public.topics from anon, authenticated, public;
revoke all privileges on public.posts from anon, authenticated, public;

grant select on public.subjects to authenticated;
grant select on public.topics to authenticated;
grant select, insert, update on public.posts to authenticated;

-- View grants
revoke all privileges on public.posts_feed from anon, public;
grant select on public.posts_feed to authenticated;

-- Function grants
grant execute on function public.check_topic_subject() to authenticated;
grant execute on function public.set_post_author_and_alias() to authenticated;
grant execute on function public.guard_post_author() to authenticated;

-- View/function execution via anon should not be allowed
revoke execute on function public.check_topic_subject() from public, anon;
revoke execute on function public.set_post_author_and_alias() from public, anon;
revoke execute on function public.guard_post_author() from public, anon;

-- Anonymous role cannot read social tables
revoke all privileges on public.posts_feed from anon;

-- --------------------------------------------------------------------------
-- Seed: subjects (idempotent)
-- --------------------------------------------------------------------------
insert into public.subjects (name, slug) values
  ('Informatika', 'informatika'),
  ('Matematika', 'matematika'),
  ('Bahasa Inggris', 'bahasa-inggris')
on conflict (slug) do nothing;

-- Topics: Informatika
insert into public.topics (subject_id, name, slug)
select s.id, v.name, v.slug
from public.subjects s
cross join (values
  ('Algoritma', 'algoritma'),
  ('Pemrograman', 'pemrograman'),
  ('Database', 'database'),
  ('Jaringan', 'jaringan')
) as v(name, slug)
where s.slug = 'informatika'
on conflict (subject_id, slug) do nothing;

-- Topics: Matematika
insert into public.topics (subject_id, name, slug)
select s.id, v.name, v.slug
from public.subjects s
cross join (values
  ('Aljabar', 'aljabar'),
  ('Trigonometri', 'trigonometri')
) as v(name, slug)
where s.slug = 'matematika'
on conflict (subject_id, slug) do nothing;

-- Topics: Bahasa Inggris
insert into public.topics (subject_id, name, slug)
select s.id, v.name, v.slug
from public.subjects s
cross join (values
  ('Grammar', 'grammar'),
  ('Vocabulary', 'vocabulary')
) as v(name, slug)
where s.slug = 'bahasa-inggris'
on conflict (subject_id, slug) do nothing;

commit;
