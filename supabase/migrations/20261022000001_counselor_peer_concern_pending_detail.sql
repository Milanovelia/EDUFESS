-- Migration: allow counselors to view details of pending concerns in queue
-- before claiming, as well as concerns assigned to them.
--
-- Preserves privacy:
-- - Role must be counselor.
-- - If handled_by is set, only that specific counselor can view it.
-- - If pending (handled_by is null), any counselor may inspect the details.

create or replace function public.get_counselor_peer_concern_detail(p_concern_id uuid)
returns table (
  concern_id uuid,
  target_display text,
  reason text,
  details text,
  status text,
  created_at timestamptz,
  handled_at timestamptz,
  closed_at timestamptz,
  resolution_note text,
  reporter_response text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_role text;
  v_rec public.bk_peer_concerns%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_rec from public.bk_peer_concerns where id = p_concern_id;
  if not found then raise exception 'Concern not found.'; end if;

  -- Allow if assigned to caller, OR if concern is pending and unclaimed
  if v_rec.handled_by is distinct from v_uid then
    if v_rec.handled_by is not null or v_rec.status is distinct from 'pending' then
      raise exception 'Not assigned counselor.';
    end if;
  end if;

  return query
    select pc.id as concern_id,
           tp.pseudonym as target_display,
           pc.reason,
           pc.details,
           pc.status,
           pc.created_at,
           pc.handled_at,
           pc.closed_at,
           pc.resolution_note,
           pc.reporter_response
    from public.bk_peer_concerns pc
    join public.profiles tp on tp.id = pc.target_student_id
    where pc.id = p_concern_id;
end;
$$;

comment on function public.get_counselor_peer_concern_detail(uuid) is
  'Counselor concern detail view. Accessible to assigned counselor, or any counselor if pending in queue.';

revoke all on function public.get_counselor_peer_concern_detail(uuid) from public, anon;
grant execute on function public.get_counselor_peer_concern_detail(uuid) to authenticated;
