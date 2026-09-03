-- Remove reporter identity from moderation queue projection
-- Content_reports.reporter_id remains in table for RLS/duplicate/audit,
-- but admin queue no longer exposes it (privacy).

begin;

drop function if exists public.get_moderation_queue();

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
  topic_name text
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
    case
      when r.target_type = 'post' then case when p.is_pseudonymous then p.anonymous_alias else pr_p.pseudonym end
      else case when c.is_pseudonymous then c.anonymous_alias else pr_c.pseudonym end
    end as display_author,
    s.name as subject_name,
    t.name as topic_name
  from public.content_reports r
  left join public.posts p on p.id = r.post_id
  left join public.comments c on c.id = r.comment_id
  left join public.posts cp on cp.id = c.post_id
  left join public.subjects s on s.id = coalesce(p.subject_id, cp.subject_id)
  left join public.topics t on t.id = coalesce(p.topic_id, cp.topic_id)
  left join public.profiles pr_p on pr_p.id = p.author_id
  left join public.profiles pr_c on pr_c.id = c.author_id
  where r.status = 'pending'
  order by r.created_at asc;
end;
$$;

comment on function public.get_moderation_queue() is 'Admin-only privacy-safe queue. Returns pending reports with display_author (alias for pseudonymous), no email, no reporter identity.';

revoke all privileges on function public.get_moderation_queue() from public, anon;
grant execute on function public.get_moderation_queue() to authenticated;

commit;
