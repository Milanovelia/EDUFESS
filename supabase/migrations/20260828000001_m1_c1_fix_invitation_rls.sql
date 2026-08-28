-- ==========================================================================
-- EduFess — M1 C1 fix: F-10a RLS zero-policy blocks auth trigger
--
-- Problem:
--   public.invitation_codes has RLS ENABLED with ZERO policies.
--   guard_new_user() runs as SECURITY INVOKER (supabase_auth_admin),
--   which is NOT a superuser and NOT the table owner.
--   RLS blocks ALL row access from supabase_auth_admin, making the
--   SELECT ... FOR UPDATE in guard_new_user() return zero rows,
--   causing HTTP signup to fail with:
--     500 unexpected_failure "Database error saving new user"
--
--   The F-10 fix (SELECT + UPDATE grant) was necessary but insufficient.
--   Grants do not bypass RLS in PostgreSQL.
--
-- Fix:
--   Disable RLS on invitation_codes.
--   API exposure is already blocked by REVOKE ALL from anon/authenticated/public.
--   RLS with zero policies is redundant for API protection and harmful
--   to the auth trigger pipeline.
--
-- Idempotent: DISABLE ROW LEVEL SECURITY is a no-op if already disabled.
-- ==========================================================================

begin;

alter table public.invitation_codes
  disable row level security;

commit;
