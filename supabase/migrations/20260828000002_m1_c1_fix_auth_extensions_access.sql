-- ==========================================================================
-- EduFess — M1 C1 fix: F-10b missing extensions schema access
--
-- Problem:
--   guard_new_user() calls extensions.digest() for synthetic-email
--   validation (line 117 of the C1 migration).
--   guard_new_user() is SECURITY INVOKER → runs as supabase_auth_admin.
--   supabase_auth_admin has no USAGE privilege on the extensions schema,
--   causing the function to fail with:
--     500 unexpected_failure "Database error saving new user"
--
-- Fix:
--   Grant USAGE on schema extensions to supabase_auth_admin.
--   This is the minimum required privilege for extensions.digest().
--
-- Idempotent: GRANT is a no-op if already held.
-- ==========================================================================

begin;

grant usage on schema extensions
  to supabase_auth_admin;

commit;
