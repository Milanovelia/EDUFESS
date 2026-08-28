-- ==========================================================================
-- EduFess — M1 C1 fix: F-10 missing UPDATE privilege for auth signup
--
-- Problem:
--   guard_new_user() executes SELECT ... FOR UPDATE on
--   public.invitation_codes (line 130-133 of the C1 migration).
--   SELECT ... FOR UPDATE requires the UPDATE table privilege.
--   The C1 migration only granted SELECT to supabase_auth_admin,
--   causing HTTP signup to fail with:
--     500 unexpected_failure "Database error saving new user"
--
-- Fix:
--   Grant SELECT + UPDATE on public.invitation_codes to supabase_auth_admin.
--   The SELECT grant is already present (idempotent); the UPDATE grant
--   is the minimal required addition.
--
-- Idempotent: GRANT is a no-op if the privilege is already held.
-- ==========================================================================

begin;

grant select, update on public.invitation_codes
  to supabase_auth_admin;

commit;
