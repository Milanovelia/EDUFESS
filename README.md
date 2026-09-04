# EduFess

EduFess — School Knowledge-Sharing Community + Private BK Support.

Students share notes and discussions in a public feed; counseling (BK) stays in a separate, private, audited security domain. Pseudonymous is not anonymous — the backend retains user IDs, but the public UI never reveals the real identity of a pseudonymous user.

## Roles

- **student** — default, creates posts/comments, Helpful/bookmarks, BK counseling, mood, appointments, Peduli Teman
- **counselor** — handles BK conversations, mood history (assigned only), appointments, Peer Concern queue, identity reveal (audited)
- **admin** — social moderation only (reports, dismiss/remove), no BK access

Key invariants: `counselor != social moderator`, `admin != BK counselor`, `BK IS A SEPARATE SECURITY DOMAIN`.

## Stack

- Flutter 3.47.0 / Dart 3.13.0, Android-first, Material 3
- flutter_riverpod (state), go_router (navigation), supabase_flutter (backend), flutter_dotenv (env)

## Privacy & Security Model

- **Pseudonymous ≠ fully anonymous** — backend stores user IDs, public UI shows alias only (`Siswa Anonim #XXXX` for social, `Siswa BK #XXXX` for BK)
- Email is private, never in public projections
- BK conversations/messages/appointments/mood/Peer Concern are BK-private, not in posts_feed/comments_feed/search_posts/moderation queue
- Authorization is server-side via Supabase RLS + SECURITY DEFINER RPCs with `SET search_path = ''`, schema-qualified refs, `auth.uid()` and role checks, minimal grants (anon denied, PUBLIC revoked, authenticated only where needed)
- Identity reveal is explicit, reason-required (1..500), audited in `bk_identity_access_log`, queue remains alias-only
- Mood is non-diagnostic (1..5, optional note 1..1000, append-only), no AI/risk scoring, disclaimer visible
- Peer Concern (Peduli Teman) is BK-private, not social report, reporter/target privacy via alias-only queue, no directory dump (search >=2 chars, limit 20)
- Notifications are generic (e.g., "Ada pesan baru di Ruang BK.") — no message/mood/peer target/details/email/identity

## Project Structure

```text
lib/app/       app-wide wiring: app.dart, router.dart, app_shell.dart, theme
lib/core/      config, constants, errors, widgets
lib/features/
  auth/        login, register, profile, session
  feed/        posts, comments, Helpful, bookmarks, Best Answer, PostCard
  explore/     search, filters, sorting, pagination, recent searches
  counseling/  BK: consent, conversations, messages, appointments, mood, peer concern
  notifications/ in-app center, unread, mark read
  profile/     pseudonym, role, logout
test/         widget/unit tests (151)
supabase/
  migrations/  forward-only, 20260831000000 .. 20260831000017
  verification/ m6..m12 security suites (actually executed)
```

## Setup (Fresh Clone)

1. **Prerequisites**: Flutter SDK stable with Android toolchain (`flutter doctor -v` should show Android toolchain).

2. **Environment**: Copy `.env.example` to `.env` and fill your Supabase project values:
   ```text
   SUPABASE_URL=<your project url>
   SUPABASE_ANON_KEY=<your project anon key>
   ```
   `.env` is gitignored and must never be committed. Without it the app boots but runs without backend (see `lib/core/config/app_env.dart` and `supabase_bootstrap.dart`).

3. **Supabase**: Create a project, enable Auth (email), then apply migrations:
   ```bash
   npx supabase link --project-ref <ref>
   npx supabase db push --linked
   npx supabase migration list --linked # should show LOCAL = REMOTE
   ```
   RLS is enabled on all private tables; SECURITY DEFINER functions use `SET search_path = ''` and minimal grants.

4. **Install & verify**:
   ```bash
   flutter pub get
   flutter analyze # must be "No issues found"
   flutter test    # 151/151 PASS
   ```

5. **Run**:
   ```bash
   flutter run # Android device/emulator
   ```

6. **Build**:
   ```bash
   flutter build apk --debug # → build/app/outputs/flutter-apk/app-debug.apk
   flutter build apk --release # requires signing, see below
   flutter build appbundle --release # for Play Store, if signing ready
   ```

## Tests & Verification

```bash
flutter analyze
flutter test
# DB security (actually executed, not inferred)
npx supabase db query --linked --file supabase/verification/m6_security_tests.sql
npx supabase db query --linked --file supabase/verification/m7_security_tests.sql
npx supabase db query --linked --file supabase/verification/m8_security_tests.sql
npx supabase db query --linked --file supabase/verification/m9_security_tests.sql
npx supabase db query --linked --file supabase/verification/m10_security_tests.sql
npx supabase db query --linked --file supabase/verification/m11_security_tests.sql
npx supabase db query --linked --file supabase/verification/m12_security_tests.sql
```

## Android Build

- **Package**: `com.edufess.edufess` (namespace/applicationId, not `com.example.*`)
- **Permissions**: only `INTERNET` (no CAMERA, RECORD_AUDIO, CONTACTS, LOCATION, SMS, STORAGE)
- **Network**: HTTPS only, no `usesCleartextTraffic`
- **Version**: `1.0.0+1` (pubspec.yaml), minSdk/targetSdk/compileSdk from `flutter.*`
- **Signing**: Release signing NOT CONFIGURED for MVP demo — debug APK is ready (`flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`). For signed release, create `android/app/key.properties` and `*.jks` (gitignored) and run `flutter build apk --release` / `flutter build appbundle --release`.

## Demo Checklist

**Student**: register (invite code) → login → create post (note/question) → Helpful/comment/reply → bookmark → Saved → Explore/search → BK → consent (bk-consent-v1) → start counseling (alias) → send message → appointments (request via available slot, cancel) → mood check-in (1..5 + note, history) → Peduli Teman (search peer >=2 chars, submit, history) → Notifications (mark read) → logout → login as different user (no leakage)

**Counselor**: login → BK → queue (alias-only, Tangani) → claim → conversation → reply → mood history (assigned only) → appointments (availability, accept/reject/reschedule/cancel/complete) → Peer Concern (queue, claim, detail, resolve/dismiss) → identity reveal (reason required, audited) → close conversation → notifications → logout

**Admin**: login → social app → moderation (queue alias-only, dismiss/remove, no reporter identity) → notifications (own only) → profile → verify BK denied (no queue/message/mood/peer concern/appointments)

## Status

- M0 Foundation: complete
- M1 Authentication: complete (invite-gated, student default, role immutable via JWT)
- M2 Social Foundation: complete (subjects/topics, posts, feed, pseudonymous, soft delete)
- M3 Social Interaction: complete (comments, Helpful, bookmarks, Best Answer)
- M4 Explore & Search: complete (search title/content/subject/topic, filters, sorting, pagination, privacy-safe)
- M5 Social Moderation: complete (reports, duplicate prevention, admin queue alias-only, dismiss/remove, audit)
- M6 BK Security Foundation: complete (consent, conversations alias BK, messages participant-only, claim, reveal audited)
- M7 BK Student Experience: complete (consent UX, student landing, one-active, minimal projections, is_mine, closed read-only)
- M8 Counselor Experience: complete (queue alias-only, claim, assigned, close, reveal, mood history)
- M9 Appointments: complete (availability, request, double-booking, alias privacy, accept/reject/reschedule/cancel/complete)
- M10 Mood Check-In: complete (1..5 non-diagnostic, note 1..1000, own-only, assigned counselor scope, closed denies, append-only)
- M11 Peer Concern: complete (search >=2, self-target denied, reporter own history, target cannot see, counselor queue alias-only, claim/resolve/dismiss, no auto-creation)
- M12 Notifications: complete (in-app center, unread, mark read/all, generic BK copy, appointment/peer concern/social, route does not bypass, search_peer_students hardened to student-only)
- M13 Hardening: complete (autoDispose for user-scoped providers, PostCard overflow fix, responsive, accessibility, hardening tests)
- M14 Release Readiness: this audit

## Privacy Notes

- Pseudonymous ≠ fully anonymous; email private; BK is separate domain; identity reveal audited; Peer Concern reporter privacy via alias-only queue; Mood is self-reported, not diagnosis.

## License

Private — not for public distribution.
