import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/app/app.dart';
import 'package:edufess/features/auth/presentation/providers/auth_providers.dart';
import 'package:edufess/features/auth/data/auth_repository.dart';

void main() {
  group('App smoke tests (unauthenticated)', () {
    testWidgets('redirects to login when not authenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWithValue(const AsyncData(null)),
            authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
          ],
          child: const EdufessApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show login page
      expect(find.text('Masuk ke EduFess'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
    });
  });
}

/// Mock auth repository that returns no session.
class _MockAuthRepository implements AuthRepository {
  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String pseudonym,
    required String inviteCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
