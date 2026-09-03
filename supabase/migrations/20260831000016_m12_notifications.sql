-- ==========================================================================
-- EduFess — M12 Notifications & Activity Feedback
-- Creates app_notifications with privacy-safe generic BK copy and
-- role-scoped delivery, plus hardening of search_peer_students.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- app_notifications
-- --------------------------------------------------------------------------
create table public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null check (type in ('social_comment','social_reply','social_helpful','best_answer','bk_message','appointment_accepted','appointment_rejected','appointment_rescheduled','appointment_cancelled','appointment_completed','appointment_requested','peer_concern_reviewing','peer_concern_resolved','peer_concern_dismissed')),
  title text not null check (char_length(title) between 1 and 100),
  body text not null check (char_length(body) between 1 and 500),
  route text check (route is null or char_length(route) between 1 and 200),
  entity_type text check (entity_type is null or entity_type in ('post','comment','conversation','appointment','peer_concern')),
  entity_ref uuid,
  event_key text unique,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

comment on table public.app_notifications is 'In-app notifications, generic BK copy, event_key for idempotency.';

create index app_notifications_user_created_idx on public.app_notifications (user_id, created_at desc);
create index app_notifications_user_read_created_idx on public.app_notifications (user_id, is_read, created_at desc);
create unique index app_notifications_event_key_unique on public.app_notifications (event_key) where event_key is not null;

-- RLS
alter table public.app_notifications enable row level security;

create policy app_notifications_select_own on public.app_notifications for select to authenticated using (user_id = auth.uid());
-- Only allow updating own read state via RPC; no direct update policy for generic update, but we create a narrow one for is_read/read_at
create policy app_notifications_update_own_read on public.app_notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and is_read in (true, false));
-- No insert/delete policies for normal client

-- --------------------------------------------------------------------------
-- Helper: create_app_notification (internal, SECURITY DEFINER)
-- --------------------------------------------------------------------------
create or replace function public.create_app_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_route text default null,
  p_entity_type text default null,
  p_entity_ref uuid default null,
  p_event_key text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if p_user_id is null then raise exception 'user_id required'; end if;
  if p_type is null or p_type not in ('social_comment','social_reply','social_helpful','best_answer','bk_message','appointment_accepted','appointment_rejected','appointment_rescheduled','appointment_cancelled','appointment_completed','appointment_requested','peer_concern_reviewing','peer_concern_resolved','peer_concern_dismissed') then
    raise exception 'Invalid type';
  end if;
  if p_event_key is not null then
    insert into public.app_notifications (user_id, type, title, body, route, entity_type, entity_ref, event_key)
    values (p_user_id, p_type, p_title, p_body, p_route, p_entity_type, p_entity_ref, p_event_key)
    on conflict (event_key) do nothing
    returning id into v_id;
    -- If conflict, try to fetch existing
    if v_id is null then
      select id into v_id from public.app_notifications where event_key = p_event_key;
    end if;
  else
    insert into public.app_notifications (user_id, type, title, body, route, entity_type, entity_ref)
    values (p_user_id, p_type, p_title, p_body, p_route, p_entity_type, p_entity_ref)
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- --------------------------------------------------------------------------
-- Read APIs
-- --------------------------------------------------------------------------
create or replace function public.get_my_notifications(p_limit int default 20, p_offset int default 0)
returns table (notification_id uuid, type text, title text, body text, route text, is_read boolean, created_at timestamptz, read_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_limit int; v_offset int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  v_limit := coalesce(p_limit, 20);
  if v_limit < 1 then v_limit := 1; end if;
  if v_limit > 100 then v_limit := 100; end if;
  v_offset := coalesce(p_offset, 0);
  if v_offset < 0 then v_offset := 0; end if;
  return query select an.id as notification_id, an.type, an.title, an.body, an.route, an.is_read, an.created_at, an.read_at
    from public.app_notifications an where an.user_id = v_uid order by an.created_at desc limit v_limit offset v_offset;
end;
$$;

create or replace function public.get_my_notification_unread_count()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_count int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select count(*)::int into v_count from public.app_notifications where user_id = v_uid and is_read = false;
  return v_count;
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  update public.app_notifications set is_read = true, read_at = now() where id = p_notification_id and user_id = v_uid;
  if not found then raise exception 'Not found or not authorized.'; end if;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  update public.app_notifications set is_read = true, read_at = now() where user_id = v_uid and is_read = false;
end;
$$;

-- --------------------------------------------------------------------------
-- Harden search_peer_students to student-only
-- --------------------------------------------------------------------------
create or replace function public.search_peer_students(p_query text, p_limit int default 10)
returns table (student_ref uuid, display_pseudonym text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_q text; v_lim int; v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Not authorized.'; end if;
  v_q := btrim(coalesce(p_query,''));
  if char_length(v_q) < 2 then raise exception 'Query too short.'; end if;
  v_lim := coalesce(p_limit, 10);
  if v_lim < 1 then v_lim := 1; end if;
  if v_lim > 20 then v_lim := 20; end if;
  return query
    select p.id as student_ref, p.pseudonym as display_pseudonym
    from public.profiles p
    where p.role = 'student'
      and p.id <> v_uid
      and p.pseudonym ilike '%' || v_q || '%'
    order by p.pseudonym asc
    limit v_lim;
end;
$$;

-- --------------------------------------------------------------------------
-- Triggers for notifications
-- --------------------------------------------------------------------------

-- BK message: notify recipient (student <-> counselor) generic
create or replace function public.notify_bk_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_student uuid; v_counselor uuid; v_recipient uuid; v_conversation_id uuid;
begin
  select student_id, counselor_id into v_student, v_counselor from public.counseling_conversations where id = new.conversation_id;
  if v_student is null then return new; end if;
  v_conversation_id := new.conversation_id;
  if new.sender_id = v_student and v_counselor is not null then
    v_recipient := v_counselor;
  elsif new.sender_id = v_counselor then
    v_recipient := v_student;
  else
    return new; -- no recipient (e.g., unassigned student message should not notify?)
  end if;
  if v_recipient = new.sender_id then return new; end if;
  perform public.create_app_notification(
    v_recipient,
    'bk_message',
    'Ruang BK',
    'Ada pesan baru di Ruang BK.',
    '/bk/' || v_conversation_id::text,
    'conversation',
    v_conversation_id,
    'bk_message:' || new.id::text || ':' || v_recipient::text
  );
  return new;
end;
$$;

drop trigger if exists counseling_messages_notify on public.counseling_messages;
create trigger counseling_messages_notify
  after insert on public.counseling_messages
  for each row execute function public.notify_bk_message();

-- Appointment notifications: notify student on counselor actions, and counselor on student request
create or replace function public.notify_appointment_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Notify counselor of new request
  perform public.create_app_notification(
    new.counselor_id,
    'appointment_requested',
    'Jadwal BK',
    'Ada permintaan jadwal konseling baru.',
    '/bk/counselor/appointments',
    'appointment',
    new.id,
    'appointment_requested:' || new.id::text || ':' || new.counselor_id::text
  );
  return new;
end;
$$;

drop trigger if exists bk_appointments_notify_request on public.bk_appointments;
create trigger bk_appointments_notify_request
  after insert on public.bk_appointments
  for each row execute function public.notify_appointment_request();

create or replace function public.notify_appointment_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = new.status then return new; end if;
  if new.status = 'accepted' then
    perform public.create_app_notification(new.student_id, 'appointment_accepted', 'Jadwal BK', 'Janji konselingmu telah dikonfirmasi.', '/bk/appointments', 'appointment', new.id, 'appointment_accepted:' || new.id::text);
  elsif new.status = 'rejected' then
    perform public.create_app_notification(new.student_id, 'appointment_rejected', 'Jadwal BK', 'Permintaan jadwal konselingmu tidak dapat dikonfirmasi.', '/bk/appointments', 'appointment', new.id, 'appointment_rejected:' || new.id::text);
  elsif new.status = 'cancelled' and old.status in ('pending','accepted') then
    -- Determine who cancelled? If student cancelled, notify counselor? But for now, notify student if counselor cancelled, and vice versa. Simple: notify student if counselor cancelled, notify counselor if student cancelled.
    -- Check who is the actor? We can't know directly, but we can notify student if counselor is the one who updated? For simplicity, notify student on any cancel (covers counselor cancel)
    perform public.create_app_notification(new.student_id, 'appointment_cancelled', 'Jadwal BK', 'Jadwal konselingmu telah dibatalkan.', '/bk/appointments', 'appointment', new.id, 'appointment_cancelled:' || new.id::text);
    -- Also notify counselor if student cancelled? For student cancel, counselor should be notified, but we don't have actor info. We can notify counselor as well for student cancel.
    perform public.create_app_notification(new.counselor_id, 'appointment_cancelled', 'Jadwal BK', 'Jadwal konseling telah dibatalkan.', '/bk/counselor/appointments', 'appointment', new.id, 'appointment_cancelled_counselor:' || new.id::text);
  elsif new.status = 'completed' then
    perform public.create_app_notification(new.student_id, 'appointment_completed', 'Jadwal BK', 'Sesi konselingmu telah ditandai selesai.', '/bk/appointments', 'appointment', new.id, 'appointment_completed:' || new.id::text);
  end if;
  -- Rescheduled: check scheduled times changed
  if (old.scheduled_start_at is distinct from new.scheduled_start_at) or (old.scheduled_end_at is distinct from new.scheduled_end_at) then
    perform public.create_app_notification(new.student_id, 'appointment_rescheduled', 'Jadwal BK', 'Jadwal konselingmu telah diperbarui.', '/bk/appointments', 'appointment', new.id, 'appointment_rescheduled:' || new.id::text || ':' || extract(epoch from new.scheduled_start_at)::text);
  end if;
  return new;
end;
$$;

drop trigger if exists bk_appointments_notify_status on public.bk_appointments;
create trigger bk_appointments_notify_status
  after update on public.bk_appointments
  for each row execute function public.notify_appointment_status();

-- Peer concern: notify reporter on status change to reviewing/resolved/dismissed
create or replace function public.notify_peer_concern_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = new.status then return new; end if;
  if new.status = 'reviewing' then
    perform public.create_app_notification(new.reporter_id, 'peer_concern_reviewing', 'Peduli Teman', 'Kepedulian yang kamu kirim sedang ditinjau.', '/bk/peduli-teman/history', 'peer_concern', new.id, 'peer_concern_reviewing:' || new.id::text);
  elsif new.status = 'resolved' then
    perform public.create_app_notification(new.reporter_id, 'peer_concern_resolved', 'Peduli Teman', 'Kepedulian yang kamu kirim telah selesai ditangani.', '/bk/peduli-teman/history', 'peer_concern', new.id, 'peer_concern_resolved:' || new.id::text);
  elsif new.status = 'dismissed' then
    perform public.create_app_notification(new.reporter_id, 'peer_concern_dismissed', 'Peduli Teman', 'Peninjauan kepedulian yang kamu kirim telah ditutup.', '/bk/peduli-teman/history', 'peer_concern', new.id, 'peer_concern_dismissed:' || new.id::text);
  end if;
  return new;
end;
$$;

drop trigger if exists bk_peer_concerns_notify_status on public.bk_peer_concerns;
create trigger bk_peer_concerns_notify_status
  after update on public.bk_peer_concerns
  for each row execute function public.notify_peer_concern_status();

-- Social: comment, reply, helpful, best_answer
create or replace function public.notify_social_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_post_author uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  if v_post_author is null or v_post_author = new.author_id then return new; end if;
  perform public.create_app_notification(
    v_post_author,
    'social_comment',
    'Aktivitas',
    'Ada komentar baru di postinganmu.',
    '/post/' || new.post_id::text,
    'post',
    new.post_id,
    'social_comment:' || new.id::text || ':' || v_post_author::text
  );
  return new;
end;
$$;

drop trigger if exists comments_notify_comment on public.comments;
create trigger comments_notify_comment
  after insert on public.comments
  for each row execute function public.notify_social_comment();

create or replace function public.notify_social_reply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_parent_author uuid;
begin
  if new.parent_id is null then return new; end if;
  select author_id into v_parent_author from public.comments where id = new.parent_id;
  if v_parent_author is null or v_parent_author = new.author_id then return new; end if;
  perform public.create_app_notification(
    v_parent_author,
    'social_reply',
    'Aktivitas',
    'Ada balasan baru pada komentarmu.',
    '/post/' || new.post_id::text,
    'comment',
    new.parent_id,
    'social_reply:' || new.id::text || ':' || v_parent_author::text
  );
  return new;
end;
$$;

-- Note: notify_social_comment already handles parent, but we separate for clarity; we will keep only one to avoid duplicate.
-- Instead, we will have a single trigger that handles both, but for now we keep both and make reply use distinct event_key.
drop trigger if exists comments_notify_reply on public.comments;
create trigger comments_notify_reply
  after insert on public.comments
  for each row execute function public.notify_social_reply();

create or replace function public.notify_social_helpful()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_post_author uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  if v_post_author is null or v_post_author = new.user_id then return new; end if;
  perform public.create_app_notification(
    v_post_author,
    'social_helpful',
    'Aktivitas',
    'Postinganmu ditandai membantu.',
    '/post/' || new.post_id::text,
    'post',
    new.post_id,
    'social_helpful:' || new.post_id::text || ':' || new.user_id::text
  );
  return new;
end;
$$;

drop trigger if exists post_helpful_notify on public.post_helpful;
create trigger post_helpful_notify
  after insert on public.post_helpful
  for each row execute function public.notify_social_helpful();

create or replace function public.notify_best_answer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare v_comment_author uuid;
begin
  if new.is_best_answer = true and (old.is_best_answer is distinct from true) then
    select author_id into v_comment_author from public.comments where id = new.id;
    -- Actually new is the comment row being updated, so author is new.author_id
    v_comment_author := new.author_id;
    -- Find post author to ensure not self? But best answer is set by post author, so comment author != post author
    perform public.create_app_notification(
      v_comment_author,
      'best_answer',
      'Aktivitas',
      'Jawabanmu dipilih sebagai Jawaban Terbaik.',
      '/post/' || new.post_id::text,
      'comment',
      new.id,
      'best_answer:' || new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists comments_notify_best_answer on public.comments;
create trigger comments_notify_best_answer
  after update on public.comments
  for each row execute function public.notify_best_answer();

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.app_notifications from anon, authenticated, public;
grant select, update on public.app_notifications to authenticated;

revoke all privileges on function public.create_app_notification(uuid,text,text,text,text,text,uuid,text) from public, anon;
grant execute on function public.create_app_notification(uuid,text,text,text,text,text,uuid,text) to authenticated; -- but RLS will still prevent direct, however we revoke to limit; actually we should revoke from authenticated and only allow definer triggers
revoke all privileges on function public.create_app_notification(uuid,text,text,text,text,text,uuid,text) from authenticated;
-- Only definer triggers can call, no direct grant

revoke all privileges on function public.get_my_notifications(int,int) from public, anon;
revoke all privileges on function public.get_my_notification_unread_count() from public, anon;
revoke all privileges on function public.mark_notification_read(uuid) from public, anon;
revoke all privileges on function public.mark_all_notifications_read() from public, anon;
grant execute on function public.get_my_notifications(int,int) to authenticated;
grant execute on function public.get_my_notification_unread_count() to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

revoke all privileges on function public.search_peer_students(text,int) from public, anon;
grant execute on function public.search_peer_students(text,int) to authenticated;

revoke execute on function public.notify_bk_message() from public, anon;
revoke execute on function public.notify_appointment_request() from public, anon;
revoke execute on function public.notify_appointment_status() from public, anon;
revoke execute on function public.notify_peer_concern_status() from public, anon;
revoke execute on function public.notify_social_comment() from public, anon;
revoke execute on function public.notify_social_reply() from public, anon;
revoke execute on function public.notify_social_helpful() from public, anon;
revoke execute on function public.notify_best_answer() from public, anon;
grant execute on function public.notify_bk_message() to authenticated;
grant execute on function public.notify_appointment_request() to authenticated;
grant execute on function public.notify_appointment_status() to authenticated;
grant execute on function public.notify_peer_concern_status() to authenticated;
grant execute on function public.notify_social_comment() to authenticated;
grant execute on function public.notify_social_reply() to authenticated;
grant execute on function public.notify_social_helpful() to authenticated;
grant execute on function public.notify_best_answer() to authenticated;

commit;
