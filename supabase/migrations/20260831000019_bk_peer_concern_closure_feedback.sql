-- ==========================================================================
-- EduFess — BK peer concern closure feedback + auditable timestamps
--
-- Changes:
--   1. Add reporter_response (nullable, student-visible counselor reply).
--   2. Add closed_at (nullable, set once on resolve/dismiss, never edited).
--   3. Fix lifecycle flaw: claim sets handled_at; resolve/dismiss used to
--      overwrite it. From now on resolve/dismiss leave handled_at alone
--      and set closed_at instead, preserving the claim time.
--   4. Backfill historical closed rows: closed_at = handled_at where
--      status in (resolved, dismissed) and closed_at is null. Historical
--      claim time cannot be recovered (handled_at already held closure
--      time on those rows); do not fabricate it.
--   5. resolve/dismiss accept p_reporter_response (default null, so old
--      single-note callers keep working) alongside p_resolution_note.
--   6. Projections: student history gains closed_at + reporter_response
--      (resolution_note stays unavailable by design — M11 H7 preserved);
--      counselor detail/history gain closed_at, resolution_note and
--      reporter_response for closure review.
--
-- Privacy impact:
--   - resolution_note remains counselor-internal; it is exposed only in
--     counselor-role projections, never in student projections.
--   - reporter_response is explicitly student-visible and appears only
--     in the reporter's own history projection.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- Columns
-- --------------------------------------------------------------------------
alter table public.bk_peer_concerns
  add column if not exists reporter_response text check (reporter_response is null or char_length(reporter_response) between 1 and 2000);

alter table public.bk_peer_concerns
  add column if not exists closed_at timestamptz;

-- --------------------------------------------------------------------------
-- Backfill historical closed rows (claim time unrecoverable — documented)
-- --------------------------------------------------------------------------
update public.bk_peer_concerns
  set closed_at = handled_at, updated_at = now()
  where status in ('resolved','dismissed')
    and closed_at is null;

-- --------------------------------------------------------------------------
-- resolve/dismiss: keep handled_at, set closed_at + both notes
-- --------------------------------------------------------------------------
drop function if exists public.resolve_bk_peer_concern(uuid,text);
drop function if exists public.dismiss_bk_peer_concern(uuid,text);

create or replace function public.resolve_bk_peer_concern(p_concern_id uuid, p_resolution_note text, p_reporter_response text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype; v_note text; v_response text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  v_note := nullif(btrim(coalesce(p_resolution_note,'')), '');
  if v_note is not null and char_length(v_note) > 2000 then raise exception 'Note too long.'; end if;
  v_response := nullif(btrim(coalesce(p_reporter_response,'')), '');
  if v_response is not null and char_length(v_response) > 2000 then raise exception 'Response too long.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id for update;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.handled_by is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_rec.status not in ('pending','reviewing') then raise exception 'Only pending/reviewing can be resolved.'; end if;
  update public.bk_peer_concerns set status='resolved', closed_at=now(), resolution_note=v_note, reporter_response=v_response, updated_at=now() where id=p_concern_id;
end;
$$;

create or replace function public.dismiss_bk_peer_concern(p_concern_id uuid, p_resolution_note text, p_reporter_response text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype; v_note text; v_response text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  v_note := nullif(btrim(coalesce(p_resolution_note,'')), '');
  if v_note is not null and char_length(v_note) > 2000 then raise exception 'Note too long.'; end if;
  v_response := nullif(btrim(coalesce(p_reporter_response,'')), '');
  if v_response is not null and char_length(v_response) > 2000 then raise exception 'Response too long.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id for update;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.handled_by is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_rec.status not in ('pending','reviewing') then raise exception 'Only pending/reviewing can be dismissed.'; end if;
  update public.bk_peer_concerns set status='dismissed', closed_at=now(), resolution_note=v_note, reporter_response=v_response, updated_at=now() where id=p_concern_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Student projection: + closed_at + reporter_response.
-- resolution_note MUST stay out (M11 H7).
-- --------------------------------------------------------------------------
drop function if exists public.get_student_peer_concerns();

create or replace function public.get_student_peer_concerns()
returns table (concern_id uuid, target_display text, reason text, details text, status text, created_at timestamptz, handled_at timestamptz, closed_at timestamptz, reporter_response text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  return query
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.details, pc.status, pc.created_at, pc.handled_at, pc.closed_at, pc.reporter_response
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.reporter_id = v_uid
    order by pc.created_at desc;
end;
$$;

-- --------------------------------------------------------------------------
-- Counselor detail projection: + handled_at + closed_at + both notes.
-- --------------------------------------------------------------------------
drop function if exists public.get_counselor_peer_concern_detail(uuid);

create or replace function public.get_counselor_peer_concern_detail(p_concern_id uuid)
returns table (concern_id uuid, target_display text, reason text, details text, status text, created_at timestamptz, handled_at timestamptz, closed_at timestamptz, resolution_note text, reporter_response text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_rec from public.bk_peer_concerns where id=p_concern_id;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.handled_by is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  return query
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.details, pc.status, pc.created_at, pc.handled_at, pc.closed_at, pc.resolution_note, pc.reporter_response
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.id = p_concern_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Counselor history projection: + closed_at + both notes.
-- --------------------------------------------------------------------------
drop function if exists public.get_counselor_peer_concern_history();

create or replace function public.get_counselor_peer_concern_history()
returns table (concern_id uuid, target_display text, reason text, status text, created_at timestamptz, handled_at timestamptz, closed_at timestamptz, resolution_note text, reporter_response text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id=v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  return query
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.status, pc.created_at, pc.handled_at, pc.closed_at, pc.resolution_note, pc.reporter_response
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.handled_by = v_uid and pc.status in ('reviewing','resolved','dismissed')
    order by pc.updated_at desc;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants (dropping a function removes its old ACL entries, so only the
-- new signatures need revoke+grant; role and ownership stay enforced
-- inside the functions)
-- --------------------------------------------------------------------------
revoke all privileges on function public.resolve_bk_peer_concern(uuid,text,text) from public, anon;
revoke all privileges on function public.dismiss_bk_peer_concern(uuid,text,text) from public, anon;
revoke all privileges on function public.get_student_peer_concerns() from public, anon;
revoke all privileges on function public.get_counselor_peer_concern_detail(uuid) from public, anon;
revoke all privileges on function public.get_counselor_peer_concern_history() from public, anon;
grant execute on function public.resolve_bk_peer_concern(uuid,text,text) to authenticated;
grant execute on function public.dismiss_bk_peer_concern(uuid,text,text) to authenticated;
grant execute on function public.get_student_peer_concerns() to authenticated;
grant execute on function public.get_counselor_peer_concern_detail(uuid) to authenticated;
grant execute on function public.get_counselor_peer_concern_history() to authenticated;

commit;
