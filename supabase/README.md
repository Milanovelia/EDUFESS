# EduFess — Supabase database

M1 C1: authentication database foundation. No Flutter code touches these
objects yet; the Flutter auth layer arrives in C2–C4.

## Auth model

```
PRIVATE AUTH IDENTITY        PUBLIC APP IDENTITY
─────────────────────        ────────────────────
email (real, private)   →    auth.users.id  →    pseudonym (public)
password (Supabase Auth)     profiles.role
```

- **email**: real email address, used only for Supabase Auth login. Never
  exposed in profiles, feed, posts, comments, search, or any public API.
- **pseudonym**: 3–32 chars `[A-Za-z0-9_.-]`, case-insensitively unique.
  The application identity visible to all users.
- **invitation code**: required for every signup. Single-use, server-enforced.

No synthetic email. No custom domain required. Supabase Auth handles
email + password natively.

## Objects created by `migrations/`

| Object | Purpose |
|---|---|
| `public.profiles` | Public identity, 1:1 with `auth.users` (`id` FK, `ON DELETE CASCADE`). Pseudonym is the public identity. Real-world identity (name, NIS, email) is intentionally not stored in M1. |
| `public.invitation_codes` | Server-side registration gate. Every `auth.users` creation must consume one code. |
| `guard_new_user()` + `on_auth_user_guard` | BEFORE INSERT on `auth.users`: validates pseudonym format, enforces invitation validity. |
| `handle_new_user()` + `on_auth_user_profile` | AFTER INSERT on `auth.users`, `SECURITY DEFINER`: creates the profile with role hard-coded `student` (role is never read from client-controlled metadata) and binds the invitation to the new profile. |
| `touch_updated_at()` + `profiles_touch_updated_at` | Keeps `profiles.updated_at` current. |
| `guard_profile_update()` + `profiles_guard_update` | Rejects pseudonym changes (immutable in M1) and rejects role changes on any session that carries a JWT (i.e. all PostgREST clients). |
| RLS + grants | See matrix below. |

## Registration contract (for C4)

```text
signUp(
  email:    <real email address>,
  password: <user-chosen>,
  data: {
    "pseudonym":   "<3-32 chars, A-Za-z0-9_.->",
    "invite_code": "<code issued by operator>"
  }
)
```

Any failure inside `guard_new_user()` aborts the whole signup transaction
and surfaces as a signup error.

## Invitation decision

The invitation mechanism **is implemented in C1 as database objects**
(`invitation_codes` + gate in `guard_new_user()`): the signup insert path
(`auth` service → trigger) is the only server-side enforcement point that
exists, and without the gate anyone holding the public anon key could
self-register, violating locked decision 12. The Flutter invitation-gated
registration UI is out of C1 scope.

> C1 authentication database foundation does not yet permit client
> registration; invitation-gated registration will be implemented before C4.

Student self-signup without a valid invitation is rejected by the database.

## RLS + grants matrix

| Table | anon | authenticated | operator (postgres / SQL editor) | auth service (`supabase_auth_admin`) |
|---|---|---|---|---|
| `profiles` | no grants | `SELECT`, `UPDATE` — RLS limits both to `auth.uid() = id`; role/pseudonym immutable via trigger; no `INSERT`/`DELETE` grants or policies | owner (full, via SQL) | none needed |
| `invitation_codes` | no grants, RLS off | no grants, RLS off | owner (full, via SQL) | `SELECT`, `UPDATE` (gate lookup + usage binding) |

`service_role` retains its default privileges and RLS bypass; it is an
operator-grade credential and must never ship in the Flutter app.

## Operator runbook

1. **Create an invitation code** (SQL editor / psql):

   ```sql
   insert into public.invitation_codes (code) values ('<random-8..64-chars>');
   ```

2. **Provision a user** — either via the dashboard (Auth > Add user) or
   admin API — with:

   - email = real email address (the user's actual email)
   - password = user-chosen password
   - user metadata: `{"pseudonym": "...", "invite_code": "..."}`

   Direct SQL seeding must follow the same shape (see the verification
   script for a worked example). Every creation consumes one invitation
   code; role defaults to `student`.

3. **Change a role** — direct SQL only, never via API (the trigger rejects
   any JWT-carrying session):

   ```sql
   update public.profiles set role = 'counselor' where id = '<uuid>';
   ```

4. **Required auth config (dashboard, not SQL):** email confirmation should
   be enabled for production (users verify real email). For M1 testing,
   confirmation can be disabled. Passwords are the only supported factor
   in M1.

5. **Account deletion** — privileged/server-side path only (decision 17):
   delete the `auth.users` row; `profiles` cascades.

## Verification

Run `verification/c1_security_tests.sql` in the SQL editor (as `postgres`)
or via psql. It seeds disposable test users through the real trigger
pipeline and asserts, using `SET LOCAL ROLE` + `request.jwt.claims` session
impersonation (the same identity PostgREST presents):

- T9 anon: SELECT/INSERT/UPDATE/DELETE on `profiles` → all DENIED
- T9 student: SELECT own → ALLOWED; SELECT other → DENIED; UPDATE own
  (no mutable fields exist) → ALLOWED; UPDATE role → DENIED (T5); UPDATE
  another profile → DENIED; DELETE → DENIED
- counselor/admin spot checks: own-row access only, escalation denied
- INV-02: signup without invitation code → DENIED
- INV-03: valid code → student profile created and code bound; code reuse → DENIED
- INV-04: signup always creates student (role cannot be set by client)
- INV-06: pseudonym uniqueness enforced server-side
- INV-07/08: email privacy — profiles table has no email column

`service_role` is never used. Expected output is only `SEED`/`PASS` notices;
any `TEST FAILED` error must be resolved before proceeding to C2.

Note: if `SET LOCAL ROLE authenticated` is rejected in your session, run the
script as a role with membership of `authenticated` (standard on Supabase
`postgres`).
