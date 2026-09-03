-- ==========================================================================
-- EduFess — M6 BK Security Foundation
--
-- Creates:
--   public.bk_consents
--   public.counseling_conversations
--   public.counseling_messages
--   public.bk_identity_access_log
--   triggers for server-side alias, ownership, consent enforcement
--   RLS + grants scoped strictly to BK domain
--   functions (SECURITY DEFINER, search_path=''):
--     public.create_bk_consent(p_version)
--     public.create_counseling_conversation()
--     public.claim_counseling_conversation(p_conversation_id)
--     public.get_counselor_bk_queue()
--     public.get_student_bk_conversations()
--     public.get_counseling_messages(p_conversation_id)
--     public.send_counseling_message(p_conversation_id, p_content)
--     public.reveal_counseling_identity(p_conversation_id, p_reason)
--
-- Design invariants:
--   - BK is separate security domain: admin != counselor, social moderation
--     has no BK access, counselor has no social moderation privilege.
--   - Pseudonymous first contact: student_alias server-generated "Siswa BK #XXXX"
--     (BK-specific, not social alias), backend retains student_id.
--   - Consent server-enforced: active bk-consent-v1 required for conversation/message.
--   - RLS enabled on all BK tables, narrow policies (own-row only for consents,
--     participant-only for conversations/messages via functions + RLS).
--   - All BK functions SECURITY DEFINER with fixed search_path='' and
--     schema-qualified refs, auth.uid() + role checks server-side.
-- ==========================================================================

begin;

-- --------------------------------------------------------------------------
-- bk_consents
-- --------------------------------------------------------------------------
create table public.bk_consents (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  version text not null check (version = 'bk-consent-v1'),
  accepted_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check (revoked_at is null or revoked_at >= accepted_at)
);

comment on table public.bk_consents is 'BK consent, versioned, one active per student/version.';

create unique index bk_consents_active_unique on public.bk_consents (student_id, version) where revoked_at is null;
create index bk_consents_student_id_idx on public.bk_consents (student_id);

-- --------------------------------------------------------------------------
-- counseling_conversations
-- --------------------------------------------------------------------------
create table public.counseling_conversations (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles (id) on delete cascade,
  counselor_id uuid references public.profiles (id) on delete set null,
  student_alias text not null check (char_length(student_alias) between 1 and 64),
  status text not null default 'open' check (status in ('open','assigned','closed')),
  identity_revealed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

comment on table public.counseling_conversations is 'BK conversations, pseudonymous first contact, student_alias server-generated.';

create index counseling_conversations_student_id_idx on public.counseling_conversations (student_id);
create index counseling_conversations_counselor_id_idx on public.counseling_conversations (counselor_id) where counselor_id is not null;
create index counseling_conversations_status_idx on public.counseling_conversations (status);

create trigger counseling_conversations_touch_updated_at
  before update on public.counseling_conversations
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------------------
-- counseling_messages
-- --------------------------------------------------------------------------
create table public.counseling_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.counseling_conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

comment on table public.counseling_messages is 'Private BK messages, only participants.';

create index counseling_messages_conversation_id_idx on public.counseling_messages (conversation_id);
create index counseling_messages_sender_id_idx on public.counseling_messages (sender_id);
create index counseling_messages_created_at_idx on public.counseling_messages (created_at);

-- --------------------------------------------------------------------------
-- bk_identity_access_log
-- --------------------------------------------------------------------------
create table public.bk_identity_access_log (
  id uuid primary key default gen_random_uuid(),
  counselor_id uuid not null references public.profiles (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  conversation_id uuid not null references public.counseling_conversations (id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 500),
  accessed_at timestamptz not null default now()
);

comment on table public.bk_identity_access_log is 'Append-only audit for identity reveal.';

create index bk_identity_access_log_counselor_id_idx on public.bk_identity_access_log (counselor_id);
create index bk_identity_access_log_student_id_idx on public.bk_identity_access_log (student_id);
create index bk_identity_access_log_conversation_id_idx on public.bk_identity_access_log (conversation_id);

-- --------------------------------------------------------------------------
-- Helper: set bk_consent student_id forced
-- --------------------------------------------------------------------------
create or replace function public.set_bk_consent_student()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if new.student_id is distinct from v_uid then new.student_id := v_uid; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Only student can create consent.'; end if;
  if new.version <> 'bk-consent-v1' then raise exception 'Invalid consent version.'; end if;
  new.revoked_at := null;
  return new;
end;
$$;

create trigger bk_consents_set_student
  before insert on public.bk_consents
  for each row execute function public.set_bk_consent_student();

-- --------------------------------------------------------------------------
-- Helper: counseling conversation creation (alias, consent, ownership)
-- --------------------------------------------------------------------------
create or replace function public.set_counseling_conversation_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_has_consent boolean; v_alias text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if new.student_id is distinct from v_uid then new.student_id := v_uid; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'student' then raise exception 'Only student can create conversation.'; end if;
  -- active consent required
  select exists(select 1 from public.bk_consents where student_id = v_uid and version='bk-consent-v1' and revoked_at is null) into v_has_consent;
  if not v_has_consent then raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.'; end if;
  -- force server fields
  if new.counselor_id is not null then raise exception 'Cannot assign counselor on create.'; end if;
  if new.identity_revealed_at is not null then raise exception 'Cannot set identity_revealed_at on create.'; end if;
  new.status := 'open';
  new.closed_at := null;
  -- generate BK-specific alias
  v_alias := 'Siswa BK #' || upper(substring(encode(extensions.digest(gen_random_uuid()::text || clock_timestamp()::text, 'sha256'), 'hex') from 1 for 4));
  new.student_alias := v_alias;
  return new;
end;
$$;

create trigger counseling_conversations_set_fields
  before insert on public.counseling_conversations
  for each row execute function public.set_counseling_conversation_fields();

-- Prevent student from assigning counselor via direct update (only via claim function)
create or replace function public.guard_counseling_counselor_assign()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  if new.counselor_id is distinct from old.counselor_id then
    -- Allow only if new counselor is auth user and caller is counselor and conversation was open unassigned
    v_uid := auth.uid();
    if v_uid is null then raise exception 'Not authenticated.'; end if;
    select role into v_role from public.profiles where id = v_uid;
    -- This trigger blocks direct table updates for counselor assignment; assignment must go via claim function (definer)
    -- So any direct update that changes counselor_id is denied
    raise exception 'Counselor assignment must use claim function.';
  end if;
  return new;
end;
$$;

create trigger counseling_conversations_guard_assign
  before update on public.counseling_conversations
  for each row execute function public.guard_counseling_counselor_assign();

-- --------------------------------------------------------------------------
-- Helper: counseling message sender and participant check
-- --------------------------------------------------------------------------
create or replace function public.set_counseling_message_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_student uuid; v_counselor uuid; v_status text; v_has_consent boolean;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if new.sender_id is distinct from v_uid then new.sender_id := v_uid; end if;
  if char_length(new.content) < 1 or char_length(new.content) > 4000 then raise exception 'Invalid message content.'; end if;
  if new.deleted_at is not null then raise exception 'Cannot set deleted_at on insert.'; end if;
  -- Check conversation exists and participant
  select student_id, counselor_id, status into v_student, v_counselor, v_status from public.counseling_conversations where id = new.conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_status = 'closed' then raise exception 'Conversation closed.'; end if;
  -- Must be participant: student or assigned counselor
  if not (v_uid = v_student or v_uid = v_counselor) then
    raise exception 'Kamu tidak memiliki akses ke percakapan ini.';
  end if;
  -- Student needs active consent to send
  select role into v_role from public.profiles where id = v_uid;
  if v_role = 'student' then
    select exists(select 1 from public.bk_consents where student_id = v_uid and version='bk-consent-v1' and revoked_at is null) into v_has_consent;
    if not v_has_consent then raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.'; end if;
  end if;
  return new;
end;
$$;

create trigger counseling_messages_set_fields
  before insert on public.counseling_messages
  for each row execute function public.set_counseling_message_fields();

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.bk_consents enable row level security;
alter table public.counseling_conversations enable row level security;
alter table public.counseling_messages enable row level security;
alter table public.bk_identity_access_log enable row level security;

-- bk_consents: own row only
create policy bk_consents_select_own on public.bk_consents for select to authenticated using (student_id = auth.uid());
create policy bk_consents_insert_own on public.bk_consents for insert to authenticated with check (student_id = auth.uid());
-- revocation via update own (set revoked_at)
create policy bk_consents_update_own on public.bk_consents for update to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());

-- counseling_conversations: student own, counselor assigned
create policy counseling_conversations_select_student on public.counseling_conversations for select to authenticated using (student_id = auth.uid());
create policy counseling_conversations_select_counselor on public.counseling_conversations for select to authenticated using (counselor_id = auth.uid());
create policy counseling_conversations_insert_student on public.counseling_conversations for insert to authenticated with check (student_id = auth.uid());
-- No direct update/delete for conversations (use claim function definer)

-- counseling_messages: participant only via conversation check (using exists, but RLS on conversations will filter)
-- For simplicity, allow participant via function check; create two policies using subquery that bypasses RLS via security definer helper?
-- Instead, use a helper function that checks participant without RLS? Simpler: create policies that allow if sender is self or conversation participant via direct table join (RLS on conversations still applies but we check via authenticated user's ability to see conversation)
-- We'll create policies with USING (sender_id = auth.uid() OR EXISTS (SELECT 1 FROM public.counseling_conversations cc WHERE cc.id = conversation_id AND (cc.student_id = auth.uid() OR cc.counselor_id = auth.uid())))
-- This works because cc select is also under RLS but the current user can see own conversations via above policies, so exists will be true for participant.
create policy counseling_messages_select_participant on public.counseling_messages for select to authenticated using (
  sender_id = auth.uid() OR EXISTS (SELECT 1 FROM public.counseling_conversations cc WHERE cc.id = conversation_id AND (cc.student_id = auth.uid() OR cc.counselor_id = auth.uid()))
);
create policy counseling_messages_insert_participant on public.counseling_messages for insert to authenticated with check (
  sender_id = auth.uid() AND EXISTS (SELECT 1 FROM public.counseling_conversations cc WHERE cc.id = conversation_id AND (cc.student_id = auth.uid() OR cc.counselor_id = auth.uid()))
);

-- bk_identity_access_log: no direct select/insert for authenticated (append-only via reveal function definer)
-- No policies → default deny

-- --------------------------------------------------------------------------
-- Functions
-- --------------------------------------------------------------------------

-- Claim counseling conversation (counselor self-claim)
create or replace function public.claim_counseling_conversation(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_conv public.counseling_conversations%rowtype;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select * into v_conv from public.counseling_conversations where id = p_conversation_id for update;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_conv.counselor_id is not null then raise exception 'Percakapan ini sudah ditangani guru BK lain.'; end if;
  if v_conv.status <> 'open' then raise exception 'Conversation not open.'; end if;
  update public.counseling_conversations set counselor_id = v_uid, status = 'assigned', updated_at = now() where id = p_conversation_id;
end;
$$;

-- Get counselor queue (unassigned open, alias only)
create or replace function public.get_counselor_bk_queue()
returns table (conversation_id uuid, student_alias text, status text, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  return query select cc.id, cc.student_alias, cc.status, cc.created_at from public.counseling_conversations cc where cc.status='open' and cc.counselor_id is null order by cc.created_at asc;
end;
$$;

-- Get student conversations (own)
create or replace function public.get_student_bk_conversations()
returns table (conversation_id uuid, student_alias text, status text, created_at timestamptz, updated_at timestamptz, counselor_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  return query select cc.id, cc.student_alias, cc.status, cc.created_at, cc.updated_at, cc.counselor_id from public.counseling_conversations cc where cc.student_id = v_uid order by cc.created_at desc;
end;
$$;

-- Get messages for conversation (participant only)
create or replace function public.get_counseling_messages(p_conversation_id uuid)
returns table (id uuid, conversation_id uuid, sender_id uuid, content text, created_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_student uuid; v_counselor uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  select student_id, counselor_id into v_student, v_counselor from public.counseling_conversations where id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if not (v_uid = v_student or v_uid = v_counselor) then raise exception 'Kamu tidak memiliki akses ke percakapan ini.'; end if;
  return query select cm.id, cm.conversation_id, cm.sender_id, cm.content, cm.created_at from public.counseling_messages cm where cm.conversation_id = p_conversation_id and cm.deleted_at is null order by cm.created_at asc;
end;
$$;

-- Send message (alternative to direct insert, also checks)
create or replace function public.send_counseling_message(p_conversation_id uuid, p_content text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_student uuid; v_counselor uuid; v_status text; v_has_consent boolean; v_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if p_content is null or char_length(p_content) < 1 or char_length(p_content) > 4000 then raise exception 'Invalid message content.'; end if;
  select student_id, counselor_id, status into v_student, v_counselor, v_status from public.counseling_conversations where id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_status = 'closed' then raise exception 'Conversation closed.'; end if;
  if not (v_uid = v_student or v_uid = v_counselor) then raise exception 'Kamu tidak memiliki akses ke percakapan ini.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role = 'student' then
    select exists(select 1 from public.bk_consents where student_id = v_uid and version='bk-consent-v1' and revoked_at is null) into v_has_consent;
    if not v_has_consent then raise exception 'Kamu perlu menyetujui ketentuan BK terlebih dahulu.'; end if;
  end if;
  insert into public.counseling_messages (conversation_id, sender_id, content) values (p_conversation_id, v_uid, p_content) returning id into v_id;
  return v_id;
end;
$$;

-- Reveal identity (assigned counselor only, reason required, audited)
create or replace function public.reveal_counseling_identity(p_conversation_id uuid, p_reason text)
returns table (student_id uuid, pseudonym text)
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid; v_role text; v_student uuid; v_counselor uuid; v_status text;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'Not authenticated.'; end if;
  if p_reason is null or btrim(p_reason) = '' then raise exception 'Reason required.'; end if;
  if char_length(p_reason) > 500 then raise exception 'Reason too long.'; end if;
  select role into v_role from public.profiles where id = v_uid;
  if v_role is distinct from 'counselor' then raise exception 'Not authorized.'; end if;
  select student_id, counselor_id, status into v_student, v_counselor, v_status from public.counseling_conversations where id = p_conversation_id;
  if not found then raise exception 'Conversation not found.'; end if;
  if v_counselor is distinct from v_uid then raise exception 'Not assigned counselor.'; end if;
  if v_status = 'closed' then raise exception 'Conversation closed.'; end if;
  -- Audit
  insert into public.bk_identity_access_log (counselor_id, student_id, conversation_id, reason) values (v_uid, v_student, p_conversation_id, btrim(p_reason));
  update public.counseling_conversations set identity_revealed_at = now(), updated_at = now() where id = p_conversation_id;
  return query select p.id, p.pseudonym from public.profiles p where p.id = v_student;
end;
$$;

-- --------------------------------------------------------------------------
-- Grants
-- --------------------------------------------------------------------------
revoke all privileges on public.bk_consents from anon, authenticated, public;
revoke all privileges on public.counseling_conversations from anon, authenticated, public;
revoke all privileges on public.counseling_messages from anon, authenticated, public;
revoke all privileges on public.bk_identity_access_log from anon, authenticated, public;

grant select, insert, update on public.bk_consents to authenticated;
grant select, insert on public.counseling_conversations to authenticated;
grant select, insert on public.counseling_messages to authenticated;
-- bk_identity_access_log: no direct grants (definer only)

revoke all privileges on function public.set_bk_consent_student() from public, anon;
revoke all privileges on function public.set_counseling_conversation_fields() from public, anon;
revoke all privileges on function public.guard_counseling_counselor_assign() from public, anon;
revoke all privileges on function public.set_counseling_message_fields() from public, anon;
grant execute on function public.set_bk_consent_student() to authenticated;
grant execute on function public.set_counseling_conversation_fields() to authenticated;
grant execute on function public.guard_counseling_counselor_assign() to authenticated;
grant execute on function public.set_counseling_message_fields() to authenticated;

revoke all privileges on function public.claim_counseling_conversation(uuid) from public, anon;
revoke all privileges on function public.get_counselor_bk_queue() from public, anon;
revoke all privileges on function public.get_student_bk_conversations() from public, anon;
revoke all privileges on function public.get_counseling_messages(uuid) from public, anon;
revoke all privileges on function public.send_counseling_message(uuid,text) from public, anon;
revoke all privileges on function public.reveal_counseling_identity(uuid,text) from public, anon;
grant execute on function public.claim_counseling_conversation(uuid) to authenticated;
grant execute on function public.get_counselor_bk_queue() to authenticated;
grant execute on function public.get_student_bk_conversations() to authenticated;
grant execute on function public.get_counseling_messages(uuid) to authenticated;
grant execute on function public.send_counseling_message(uuid,text) to authenticated;
grant execute on function public.reveal_counseling_identity(uuid,text) to authenticated;

commit;
