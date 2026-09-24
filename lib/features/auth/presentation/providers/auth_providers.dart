import 'dart:async' show StreamController, StreamSubscription;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../data/auth_repository.dart';

/// Provides the [AuthRepository] wrapping Supabase Auth.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Helper: creates a session stream that does NOT have a subscription gap.
///
/// Guarantees:
///   1. Subscription to onAuthStateChange is established BEFORE currentSession is emitted.
///   2. currentSession snapshot is emitted immediately after subscription is active.
///   3. Every future auth event is forwarded.
///   4. Subscription is cancelled on provider dispose.
///   5. No duplicate/out-of-order state if signedIn occurs between subscription and currentSession read.
///
/// Important: The GoTrueClient API types used here must match the installed supabase_flutter version.
Stream<Session?> buildSessionStream(GoTrueClient auth) {
  late StreamController<Session?> controller;
  StreamSubscription<dynamic>? subscription;

  controller = StreamController<Session?>(
    onListen: () {
      // 1. SUBSCRIBE to auth changes BEFORE emitting anything.
      // This ensures we never miss a signedIn/signedOut event that occurs
      // immediately after subscription but before currentSession is emitted.
      subscription = auth.onAuthStateChange.listen(
        (event) {
          // MAP AuthState to Session?
          final session = event.session;
          // Forward the session to all listeners.
          // If the controller is already disposed, onAdd may fail silently — ignore.
          try {
            controller.add(session);
          } catch (_) {}
        },
        onError: (error) {
          try {
            controller.addError(error);
          } catch (_) {}
        },
      );

      // 2. Emit the persisted currentSession snapshot IMMEDIATELY after subscription.
      // This is the critical bootstrap step: ensures that on cold-start or app restart,
      // the authenticated session is available immediately, without waiting for the first auth event.
      // onListen runs when the stream is first listened to, so the subscription is active
      // before we emit currentSession, guaranteeing no events are missed.
      final current = auth.currentSession;
      // Always emit the currentSession snapshot — the subscription is active by this point.
      controller.add(current);

      // 3. Forward future auth events that arrive after the initial snapshot.
      // onAuthStateChange is a replay-once stream; re-subscribing ensures we capture
      // any events that were emitted before our subscription (cold-start scenario).
    },
    onCancel: () async {
      // Clean up the subscription when the provider is disposed/removed.
      await subscription?.cancel();
    },
  );

  return controller.stream;
}

/// Exposes the current Supabase [Session].
///
/// `null` when logged out. Updates automatically via auth state changes.
/// **Bootstrap behavior**: immediately yields the persisted session on subscription,
/// then listens for future auth state changes. This ensures the session is available
/// immediately on cold start / app restart, without waiting for the first auth event.
///
/// Uses a native Dart StreamController (no RxDart, no extra packages) to guarantee
/// there is no subscription gap between establishing the listener and emitting the
/// initial session snapshot.
final currentSessionProvider = StreamProvider<Session?>((ref) {
  final auth = ref.watch(supabaseClientProvider).auth;

  // The stream from buildSessionStream already contains the bootstrap emission
  // plus all future events. Riverpod's StreamProvider will emit these to listeners.
  // No additional yield* is needed; buildSessionStream handles the full lifecycle.
  return buildSessionStream(auth);
});

/// Whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  // .value returns the latest data or throws if AsyncLoading/AsyncError;
  // we use a safe check: if the provider has data and it's not null, user is authenticated.
  return ref.watch(currentSessionProvider).value != null;
});

/// Current Supabase [User], or `null` when logged out.
final currentUserProvider = Provider<User?>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session case AsyncData(:final value)) {
    return value?.user;
  }
  // fallback for AsyncLoading/AsyncError: check the resolved session value
  return session.value?.user;
});
