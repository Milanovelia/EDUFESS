import 'package:flutter_test/flutter_test.dart';

import 'package:edufess/app/router.dart';

/// Verifies the router uses the DIRECT Supabase session as authority.
///
/// The critical race: immediately after signIn, `auth.currentSession != null`
/// while `currentSessionProvider` is still `AsyncData(null)`. The router must
/// follow the direct session, not the lagging provider.
void main() {
  group('resolveAuthRedirect — direct session authority', () {
    test('1. direct true + provider stale null -> protected Home ALLOWED', () {
      // Live login race window: direct session already valid, provider
      // still null. Router must NOT bounce back to login.
      final result = resolveAuthRedirect(AppRoutes.home, isLoggedIn: true);
      expect(result, isNull);
    });

    test(
      '2. direct false + provider stale Session -> protected Home DENIED',
      () {
        // Logout race window (or stale provider): direct session is null,
        // so protected Home must redirect to login even if the provider
        // still holds an old session.
        final result = resolveAuthRedirect(AppRoutes.home, isLoggedIn: false);
        expect(result, AppRoutes.login);
      },
    );

    test('3. live login -> auth route redirects Home without restart', () {
      // context.go('/') after sign-in lands via redirect; an authenticated
      // user sitting on /auth/login must be sent to /.
      expect(
        resolveAuthRedirect(AppRoutes.login, isLoggedIn: true),
        AppRoutes.home,
      );
      expect(
        resolveAuthRedirect(AppRoutes.register, isLoggedIn: true),
        AppRoutes.home,
      );
    });

    test('4. logout -> protected route redirects Login immediately', () {
      for (final location in [
        AppRoutes.home,
        AppRoutes.explore,
        AppRoutes.bk,
        AppRoutes.profile,
      ]) {
        expect(
          resolveAuthRedirect(location, isLoggedIn: false),
          AppRoutes.login,
          reason: 'logged-out user on $location must go to login',
        );
      }
      // Auth routes stay put when logged out (no loop).
      expect(resolveAuthRedirect(AppRoutes.login, isLoggedIn: false), isNull);
      expect(
        resolveAuthRedirect(AppRoutes.register, isLoggedIn: false),
        isNull,
      );
    });

    test('5. persisted session cold start -> Home allowed', () {
      // Cold start with stored session: direct session true on launch.
      expect(resolveAuthRedirect(AppRoutes.home, isLoggedIn: true), isNull);
      expect(
        resolveAuthRedirect(AppRoutes.login, isLoggedIn: true),
        AppRoutes.home,
      );
    });

    test('6. no persisted session -> protected routes go to Login', () {
      expect(
        resolveAuthRedirect(AppRoutes.home, isLoggedIn: false),
        AppRoutes.login,
      );
      expect(resolveAuthRedirect(AppRoutes.login, isLoggedIn: false), isNull);
    });

    test('authenticated user on app routes stays (no redirect loop)', () {
      for (final location in [
        AppRoutes.home,
        AppRoutes.explore,
        AppRoutes.bk,
        AppRoutes.profile,
      ]) {
        expect(
          resolveAuthRedirect(location, isLoggedIn: true),
          isNull,
          reason: 'logged-in user on $location must stay',
        );
      }
    });
  });
}
