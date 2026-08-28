# AGENTS.md — EduFess

Working rules for AI agents and contributors on this repository.

## Project purpose

Edufess is a school knowledge-sharing community app with a privacy-conscious
bridge to counseling (BK) services. Students share notes and discussions in a
public feed; counseling stays in a separate, private space.

## Stack

- Flutter (stable) / Dart ^3.13.0, Android-first
- flutter_riverpod (state), go_router (navigation), supabase_flutter (backend),
  flutter_dotenv (environment)

## Architecture principle

- Feature-first: `lib/features/<feature>/` owns its screens; shared code lives
  in `lib/core/`, app-wide wiring in `lib/app/`.
- Keep it simple and maintainable. Do NOT introduce clean architecture
  4-layer (data/domain/presentation split). Do not over-engineer.
- Android-first. Do not add platform-specific workarounds for other platforms
  unless asked.
- Match the existing code style: `abstract final class` for utility holders,
  short doc comments, comments only where they earn their place.

## Run & verify

```bash
flutter pub get
flutter analyze
flutter test
```

## Secrets

`.env` holds real Supabase credentials and is git-ignored. Never commit it,
never hardcode credentials in source. `.env.example` documents the required
keys.

## Privacy invariants (apply to every milestone)

1. BK/counseling data must never enter the public feed.
2. Pseudonymous is not anonymous; the backend still stores user IDs.
3. Public UI must never reveal the real identity of a pseudonymous user.
4. Authorization is enforced server-side via Supabase RLS, never by Flutter.
5. Students must not be able to elevate their own role.
6. Counseling is accessible only to authorized participants.
7. Counselor identity reveal must be auditable.
8. Mood check-in must never diagnose.
9. BK notifications must not leak sensitive details.
10. Social admins do not automatically gain counseling access.

## Scope discipline

- Do not implement the next milestone (auth, feed, counseling flows, DB
  migrations, RLS) without explicit instruction.
- Do not commit or push without the user's confirmation.
