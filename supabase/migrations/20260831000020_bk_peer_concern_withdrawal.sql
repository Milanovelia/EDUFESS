-- ==========================================================================
-- EduFess — BK peer concern reporter withdrawal
--
-- Adds a reporter-only withdrawal path for still-pending concerns:
--   - New terminal status 'withdrawn' + reporter-owned timestamp
--     withdrawn_at (handled_at/closed_at keep their counselor meanings
--     and stay NULL on withdrawn rows).
--   - New RPC withdraw_bk_peer_concern(): the original reporter, while
--     the concern is still pending and unclaimed, moves it to withdrawn
--     atomically (row lock + conditional update, so a simultaneous
--     counselor claim cannot produce a mixed withdrawn+handled state).
--   - Student history projection gains withdrawn_at; counselor queue
--     (pending + handled_by null) and counselor history/detail
--     (handled_by = caller) exclude never-claimed withdrawn rows by
--     their existing predicates — minimum disclosure preserved.
--   - The duplicate-active partial index already covers only
--     ('pending','reviewing'), so a withdrawn reporter may submit a new
--     concern for the same target later. No index change needed.
--   - No notification is emitted for withdrawal (the reporter acted
--     themselves; the notify trigger only handles
--     reviewing/resolved/dismissed transitions).
--
-- Privacy impact:
--   - No new counselor-visible fields; withdrawn-before-claim rows stay
--     invisible to counselors (queue/history/detail predicates).
--   - Consent is intentionally NOT required for withdrawal: a student
--     must never be trapped from retracting their own pending report
--     because of a later consent state change. Consent stays mandatory
--     for submit, counseling, mood and appointments.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- Status vocabulary + withdrawn_at
-- --------------------------------------------------------------------------
alter table public.bk_peer_concerns
  drop constraint if exists bk_peer_concerns_status_check;

alter table public.bk_peer_concerns
  add constraint bk_peer_concerns_status_check
  check (status in ('pending','reviewing','resolved','dismissed','withdrawn'));

alter table public.bk_peer_concerns
  add column if not exists withdrawn_at timestamptz;

-- --------------------------------------------------------------------------
-- withdraw_bk_peer_concern
-- --------------------------------------------------------------------------
create or replace function public.withdraw_bk_peer_concern(p_concern_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_rec public.bk_peer_concerns%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Not authorized.'; end if;
  -- Lock the row so a simultaneous counselor claim serializes: exactly
  -- one of withdraw/claim wins; the loser sees the committed state.
  select * into v_rec from public.bk_peer_concerns where id = p_concern_id for update;
  if not found then raise exception 'Concern not found.'; end if;
  if v_rec.reporter_id is distinct from v_uid then raise exception 'Not authorized.'; end if;
  if v_rec.status = 'withdrawn' then raise exception 'Laporan ini sudah ditarik.'; end if;
  if v_rec.status in ('resolved','dismissed') then raise exception 'Laporan yang sudah selesai tidak dapat ditarik.'; end if;
  if v_rec.status <> 'pending' or v_rec.handled_by is not null then
    raise exception 'Laporan sudah mulai ditangani dan tidak dapat ditarik.';
  end if;
  -- Conditional update: if a claim committed between our lock and this
  -- write (cannot happen while we hold the lock, belt-and-braces), fail.
  update public.bk_peer_concerns
    set status = 'withdrawn', withdrawn_at = now(), updated_at = now()
    where id = p_concern_id and status = 'pending' and handled_by is null;
  if not found then
    raise exception 'Laporan sudah mulai ditangani dan tidak dapat ditarik.';
  end if;
end;
$$;

-- --------------------------------------------------------------------------
-- Student projection: + withdrawn_at (still no counselor-private fields)
-- --------------------------------------------------------------------------
drop function if exists public.get_student_peer_concerns();

create or replace function public.get_student_peer_concerns()
returns table (concern_id uuid, target_display text, reason text, details text, status text, created_at timestamptz, handled_at timestamptz, closed_at timestamptz, reporter_response text, withdrawn_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  return query
    select pc.id as concern_id, tp.pseudonym as target_display, pc.reason, pc.details, pc.status, pc.created_at, pc.handled_at, pc.closed_at, pc.reporter_response, pc.withdrawn_at
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.reporter_id = v_uid
    order by pc.created_at desc;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants (function is new, so revoke is defensive; role and ownership stay
-- enforced inside the function)
-- --------------------------------------------------------------------------
revoke all privileges on function public.withdraw_bk_peer_concern(uuid) from public, anon;
grant execute on function public.withdraw_bk_peer_concern(uuid) to authenticated;
revoke all privileges on function public.get_student_peer_concerns() from public, anon;
grant execute on function public.get_student_peer_concerns() to authenticated;

commit;
