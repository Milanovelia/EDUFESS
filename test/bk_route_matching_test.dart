import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/app/router.dart';
import 'package:edufess/features/auth/data/auth_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_providers.dart';

/// BK-01 regression: the dynamic `/bk/:id` route must be matched AFTER all
/// static BK routes. go_router matches top-level routes in declaration
/// order, so `/bk/:id` declared first captured `mood`, `appointments`,
/// `availability` and `peduli-teman` as bogus conversation ids.
///
/// Strategy: exercise the REAL route table via
/// `GoRouter.configuration.findMatch` — pure route matching, no page
/// builders run, so no Supabase/page providers need mocking beyond the
/// auth repository required to construct the router.
void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
      ],
    );
    addTearDown(container.dispose);
    router = container.read(routerProvider);
  });

  /// Returns the leaf [RouteMatch] for [location], failing on no-match.
  /// Shell matches nest the leaf inside [ShellRouteMatch.matches], so
  /// collect recursively.
  RouteMatch matchLeaf(String location) {
    final matchList = router.configuration.findMatch(Uri.parse(location));
    expect(
      matchList.error,
      isNull,
      reason: 'no route matched $location: ${matchList.error}',
    );
    final leaves = <RouteMatch>[];
    void collect(List<RouteMatchBase> ms) {
      for (final m in ms) {
        if (m is RouteMatch) leaves.add(m);
        if (m is ShellRouteMatch) collect(m.matches);
      }
    }

    collect(matchList.matches);
    expect(leaves, isNotEmpty, reason: location);
    return leaves.last;
  }

  /// Returns the path parameters for [location].
  Map<String, String> matchListParams(String location) =>
      router.configuration.findMatch(Uri.parse(location)).pathParameters;

  /// Asserts [location] resolves to the route named [expectedName] with
  /// exactly [expectedParams] path parameters.
  void expectRoute(
    String location,
    String expectedName, [
    Map<String, String> expectedParams = const {},
  ]) {
    final leaf = matchLeaf(location);
    final route = leaf.route;
    expect(
      route.name,
      expectedName,
      reason: '$location resolved to ${route.path}',
    );
    expect(
      matchListParams(location),
      expectedParams,
      reason: '$location path parameters',
    );
  }

  group('BK-01 static BK routes are not shadowed by /bk/:id', () {
    test('/bk/mood -> BkMoodPage', () {
      expectRoute(AppRoutes.bkMood, AppRoutes.bkMoodName);
    });

    test('/bk/appointments -> BkAppointmentsPage', () {
      expectRoute(AppRoutes.bkAppointments, AppRoutes.bkAppointmentsName);
    });

    test('/bk/availability -> CounselorAvailabilityPage', () {
      expectRoute(
        AppRoutes.counselorAvailability,
        AppRoutes.counselorAvailabilityName,
      );
    });

    test('/bk/peduli-teman -> BkPeerConcernPage', () {
      expectRoute(AppRoutes.bkPeerConcern, AppRoutes.bkPeerConcernName);
    });

    test('/bk/peduli-teman/history -> BkPeerConcernHistoryPage', () {
      expectRoute(
        AppRoutes.bkPeerConcernHistory,
        AppRoutes.bkPeerConcernHistoryName,
      );
    });

    test('/bk/peduli-teman/counselor -> CounselorPeerConcernQueuePage', () {
      expectRoute(
        AppRoutes.counselorPeerConcernQueue,
        AppRoutes.counselorPeerConcernQueueName,
      );
    });

    test(
      '/bk/peduli-teman/counselor/<id> -> CounselorPeerConcernDetailPage',
      () {
        expectRoute(
          '${AppRoutes.counselorPeerConcernQueue}/concern-123',
          AppRoutes.counselorPeerConcernDetailName,
          {'id': 'concern-123'},
        );
      },
    );

    test('/bk/mood/<id> -> CounselorMoodHistoryPage', () {
      expectRoute(
        '${AppRoutes.bkMood}/conv-456',
        AppRoutes.counselorMoodHistoryName,
        {'id': 'conv-456'},
      );
    });

    test('/bk/counselor/appointments -> CounselorAppointmentsPage', () {
      expectRoute(
        AppRoutes.counselorAppointments,
        AppRoutes.counselorAppointmentsName,
      );
    });

    test('/bk/<conversation-id> -> BkConversationPage', () {
      expectRoute('${AppRoutes.bk}/conv-789', AppRoutes.bkConversationName, {
        'id': 'conv-789',
      });
    });

    test('/bk -> BkPage (shell branch, unaffected)', () {
      expectRoute(AppRoutes.bk, AppRoutes.bkName);
    });
  });

  group('BK-01 static segments are NOT conversation ids', () {
    for (final location in [
      AppRoutes.bkMood,
      AppRoutes.bkAppointments,
      AppRoutes.counselorAvailability,
      AppRoutes.bkPeerConcern,
    ]) {
      test('$location carries no :id parameter', () {
        final leaf = matchLeaf(location);
        expect(
          leaf.route.path,
          isNot(AppRoutes.bkConversation),
          reason: '$location shadowed by /bk/:id',
        );
        expect(
          matchListParams(location),
          isNot(contains('id')),
          reason: '$location interpreted as conversation id',
        );
      });
    }
  });
}

/// Minimal auth repository stand-in: route *matching* never touches auth,
/// but constructing the real router still requires the provider.
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
