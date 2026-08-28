-- ==========================================================================
-- EduFess — M1 C1: auth repair — remove synthetic email domain dependency
--
-- Replaces guard_new_user() to remove the synthetic email validation.
--
-- OLD MODEL:
--   signup email MUST equal SHA-256(pseudonym) + domain
--   required custom domain, DNS validation, complex derivation
--
-- NEW MODEL:
--   email + password = Supabase Auth credentials (PRIVATE)
--   pseudonym = application identity (PUBLIC)
--   invitation code = registration gate
--   no synthetic email, no custom domain required
--
-- Signup flow:
--   1. Client sends: email + password + metadata {pseudonym, invite_code}
--   2. Supabase Auth creates user with email+password
--   3. guard_new_user() validates pseudonym + invitation code
--   4. handle_new_user() creates profile with role='student'
--
-- This migration does NOT modify:
--   - handle_new_user()
--   - guard_profile_update()
--   - touch_updated_at()
--   - triggers
--   - RLS policies
--   - grants
--   - profiles table
--   - invitation_codes table
-- ==========================================================================

begin;

create or replace function public.guard_new_user()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_pseudonym text;
  v_code      text;
  v_used_at   timestamptz;
begin
  -- Validate pseudonym from metadata
  v_pseudonym := new.raw_user_meta_data ->> 'pseudonym';
  if v_pseudonym is null then
    raise exception 'Registration requires a pseudonym.';
  end if;

  -- Canonical normalization: trim + lowercase. The stored pseudonym keeps
  -- the user's casing; uniqueness and login derivation use this form.
  if lower(trim(v_pseudonym)) !~ '^[a-z0-9_.-]{3,32}$' then
    raise exception 'Pseudonym must be 3-32 characters of A-Z a-z 0-9 _ . -';
  end if;

  -- Validate invitation code (REQUIRED)
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

commit;
