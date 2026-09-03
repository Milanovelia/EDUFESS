-- ==========================================================================
-- EduFess — M5: social moderation
--
-- Creates:
--   public.content_reports     (private reports, pending/resolved/dismissed)
--   public.moderation_actions  (append-only audit trail)
--   functions:
--     public.report_content      (student report, duplicate-safe)
--     public.moderate_report     (admin dismiss/remove)
--     public.get_moderation_queue (admin privacy-safe queue)
--   triggers for reporter enforcement + target validation
--   RLS + grants scoped to social moderation only
--   indexes
--
-- Design:
--   - content_reports: target_type post|comment, exactly one of post_id/comment_id
--     NOT NULL matching target_type, reason enum, status enum, reporter forced
--     to auth.uid(), duplicate pending prevented via partial unique indexes
--     (same reporter + same target + pending). New report allowed after prior
--     resolved/dismissed (documented).
--   - report target validity: must exist and not deleted (deleted_at is null)
--     enforced server-side via trigger.
--   - moderation_actions: append-only, moderator is auth.uid() verified admin,
--     target mirrors report, action enum dismiss_report/remove_content/hide_content/restore_content
--     (hide_content treated as soft-delete same as remove_content for MVP).
--   - admin authorization server-side via profiles.role='admin' lookup (never
--     from client).
--   - BK isolation: no grants, no policies, no functions reference BK tables;
--     admin moderation only touches posts/comments/reports/actions.
--   - content removal reuses soft-delete (deleted_at = now()) via
--     SECURITY DEFINER so admin can moderate any content.
--   - privacy: queue returns display_author (alias for pseudonymous) via same
--     CASE as posts_feed/comments_feed, never email/raw pseudonym; reporter
--     identity not exposed to normal students.
--   - SECURITY DEFINER with fixed search_path = '' and schema-qualified refs.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- content_reports
-- --------------------------------------------------------------------------
create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('post','comment')),
  post_id uuid references public.posts (id) on delete cascade,
  comment_id uuid references public.comments (id) on delete cascade,
  reason text not null check (reason in ('spam','harassment','hate','sexual','violence','misinformation','privacy','other')),
  details text check (details is null or char_length(details) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending','resolved','dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles (id) on delete set null,
  check (
    (target_type = 'post' and post_id is not null and comment_id is null)
    or
    (target_type = 'comment' and comment_id is not null and post_id is null)
  )
);

comment on table public.content_reports is 'Private social moderation reports. One pending per reporter per target (partial unique index). New report allowed after prior resolved/dismissed.';

create index content_reports_reporter_id_idx on public.content_reports (reporter_id);
create index content_reports_status_created_idx on public.content_reports (status, created_at desc);
create index content_reports_post_id_idx on public.content_reports (post_id) where post_id is not null;
create index content_reports_comment_id_idx on public.content_reports (comment_id) where comment_id is not null;

-- Duplicate pending prevention: one pending per reporter per target
create unique index content_reports_pending_post_unique
  on public.content_reports (reporter_id, post_id)
  where status = 'pending' and post_id is not null;

create unique index content_reports_pending_comment_unique
  on public.content_reports (reporter_id, comment_id)
  where status = 'pending' and comment_id is not null;

-- --------------------------------------------------------------------------
-- moderation_actions
-- --------------------------------------------------------------------------
create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.content_reports (id) on delete set null,
  moderator_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('post','comment')),
  post_id uuid references public.posts (id) on delete set null,
  comment_id uuid references public.comments (id) on delete set null,
  action text not null check (action in ('dismiss_report','hide_content','remove_content','restore_content')),
  reason text check (reason is null or char_length(reason) between 1 and 500),
  created_at timestamptz not null default now(),
  check (
    (target_type = 'post' and post_id is not null and comment_id is null)
    or
    (target_type = 'comment' and comment_id is not null and post_id is null)
  )
);

comment on table public.moderation_actions is 'Append-only moderation audit trail. Students never modify.';

create index moderation_actions_report_id_idx on public.moderation_actions (report_id) where report_id is not null;
create index moderation_actions_created_at_idx on public.moderation_actions (created_at desc);
create index moderation_actions_moderator_id_idx on public.moderation_actions (moderator_id);

-- --------------------------------------------------------------------------
-- Helper: force reporter_id = auth.uid()
-- --------------------------------------------------------------------------
create or replace function public.set_report_reporter()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if new.reporter_id is distinct from v_uid then new.reporter_id := v_uid; end if;
  if new.status is distinct from 'pending' then
    -- Only allow pending on insert; status transitions only via moderate_report
    if tg_op = 'INSERT' then new.status := 'pending'; end if;
  end if;
  if new.reviewed_at is not null or new.reviewed_by is not null then
    raise exception 'Cannot set reviewed fields on insert.';
  end if;
  return new;
end;
$$;

create trigger content_reports_set_reporter
  before insert on public.content_reports
  for each row execute function public.set_report_reporter();

-- --------------------------------------------------------------------------
-- Helper: validate report target exists and not deleted, reason etc.
-- --------------------------------------------------------------------------
create or replace function public.check_report_target()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_deleted timestamptz;
begin
  if new.target_type = 'post' then
    select deleted_at into v_deleted from public.posts where id = new.post_id;
    if not found then raise exception 'Post not found.'; end if;
    if v_deleted is not null then raise exception 'Post has been deleted.'; end if;
  elsif new.target_type = 'comment' then
    select deleted_at into v_deleted from public.comments where id = new.comment_id;
    if not found then raise exception 'Comment not found.'; end if;
    if v_deleted is not null then raise exception 'Comment has been deleted.'; end if;
  end if;
  return new;
end;
$$;

create trigger content_reports_check_target
  before insert on public.content_reports
  for each row execute function public.check_report_target();

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.content_reports enable row level security;
alter table public.moderation_actions enable row level security;

-- content_reports: students can insert own report, select own reports; no update/delete via RLS (admin via definer)
create policy content_reports_select_own
  on public.content_reports for select to authenticated
  using (reporter_id = auth.uid());

create policy content_reports_insert_own
  on public.content_reports for insert to authenticated
  with check (reporter_id = auth.uid());

-- No update/delete policies for content_reports → denied unless SECURITY DEFINER
-- moderation_actions: no direct access for authenticated (append-only via RPC)
-- (no policies → default deny)

-- --------------------------------------------------------------------------
-- report_content RPC — student creates report
-- --------------------------------------------------------------------------
create or replace function public.report_content(
  p_target_type text,
  p_post_id uuid default null,
  p_comment_id uuid default null,
  p_reason text default null,
  p_details text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_id uuid;
  v_reason text;
  v_target_type text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;

  v_target_type := lower(coalesce(p_target_type, ''));
  if v_target_type not in ('post','comment') then raise exception 'Invalid target type.'; end if;

  v_reason := lower(coalesce(p_reason, ''));
  if v_reason not in ('spam','harassment','hate','sexual','violence','misinformation','privacy','other') then
    raise exception 'Invalid reason.';
  end if;

  if p_details is not null and char_length(p_details) > 1000 then
    raise exception 'Details too long.';
  end if;
  if p_details is not null and btrim(p_details) = '' then
    raise exception 'Details cannot be empty.';
  end if;

  -- Enforce XOR and matching target_type; trigger will also check
  if v_target_type = 'post' then
    if p_post_id is null or p_comment_id is not null then raise exception 'Post report requires post_id only.'; end if;
  else
    if p_comment_id is null or p_post_id is not null then raise exception 'Comment report requires comment_id only.'; end if;
  end if;

  insert into public.content_reports (reporter_id, target_type, post_id, comment_id, reason, details)
  values (v_uid, v_target_type, p_post_id, p_comment_id, v_reason, nullif(btrim(coalesce(p_details,'')), ''))
  returning id into v_id;

  return v_id;
exception when unique_violation then
  raise exception 'Konten ini sudah pernah kamu laporkan dan masih ditinjau.';
end;
$$;

comment on function public.report_content(text, uuid, uuid, text, text) is 'Student report. Forces reporter_id=auth.uid(), validates target exists & not deleted, prevents duplicate pending per reporter/target.';

-- --------------------------------------------------------------------------
-- get_moderation_queue RPC — admin only, privacy-safe
-- --------------------------------------------------------------------------
create or replace function public.get_moderation_queue()
returns table (
  report_id uuid,
  target_type text,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid,
  post_id uuid,
  comment_id uuid,
  target_title text,
  target_content text,
  display_author text,
  subject_name text,
  topic_name text,
  reporter_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
  v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'admin' then raise exception 'Not authorized.'; end if;

  return query
  select
    r.id as report_id,
    r.target_type,
    r.reason,
    r.details,
    r.status,
    r.created_at,
    r.reviewed_at,
    r.reviewed_by,
    r.post_id,
    r.comment_id,
    coalesce(p.title, cp.title) as target_title,
    coalesce(p.content, c.content) as target_content,
    -- privacy-safe display_author: alias for pseudonymous
    case
      when r.target_type = 'post' then case when p.is_pseudonymous then p.anonymous_alias else pr_p.pseudonym end
      else case when c.is_pseudonymous then c.anonymous_alias else pr_c.pseudonym end
    end as display_author,
    s.name as subject_name,
    t.name as topic_name,
    r.reporter_id
  from public.content_reports r
  left join public.posts p on p.id = r.post_id
  left join public.subjects s on s.id = coalesce(p.subject_id, cp.subject_id)
  left join public.topics t on t.id = coalesce(p.topic_id, cp.topic_id)
  left join public.profiles pr_p on pr_p.id = p.author_id
  left join public.comments c on c.id = r.comment_id
  left join public.posts cp on cp.id = c.post_id
  left join public.profiles pr_c on pr_c.id = c.author_id
  where r.status = 'pending'
  order by r.created_at asc;
end;
$$;

comment on function public.get_moderation_queue() is 'Admin-only privacy-safe queue. Returns pending reports with display_author (alias for pseudonymous), no email.';

-- --------------------------------------------------------------------------
-- moderate_report RPC — admin dismiss or remove
-- --------------------------------------------------------------------------
create or replace function public.moderate_report(
  p_report_id uuid,
  p_action text,
  p_reason text default null
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_role text;
  v_report public.content_reports%rowtype;
  v_action text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'admin' then raise exception 'Not authorized.'; end if;

  v_action := lower(coalesce(p_action, ''));
  if v_action not in ('dismiss_report','hide_content','remove_content') then
    raise exception 'Invalid action.';
  end if;

  select * into v_report from public.content_reports where id = p_report_id for update;
  if not found then raise exception 'Report not found.'; end if;
  if v_report.status <> 'pending' then raise exception 'Report already processed.'; end if;

  if v_action = 'dismiss_report' then
    update public.content_reports
      set status = 'dismissed', reviewed_at = now(), reviewed_by = v_uid
      where id = p_report_id;
    insert into public.moderation_actions (report_id, moderator_id, target_type, post_id, comment_id, action, reason)
      values (p_report_id, v_uid, v_report.target_type, v_report.post_id, v_report.comment_id, 'dismiss_report', nullif(btrim(coalesce(p_reason,'')), ''));

  elsif v_action in ('hide_content','remove_content') then
    -- Soft-delete target
    if v_report.target_type = 'post' then
      update public.posts set deleted_at = now() where id = v_report.post_id and deleted_at is null;
    else
      update public.comments set deleted_at = now() where id = v_report.comment_id and deleted_at is null;
    end if;

    update public.content_reports
      set status = 'resolved', reviewed_at = now(), reviewed_by = v_uid
      where id = p_report_id;

    insert into public.moderation_actions (report_id, moderator_id, target_type, post_id, comment_id, action, reason)
      values (p_report_id, v_uid, v_report.target_type, v_report.post_id, v_report.comment_id, 'remove_content', nullif(btrim(coalesce(p_reason,'')), ''));
  end if;
end;
$$;

comment on function public.moderate_report(uuid, text, text) is 'Admin moderation. Verifies admin, locks report pending, applies dismiss or soft-delete, updates report, appends audit.';

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.content_reports from anon, authenticated, public;
revoke all privileges on public.moderation_actions from anon, authenticated, public;

-- content_reports: authenticated can select/insert via RLS, but grant needed
grant select, insert on public.content_reports to authenticated;
-- moderation_actions: no direct grants for authenticated (definer only)
-- But allow authenticated to have no direct access; function will still work as definer

revoke all privileges on function public.report_content(text, uuid, uuid, text, text) from public, anon;
grant execute on function public.report_content(text, uuid, uuid, text, text) to authenticated;

revoke all privileges on function public.get_moderation_queue() from public, anon;
grant execute on function public.get_moderation_queue() to authenticated;

revoke all privileges on function public.moderate_report(uuid, text, text) from public, anon;
grant execute on function public.moderate_report(uuid, text, text) to authenticated;

-- Helper functions: no direct execute for anon/public
revoke execute on function public.set_report_reporter() from public, anon;
revoke execute on function public.check_report_target() from public, anon;
grant execute on function public.set_report_reporter() to authenticated;
grant execute on function public.check_report_target() to authenticated;

commit;
