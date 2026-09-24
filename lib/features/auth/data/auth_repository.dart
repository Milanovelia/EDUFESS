import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth operations for Edufess.
///
/// Only exposes what C2 needs: sign-up, sign-in, sign-out, and session
/// access. Never stores tokens manually — Supabase manages the session.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// Current session, if any. `null` when logged out.
  Session? get currentSession => _auth.currentSession;

  /// Current Supabase user, if any.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (sign-in, sign-out, token refresh).
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// Registers a new user with email + password.
  ///
  /// [pseudonym] and [inviteCode] are passed as Supabase user metadata.
  /// The database trigger `guard_new_user()` validates them server-side.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String pseudonym,
    required String inviteCode,
  }) async {
    return _auth.signUp(
      email: email,
      password: password,
      data: {'pseudonym': pseudonym, 'invite_code': inviteCode},
    );
  }

  /// Signs in with email + password.
  ///
  /// [20] second timeout protection to prevent indefinite loading.
  /// The timeout is applied directly to the Supabase Future to ensure
  /// a real wall-clock timeout, not just a post-completion check.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    // REAL timeout: applied directly to the Supabase Future.
    // If the request takes >20s, onTimeout fires and throws TimeoutException,
    // which the caller (AuthController) translates into a safe message.
    return _auth
        .signInWithPassword(email: email, password: password)
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException('Login request timed out');
          },
        );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
