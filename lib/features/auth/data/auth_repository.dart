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
      data: {
        'pseudonym': pseudonym,
        'invite_code': inviteCode,
      },
    );
  }

  /// Signs in with email + password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
