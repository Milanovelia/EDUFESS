import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:edufess/features/auth/data/auth_exception.dart';
import 'package:edufess/features/auth/presentation/pages/login_page.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';

/// AUTH-LOGIN-LOADING: the login form spinner must represent ONLY a
/// user-initiated submission — never session init, sign-out, or any other
/// shared-controller state.
void main() {
  group('LoginPage submission loading', () {
    late _FakeAuthController controller;

    setUp(() {
      _FakeAuthController.resetStatics();
      controller = _FakeAuthController();
    });

    Widget buildLoginScreen() {
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('home-sink')),
          ),
        ],
      );
      addTearDown(router.dispose);
      return ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => controller)],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
        'password123',
      );
      await tester.pump();
    }

    bool fieldsEnabled(WidgetTester tester) {
      final email = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Email'),
      );
      final password = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Kata Sandi'),
      );
      return email.enabled && password.enabled;
    }

    // AUTH-LOGIN-LOADING-01
    testWidgets('fresh logged-out page is interactive, no spinner', (
      tester,
    ) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fieldsEnabled(tester), isTrue);
      final register = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Belum punya akun? Daftar'),
      );
      expect(register.onPressed, isNotNull);
    });

    // AUTH-LOGIN-LOADING-02
    testWidgets('pending submission shows spinner and disables form', (
      tester,
    ) async {
      _FakeAuthController.gate = Completer<AuthException?>();
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();
      await fillValidForm(tester);

      await tester.tap(find.text('Masuk'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Masuk'), findsNothing);
      expect(fieldsEnabled(tester), isFalse);

      // Release the gate: success navigates home, spinner gone.
      _FakeAuthController.gate!.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('home-sink'), findsOneWidget);
    });

    // AUTH-LOGIN-LOADING-03
    testWidgets('failed login resets to interactive form', (tester) async {
      _FakeAuthController.nextResult = const AuthGenericException(
        'Email atau kata sandi salah.',
      );
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();
      await fillValidForm(tester);

      await tester.tap(find.text('Masuk'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fieldsEnabled(tester), isTrue);
    });

    // AUTH-LOGIN-LOADING-04
    testWidgets('timeout resets form and keeps timeout message', (
      tester,
    ) async {
      _FakeAuthController.nextResult = const AuthGenericException(
        'Koneksi ke server terlalu lama. Coba lagi.',
      );
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();
      await fillValidForm(tester);

      await tester.tap(find.text('Masuk'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Koneksi ke server terlalu lama. Coba lagi.'),
        findsOneWidget,
      );
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fieldsEnabled(tester), isTrue);
    });

    // AUTH-LOGIN-LOADING-05
    testWidgets('stuck sign-out controller state does not freeze login', (
      tester,
    ) async {
      // Simulate the reported bug: shared controller left in AsyncLoading
      // (e.g. after logout). The form must ignore it.
      _FakeAuthController.initialState = const AsyncLoading();
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fieldsEnabled(tester), isTrue);
    });

    // AUTH-LOGIN-LOADING-06
    testWidgets('opening login page never calls signIn', (tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(_FakeAuthController.signInCalls, 0);
    });
  });
}

/// Controllable stand-in: static knobs so tests can pend, fail, or
/// pre-load the controller state.
class _FakeAuthController extends Notifier<AsyncValue<void>>
    implements AuthController {
  static Completer<AuthException?>? gate;
  static AuthException? nextResult;
  static int signInCalls = 0;
  static AsyncValue<void> initialState = const AsyncData(null);

  static void resetStatics() {
    gate = null;
    nextResult = null;
    signInCalls = 0;
    initialState = const AsyncData(null);
  }

  @override
  AsyncValue<void> build() => initialState;

  @override
  Future<AuthException?> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (gate != null) return gate!.future;
    return nextResult;
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
  void reset() {}

  @override
  Future<void> signOut() async {}
}
