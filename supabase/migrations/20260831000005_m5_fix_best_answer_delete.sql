-- Allow soft-delete of best-answer comment via moderation or owner
-- Original check_best_answer blocked any deleted comment with is_best_answer=true,
-- which prevented admin from removing a best-answer comment.
-- For moderation, removed content should clear has_best_answer (view filters deleted_at).
-- Fix: when setting deleted_at, automatically clear is_best_answer.

begin;

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
  -- If clearing best flag, always allow
  if new.is_best_answer = false then
    return new;
  end if;

  -- If this update is soft-deleting a best-answer comment, allow by clearing flag
  -- (moderation or owner deletes best answer; has_best_answer will become false)
  if new.deleted_at is not null then
    if old.deleted_at is null and new.deleted_at is not null then
      -- Transition to deleted: clear best flag and allow
      new.is_best_answer := false;
      return new;
    end if;
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

  return new;
end;
$$;

-- Also update moderate_report to explicitly clear is_best_answer when removing comment
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
    if v_report.target_type = 'post' then
      update public.posts set deleted_at = now() where id = v_report.post_id and deleted_at is null;
    else
      -- Clear best answer before soft-delete to avoid trigger block; trigger also handles but we do explicit
      update public.comments set is_best_answer = false where id = v_report.comment_id and is_best_answer = true;
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

comment on function public.check_best_answer() is 'Best answer enforcement, now allows soft-delete of best answer by clearing flag.';
comment on function public.moderate_report(uuid, text, text) is 'Admin moderation. Verifies admin, locks report pending, applies dismiss or soft-delete (clears best answer if needed), updates report, appends audit.';

revoke execute on function public.check_best_answer() from public, anon;
grant execute on function public.check_best_answer() to authenticated;
revoke all privileges on function public.moderate_report(uuid, text, text) from public, anon;
grant execute on function public.moderate_report(uuid, text, text) to authenticated;

commit;
