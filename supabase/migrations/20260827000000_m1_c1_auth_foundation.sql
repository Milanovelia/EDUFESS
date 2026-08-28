-- ==========================================================================
-- EduFess — M1 C1: authentication database foundation
--
-- Creates:
--   public.profiles          1:1 domain identity for auth.users
--   public.invitation_codes  server-side registration gate
--   triggers/functions       signup guard + profile creation,
--                            updated_at maintenance, role/pseudonym guard
--   RLS + grants             per M1 locked decisions
--
-- Client registration is NOT yet implemented (C1 has no Flutter auth UI).
-- Any signup that does reach the database is invitation-gated and validated
-- server-side. Invitation-gated registration (client flow) will be
-- implemented before C4.
--
-- See supabase/README.md for the canonical synthetic-email algorithm,
-- the operator runbook, and verification instructions.
-- ==========================================================================

begin;

-- SHA-256 digests for the synthetic-email derivation.
create extension if not exists pgcrypto with schema extensions;

-- --------------------------------------------------------------------------
-- profiles: domain identity, 1:1 with auth.users.
-- Real-world identity (name, NIS, real email) is intentionally absent.
-- --------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key
    references auth.users (id) on delete cascade,
  pseudonym text not null
    check (char_length(pseudonym) between 3 and 32)
    check (pseudonym ~ '^[A-Za-z0-9_.-]+$'),
  role text not null default 'student'
    check (role in ('student', 'counselor', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Domain identity, 1:1 with auth.users. Pseudonym is the public identity; role is operator-managed.';

-- Case-insensitive uniqueness via lower() rather than the citext extension:
-- no extra extension dependency, and lower(pseudonym) is exactly the
-- normalization used by the synthetic-email derivation.
create unique index profiles_pseudonym_lower_key
  on public.profiles (lower(pseudonym));

-- --------------------------------------------------------------------------
-- invitation_codes: server-side registration gate (locked decision 12).
-- The auth service executes signup inserts as supabase_auth_admin, so the
-- gate is enforced unconditionally — operator provisioning consumes
-- invitation codes as well.
-- --------------------------------------------------------------------------
create table public.invitation_codes (
  code text primary key
    check (char_length(code) between 8 and 64),
  created_at timestamptz not null default now(),
  used_by uuid references public.profiles (id) on delete set null,
  used_at timestamptz
);

comment on table public.invitation_codes is
  'Server-side registration gate. Every auth.users creation must consume one. Operator-managed; no API role can read or write it.';

-- --------------------------------------------------------------------------
-- updated_at maintenance
-- --------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- --------------------------------------------------------------------------
-- Signup guard (BEFORE INSERT on auth.users).
--
-- Signup inserts are performed by the auth service (supabase_auth_admin),
-- not by the end-user session, so no JWT-based bypass is possible or
-- offered. Enforced here: pseudonym presence/format, synthetic-email
-- consistency (locked decision 11), invitation validity (decision 12).
-- Role is never read from client-controlled metadata.
-- --------------------------------------------------------------------------
create or replace function public.guard_new_user()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_pseudonym    text;
  v_email_expect text;
  v_code         text;
  v_used_at      timestamptz;
begin
  v_pseudonym := new.raw_user_meta_data ->> 'pseudonym';
  if v_pseudonym is null then
    raise exception 'Registration requires a pseudonym.';
  end if;

  -- Canonical normalization: trim + lowercase. The stored pseudonym keeps
  -- the user's casing; uniqueness and login derivation use this form.
  if lower(trim(v_pseudonym)) !~ '^[a-z0-9_.-]{3,32}$' then
    raise exception 'Pseudonym must be 3-32 characters of A-Z a-z 0-9 _ . -';
  end if;

  v_email_expect :=
    encode(extensions.digest(lower(trim(v_pseudonym)), 'sha256'), 'hex')
    || '@edufess.app';
  if new.email is null or lower(new.email) <> v_email_expect then
    raise exception
      'Email must be the synthetic address derived from the pseudonym.';
  end if;

  v_code := new.raw_user_meta_data ->> 'invite_code';
  if v_code is null then
    raise exception 'Registration requires an invitation code.';
  end if;

  -- Row lock serializes concurrent redemptions of the same code.
  select used_at into v_used_at
    from public.invitation_codes
    where code = v_code
    for update;
  if not found then
    raise exception 'Invalid invitation code.';
  end if;
  if v_used_at is not null then
    raise exception 'Invitation code has already been used.';
  end if;

  return new;
end;
$$;

-- --------------------------------------------------------------------------
-- Profile creation (AFTER INSERT on auth.users).
-- SECURITY DEFINER: the signup session has no direct INSERT grant on
-- public.profiles, and must never get one. Role is hard-coded.
-- --------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  insert into public.profiles (id, pseudonym, role)
  values (
    new.id,
    trim(new.raw_user_meta_data ->> 'pseudonym'),
    'student'  -- never taken from client-controlled metadata
  );

  v_code := new.raw_user_meta_data ->> 'invite_code';
  if v_code is not null then
    update public.invitation_codes
      set used_by = new.id,
          used_at = now()
      where code = v_code
        and used_at is null;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_guard
  before insert on auth.users
  for each row execute function public.guard_new_user();

create trigger on_auth_user_profile
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- --------------------------------------------------------------------------
-- Profile update guard: pseudonym immutable (decision 6); role changeable
-- only from direct SQL sessions, which carry no JWT (decisions 8 and 16).
-- PostgREST client calls always set request.jwt.claims; the dashboard/psql
-- operator path never does.
-- --------------------------------------------------------------------------
create or replace function public.guard_profile_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.pseudonym is distinct from old.pseudonym then
    raise exception 'Pseudonym is immutable.';
  end if;

  if new.role is distinct from old.role then
    if current_setting('request.jwt.claims', true) is not null then
      raise exception 'Role cannot be changed through the client API.';
    end if;
  end if;

  return new;
end;
$$;

create trigger profiles_guard_update
  before update on public.profiles
  for each row execute function public.guard_profile_update();

-- --------------------------------------------------------------------------
-- RLS
-- --------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.invitation_codes enable row level security;

-- SELECT: authenticated, own row only (decision 14).
create policy profiles_select_own
  on public.profiles for select to authenticated
  using (auth.uid() = id);

-- UPDATE: authenticated, own row only (decision 16). role and pseudonym
-- are additionally immutable via the trigger above.
create policy profiles_update_own
  on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- No INSERT/DELETE policies: profiles are created by handle_new_user()
-- and removed only via the privileged auth.users cascade path
-- (decisions 15 and 17).
-- invitation_codes: RLS enabled with zero policies — invisible to every
-- API role; trigger functions reach it through explicit grants below.

-- --------------------------------------------------------------------------
-- Grants (defence in depth on top of RLS; RLS stays the enforcement layer)
-- --------------------------------------------------------------------------
revoke all privileges on public.profiles
  from anon, authenticated, public;
revoke all privileges on public.invitation_codes
  from anon, authenticated, public;

-- authenticated may exercise exactly the two policies above — nothing else.
grant select, update on public.profiles to authenticated;

-- The auth service executes the signup triggers and reads invitation codes.
grant usage on schema public to supabase_auth_admin;
grant select on public.invitation_codes to supabase_auth_admin;
grant execute on function public.guard_new_user() to supabase_auth_admin;
grant execute on function public.handle_new_user() to supabase_auth_admin;

-- The authenticated role executes the profile UPDATE triggers.
grant execute on function public.guard_profile_update() to authenticated;
grant execute on function public.touch_updated_at() to authenticated;

-- Trigger functions are implementation details; no direct client calls.
revoke execute on function public.guard_new_user()
  from public, anon, authenticated;
revoke execute on function public.handle_new_user()
  from public, anon, authenticated;
revoke execute on function public.guard_profile_update()
  from public, anon;
revoke execute on function public.touch_updated_at()
  from public, anon;

commit;
