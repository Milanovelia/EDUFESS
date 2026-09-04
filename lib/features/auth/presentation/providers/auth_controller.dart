import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/auth_exception.dart';
import '../../data/profile_repository.dart';
import '../../../../core/config/supabase_providers.dart';
import 'auth_providers.dart';

/// Profile repository provider.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Current user's profile. `null` when not authenticated or profile not loaded.
final currentProfileProvider = FutureProvider.autoDispose<UserProfile?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session case AsyncData(:final value)) {
    if (value == null) return null;
  } else {
    return null;
  }

  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchCurrentProfile();
});

/// Auth form controller managing sign-in/sign-up state.
///
/// Exposes [signIn] and [signUp] methods. Loading/error states are tracked
/// so the UI can show progress indicators and error messages.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// Signs in with email + password.
  ///
  /// Returns `null` on success, or an [AuthException] on failure.
  Future<AuthException?> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.signIn(email: email, password: password);
      state = const AsyncData(null);
      return null;
    } on Object catch (e) {
      state = const AsyncData(null);
      return translateAuthError(e);
    }
  }

  /// Registers a new user with email, password, pseudonym, and invitation code.
  ///
  /// Returns `null` on success, in which case a session exists and the router
  /// redirects to the home page. Returns an [AuthException] otherwise:
  /// - [EmailConfirmationRequiredException] when the account was created but
  ///   awaits email confirmation (no session yet);
  /// - a translated failure for every other error.
  Future<AuthException?> signUp({
    required String email,
    required String password,
    required String pseudonym,
    required String inviteCode,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await _repo.signUp(
        email: email,
        password: password,
        pseudonym: pseudonym,
        inviteCode: inviteCode,
      );

      // No session → account awaits email confirmation. Surface a clear
      // message so the UI never appears to "do nothing".
      if (response.session == null) {
        state = const AsyncData(null);
        return const EmailConfirmationRequiredException();
      }

      // Session created → let the auth stream drive the redirect to home.
      state = const AsyncData(null);
      ref.invalidate(currentSessionProvider);
      return null;
    } on Object catch (e) {
      state = const AsyncData(null);
      return translateAuthError(e);
    }
  }

  /// Signs out the current user and clears user-scoped state.
  Future<void> signOut() async {
    state = const AsyncLoading();
    await _repo.signOut();
    // Invalidate user-scoped providers to prevent cross-user leakage
    ref.invalidate(currentProfileProvider);
    // Use try to avoid import cycles — providers will be invalidated via ref.invalidate if available
    // Explicitly invalidate known user-scoped providers (best-effort, ignore if not found)
    try {
      ref.invalidate(currentSessionProvider);
    } catch (_) {}
    state = const AsyncData(null);
  }
}

/// Provider for [AuthController].
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);
