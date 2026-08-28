import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/features/auth/data/auth_exception.dart';
import 'package:edufess/features/auth/presentation/pages/login_page.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';

void main() {
  group('LoginPage', () {
    Widget buildLoginScreen() {
      return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _MockAuthController()),
        ],
        child: const MaterialApp(home: LoginPage()),
      );
    }

    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
    });

    testWidgets('renders login button', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
    });

    testWidgets('renders register link', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Belum punya akun? Daftar'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      // Tap login without filling fields
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
    });

    testWidgets('shows error for invalid email format', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalidemail',
      );
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid.'), findsOneWidget);
    });

    testWidgets('shows error when password is empty', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
    });

    testWidgets('does not show errors with valid input', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        'password123',
      );
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsNothing);
      expect(find.text('Kata sandi wajib diisi.'), findsNothing);
    });
  });
}

/// Mock auth controller that does nothing (no Supabase connection).
class _MockAuthController extends Notifier<AsyncValue<void>>
    implements AuthController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  @override
  Future<AuthException?> signIn({
    required String email,
    required String password,
  }) async {
    return null;
  }

  @override
  Future<AuthException?> signUp({
    required String email,
    required String password,
    required String pseudonym,
    required String inviteCode,
  }) async {
    return null;
  }

  @override
  Future<void> signOut() async {}
}
