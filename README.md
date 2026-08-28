# EduFess

Edufess is a school knowledge-sharing community app with a privacy-conscious
bridge to counseling (BK) services. Students share notes and discussions in a
public feed; counseling stays in a separate, private space.

## Stack

- Flutter (stable) / Dart ^3.13.0, Android-first
- flutter_riverpod, go_router, supabase_flutter, flutter_dotenv

## Structure

```text
lib/app/       app-wide wiring: root widget, router, shell, theme
lib/core/      shared config, constants, errors, widgets
lib/features/  feed, explore, create_post, counseling, profile
```

## Getting started

Prerequisite: Flutter SDK (stable) with the Android toolchain.

1. Copy `.env.example` to `.env` and fill in your Supabase project values:

   ```text
   SUPABASE_URL=<your project url>
   SUPABASE_ANON_KEY=<your project anon key>
   ```

   `.env` is git-ignored and must never be committed. Without it the app
   still boots, but runs without a backend.

2. Install dependencies and verify:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```

3. Run on an Android device or emulator:

   ```bash
   flutter run
   ```

## Status

- M0 Foundation: complete (bootstrap, navigation shell, theming,
  Supabase/environment wiring, placeholder screens).
- M1 Authentication: not implemented yet.
