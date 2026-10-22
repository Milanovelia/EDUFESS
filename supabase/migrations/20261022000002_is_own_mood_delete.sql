-- ==========================================================================
-- EduFess — P2/P3: is_own in comments_feed + mood soft-delete
--
-- 1. Rebuild comments_feed to include is_own (author_id = auth.uid()).
--    This lets clients show owner-only actions without exposing author_id.
-- 2. Add deleted_at to bk_mood_checkins for student-initiated soft-delete.
-- 3. Add delete_mood_checkin RPC (security definer, student only, own data).
-- 4. Update get_student_bk_mood_history to exclude soft-deleted entries.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- 1. Rebuild comments_feed with is_own
-- --------------------------------------------------------------------------
drop view if exists public.comments_feed;

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
  c.updated_at,
  -- is_own: true when the requesting user authored this comment.
  -- Safe: never reveals real identity; just a boolean for owner-actions.
  (c.author_id = auth.uid()) as is_own
from public.comments c
left join public.profiles pr on pr.id = c.author_id
where c.deleted_at is null;

comment on view public.comments_feed is
  'Privacy-safe comments. display_author resolved server-side. '
  'is_own=true only for the authenticated author (never reveals identity to others).';

revoke all privileges on public.comments_feed from anon, public;
grant select on public.comments_feed to authenticated;

-- --------------------------------------------------------------------------
-- 2. Add deleted_at to bk_mood_checkins
-- --------------------------------------------------------------------------
alter table public.bk_mood_checkins
  add column if not exists deleted_at timestamptz;

-- --------------------------------------------------------------------------
-- 3. delete_mood_checkin RPC — student deletes own check-in
-- --------------------------------------------------------------------------
create or replace function public.delete_mood_checkin(p_checkin_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_owner uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated.';
  end if;

  select student_id into v_owner
    from public.bk_mood_checkins
   where id = p_checkin_id and deleted_at is null;

  if not found then
    raise exception 'Check-in not found or already deleted.';
  end if;

  if v_owner is distinct from v_uid then
    raise exception 'Not authorized.';
  end if;

  update public.bk_mood_checkins
     set deleted_at = now()
   where id = p_checkin_id;
end;
$$;

revoke all privileges on function public.delete_mood_checkin(uuid) from public, anon;
grant execute on function public.delete_mood_checkin(uuid) to authenticated;

-- --------------------------------------------------------------------------
-- 4. Update get_student_bk_mood_history to exclude soft-deleted
-- --------------------------------------------------------------------------
create or replace function public.get_student_bk_mood_history(
  p_limit  int default 30,
  p_offset int default 0
)
returns table (checkin_id uuid, mood_level smallint, note text, checked_in_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid;
  v_limit  int;
  v_offset int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  v_limit  := coalesce(p_limit,  30);
  if v_limit  < 1  then v_limit  := 1;   end if;
  if v_limit  > 100 then v_limit  := 100; end if;
  v_offset := coalesce(p_offset, 0);
  if v_offset < 0  then v_offset := 0;   end if;

  return query
    select mc.id as checkin_id, mc.mood_level, mc.note, mc.checked_in_at
      from public.bk_mood_checkins mc
     where mc.student_id = v_uid
       and mc.deleted_at is null          -- exclude soft-deleted
     order by mc.checked_in_at desc
     limit v_limit offset v_offset;
end;
$$;

revoke all privileges on function public.get_student_bk_mood_history(int,int) from public, anon;
grant execute on function public.get_student_bk_mood_history(int,int) to authenticated;

commit;
