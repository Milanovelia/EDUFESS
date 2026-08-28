import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../data/auth_repository.dart';

/// Provides the [AuthRepository] wrapping Supabase Auth.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Exposes the current Supabase [Session].
///
/// `null` when logged out. Updates automatically via `onAuthStateChange`.
final currentSessionProvider = StreamProvider<Session?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges.map((state) => state.session);
});

/// Whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final session = ref.watch(currentSessionProvider);
  return session.hasValue && session.value != null;
});

/// Current Supabase [User], or `null` when logged out.
final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session case AsyncData(:final value)) {
    return value?.user;
  }
  return null;
});
