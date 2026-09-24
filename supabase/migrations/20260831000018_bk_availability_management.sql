-- ==========================================================================
-- EduFess — BK availability management (counselor edit + deactivate)
--
-- Adds two narrowly-scoped SECURITY DEFINER RPCs so a counselor can
-- manage ONLY their own future availability slots:
--   - update_counselor_availability: change date/start/end of an
--     unbooked, active, future slot.
--   - deactivate_counselor_availability: soft-delete (is_active = false)
--     an unbooked slot so it disappears from student discovery.
--
-- Safety (all enforced server-side, never by Flutter):
--   - auth.uid() must own the row (counselor_id) and role = counselor.
--   - Slots with a pending/accepted appointment can neither be edited
--     nor deactivated (appointment integrity preserved).
--   - Past slots cannot be edited; edits validate start < end and reuse
--     the same past/duplicate guards as creation.
--   - Physical DELETE is never performed by these functions; the
--     existing partial unique index (where is_active) lets a deactivated
--     slot's values be reused for a fresh slot.
--   - Student discovery (get_available_counseling_slots) already filters
--     is_active = true, so deactivated slots vanish automatically.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- update_counselor_availability
-- --------------------------------------------------------------------------
create or replace function public.update_counselor_availability(p_availability_id uuid, p_available_date date, p_start_time time, p_end_time time)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_slot public.counselor_availability%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_slot from public.counselor_availability where id = p_availability_id for update;
  if not found then raise exception 'Slot tidak ditemukan.'; end if;
  if v_slot.counselor_id is distinct from v_uid then raise exception 'Not authorized.'; end if;
  if not v_slot.is_active then raise exception 'Slot tidak aktif.'; end if;
  if p_available_date is null or p_start_time is null or p_end_time is null then raise exception 'Invalid slot.'; end if;
  if p_start_time >= p_end_time then raise exception 'Invalid time.'; end if;
  if p_available_date < current_date then raise exception 'Past slot.'; end if;
  if p_available_date = current_date and p_start_time <= current_time then raise exception 'Past slot.'; end if;
  if exists (select 1 from public.bk_appointments ba where ba.availability_id = p_availability_id and ba.status in ('pending','accepted')) then
    raise exception 'Slot ini sudah dipesan sehingga tidak bisa diubah.';
  end if;
  update public.counselor_availability
    set available_date = p_available_date, start_time = p_start_time, end_time = p_end_time, updated_at = now()
    where id = p_availability_id;
exception when unique_violation then
  raise exception 'Slot sudah ada.';
end;
$$;

-- --------------------------------------------------------------------------
-- deactivate_counselor_availability (soft-delete via is_active = false)
-- --------------------------------------------------------------------------
create or replace function public.deactivate_counselor_availability(p_availability_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_slot public.counselor_availability%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_slot from public.counselor_availability where id = p_availability_id for update;
  if not found then raise exception 'Slot tidak ditemukan.'; end if;
  if v_slot.counselor_id is distinct from v_uid then raise exception 'Not authorized.'; end if;
  -- Idempotent: deactivating an already-inactive slot succeeds silently.
  if not v_slot.is_active then return; end if;
  if exists (select 1 from public.bk_appointments ba where ba.availability_id = p_availability_id and ba.status in ('pending','accepted')) then
    raise exception 'Slot ini sudah dipesan sehingga tidak bisa dinonaktifkan.';
  end if;
  update public.counselor_availability set is_active = false, updated_at = now() where id = p_availability_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants (match M9 convention: revoke public/anon, grant authenticated;
-- role and ownership are enforced inside the functions)
-- --------------------------------------------------------------------------
revoke all privileges on function public.update_counselor_availability(uuid,date,time,time) from public, anon;
revoke all privileges on function public.deactivate_counselor_availability(uuid) from public, anon;
grant execute on function public.update_counselor_availability(uuid,date,time,time) to authenticated;
grant execute on function public.deactivate_counselor_availability(uuid) to authenticated;

commit;
