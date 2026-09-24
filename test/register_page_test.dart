import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/features/auth/data/auth_exception.dart';
import 'package:edufess/features/auth/presentation/pages/register_page.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';

void main() {
  setUp(() {
    _MockAuthController.nextSignUpResult = null;
  });

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

  group('RegisterPage feedback', () {
    testWidgets('shows confirmation dialog when account awaits email confirmation',
        (tester) async {
      _MockAuthController.nextSignUpResult =
          const EmailConfirmationRequiredException();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController()),
          ],
          child: const MaterialApp(home: RegisterPage()),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      expect(find.text('Pendaftaran Berhasil'), findsOneWidget);
      expect(find.textContaining('Periksa email'), findsOneWidget);
    });

    testWidgets('shows Indonesian error snackbar for invalid invitation',
        (tester) async {
      _MockAuthController.nextSignUpResult =
          const InvalidInvitationException();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController()),
          ],
          child: const MaterialApp(home: RegisterPage()),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.text('Daftar'));
      await tester.pump();

      expect(
        find.text('Kode undangan tidak valid atau sudah digunakan.'),
        findsOneWidget,
      );
    });

    testWidgets('shows Indonesian snackbar for generic error', (tester) async {
      _MockAuthController.nextSignUpResult =
          const AuthGenericException('Terjadi kesalahan. Silakan coba lagi nanti.');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _MockAuthController()),
          ],
          child: const MaterialApp(home: RegisterPage()),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await tester.tap(find.text('Daftar'));
      await tester.pump();

      expect(find.text('Terjadi kesalahan. Silakan coba lagi nanti.'),
          findsOneWidget);
    });
  });
}

Future<void> _fillValidForm(WidgetTester tester) async {
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
}

/// Mock auth controller with configurable sign-up result (no Supabase).
class _MockAuthController extends Notifier<AsyncValue<void>>
    implements AuthController {
  static AuthException? nextSignUpResult;

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
    return nextSignUpResult;
  }

  @override
  void reset() {}

  @override
  Future<void> signOut() async {}
}
