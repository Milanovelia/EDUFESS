import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/features/auth/data/auth_exception.dart';
import 'package:edufess/features/auth/presentation/pages/register_page.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';

void main() {
  group('RegisterPage', () {
    Widget buildRegisterScreen() {
      return ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _MockAuthController()),
        ],
        child: const MaterialApp(home: RegisterPage()),
      );
    }

    testWidgets('renders all form fields', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Pseudonim'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi'), findsOneWidget);
      expect(find.text('Kode Undangan'), findsOneWidget);
    });

    testWidgets('renders register button', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      expect(find.text('Daftar'), findsOneWidget);
    });

    testWidgets('renders login link', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsOneWidget);
    });

    testWidgets('shows error for invalid email format', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'notanemail',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Format email tidak valid.'), findsOneWidget);
    });

    testWidgets('shows error when pseudonym is empty', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Pseudonim wajib diisi.'), findsOneWidget);
    });

    testWidgets('shows error for short pseudonym', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'ab',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Pseudonim harus 3-32 karakter.'), findsOneWidget);
    });

    testWidgets('shows error when password is empty', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'TestUser',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
    });

    testWidgets('shows error for short password', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'TestUser',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        '12345',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi minimal 6 karakter.'), findsOneWidget);
    });

    testWidgets('shows error when confirm password is empty', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'TestUser',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        'password123',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi kata sandi wajib diisi.'), findsOneWidget);
    });

    testWidgets('shows error when passwords do not match', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'TestUser',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Konfirmasi Kata Sandi'),
        'differentpassword',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi tidak cocok.'), findsOneWidget);
    });

    testWidgets('shows error when invitation code is empty', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'TestUser',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Konfirmasi Kata Sandi'),
        'password123',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Kode undangan wajib diisi.'), findsOneWidget);
    });

    testWidgets('does not show errors with valid input', (tester) async {
      await tester.pumpWidget(buildRegisterScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pseudonim'),
        'TestUser',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Konfirmasi Kata Sandi'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kode Undangan'),
        'INVITE-123',
      );
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Email wajib diisi.'), findsNothing);
      expect(find.text('Pseudonim wajib diisi.'), findsNothing);
      expect(find.text('Kata sandi wajib diisi.'), findsNothing);
      expect(find.text('Konfirmasi kata sandi wajib diisi.'), findsNothing);
      expect(find.text('Kode undangan wajib diisi.'), findsNothing);
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
