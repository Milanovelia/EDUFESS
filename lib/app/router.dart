import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../core/config/supabase_providers.dart';

import 'package:edufess/features/counseling/presentation/pages/bk_appointments_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_mood_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_conversation_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_peer_concern_history_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_peer_concern_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_appointments_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_availability_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_mood_history_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_peer_concern_detail_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_peer_concern_queue_page.dart';
import 'package:edufess/features/notifications/presentation/pages/notifications_page.dart';
import 'package:edufess/features/create_post/presentation/pages/create_post_page.dart';

import '../features/explore/presentation/pages/explore_page.dart';
import '../features/feed/presentation/pages/home_page.dart';
import '../features/feed/presentation/pages/post_detail_page.dart';
import '../features/moderation/presentation/pages/moderation_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/saved/presentation/pages/saved_page.dart';
import 'app_shell.dart';

/// Route paths and names. Keep string literals in one place only.
abstract final class AppRoutes {
  // Auth routes
  static const String login = '/auth/login';
  static const String loginName = 'login';
  static const String register = '/auth/register';
  static const String registerName = 'register';

  // App routes
  static const String home = '/';
  static const String homeName = 'home';

  static const String explore = '/explore';
  static const String exploreName = 'explore';

  static const String create = '/create';
  static const String createName = 'create';

  static const String bk = '/bk';
  static const String bkName = 'bk';

  static const String profile = '/profile';
  static const String profileName = 'profile';

  static const String postDetailBase = '/post';
  static const String postDetail = '/post/:id';
  static const String postDetailName = 'postDetail';

  static const String saved = '/saved';
  static const String savedName = 'saved';

  static const String moderation = '/admin/moderation';
  static const String moderationName = 'moderation';

  static const String bkConversation = '/bk/:id';
  static const String bkConversationName = 'bkConversation';

  static const String bkAppointments = '/bk/appointments';
  static const String bkAppointmentsName = 'bkAppointments';

  static const String counselorAvailability = '/bk/availability';
  static const String counselorAvailabilityName = 'counselorAvailability';

  static const String counselorAppointments = '/bk/counselor/appointments';
  static const String counselorAppointmentsName = 'counselorAppointments';

  static const String bkMood = '/bk/mood';
  static const String bkMoodName = 'bkMood';

  static const String counselorMoodHistory = '/bk/mood/:id';
  static const String counselorMoodHistoryName = 'counselorMoodHistory';

  static const String bkPeerConcern = '/bk/peduli-teman';
  static const String bkPeerConcernName = 'bkPeerConcern';

  static const String bkPeerConcernHistory = '/bk/peduli-teman/history';
  static const String bkPeerConcernHistoryName = 'bkPeerConcernHistory';

  static const String counselorPeerConcernQueue = '/bk/peduli-teman/counselor';
  static const String counselorPeerConcernQueueName =
      'counselorPeerConcernQueue';

  static const String counselorPeerConcernDetail =
      '/bk/peduli-teman/counselor/:id';
  static const String counselorPeerConcernDetailName =
      'counselorPeerConcernDetail';

  static const String notifications = '/notifications';
  static const String notificationsName = 'notifications';
}

/// Whether the given [location] is an auth route (login or register).
bool _isAuthRoute(String location) =>
    location == AppRoutes.login || location == AppRoutes.register;

/// Pure redirect decision using the **direct** Supabase session.
///
/// [isLoggedIn] must come from `supabase.auth.currentSession != null`
/// (synchronous, authoritative). It must NOT come from
/// `currentSessionProvider`, which can lag one frame behind
/// `authStateChanges` right after sign-in/sign-out.
///
/// - Authenticated user on auth route → [AppRoutes.home]
/// - Unauthenticated user on app route → [AppRoutes.login]
/// - Otherwise → `null` (no redirect, allow)
///
/// Extracted as a top-level pure function so it is unit-testable without
/// mocking Supabase.
String? resolveAuthRedirect(String location, {required bool isLoggedIn}) {
  if (isLoggedIn && _isAuthRoute(location)) {
    return AppRoutes.home;
  }
  if (!isLoggedIn && !_isAuthRoute(location)) {
    return AppRoutes.login;
  }
  return null;
}

/// App router with auth guard.
///
/// - Unauthenticated user attempting app route → `/auth/login`
/// - Authenticated user attempting login/register → `/`
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authRepositoryProvider).authStateChanges.map((_) => null),
    ),
    redirect: (context, state) {
      final location = state.matchedLocation;

      // AUTHORITATIVE: direct synchronous Supabase session.
      // Valid immediately after signInWithPassword() returns, with no
      // provider/stream lag. Router decisions must use this — never the
      // lagging currentSessionProvider snapshot.
      bool isLoggedIn;
      try {
        final auth = ref.read(supabaseClientProvider).auth;
        isLoggedIn = auth.currentSession != null;
      } catch (_) {
        // Supabase not initialized (e.g. widget tests without overrides).
        // Fail closed: treat as logged out so protected routes go to login.
        isLoggedIn = false;
      }

      return resolveAuthRedirect(location, isLoggedIn: isLoggedIn);
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterPage(),
      ),

      // Post detail (outside shell to show back button)
      GoRoute(
        path: AppRoutes.postDetail,
        name: AppRoutes.postDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PostDetailPage(postId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.saved,
        name: AppRoutes.savedName,
        builder: (context, state) => const SavedPage(),
      ),
      GoRoute(
        path: AppRoutes.moderation,
        name: AppRoutes.moderationName,
        builder: (context, state) => const ModerationPage(),
      ),
      GoRoute(
        path: AppRoutes.bkConversation,
        name: AppRoutes.bkConversationName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BkConversationPage(conversationId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.bkAppointments,
        name: AppRoutes.bkAppointmentsName,
        builder: (context, state) => const BkAppointmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.counselorAvailability,
        name: AppRoutes.counselorAvailabilityName,
        builder: (context, state) => const CounselorAvailabilityPage(),
      ),
      GoRoute(
        path: AppRoutes.counselorAppointments,
        name: AppRoutes.counselorAppointmentsName,
        builder: (context, state) => const CounselorAppointmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.bkMood,
        name: AppRoutes.bkMoodName,
        builder: (context, state) => const BkMoodPage(),
      ),
      GoRoute(
        path: AppRoutes.counselorMoodHistory,
        name: AppRoutes.counselorMoodHistoryName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CounselorMoodHistoryPage(conversationId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.bkPeerConcern,
        name: AppRoutes.bkPeerConcernName,
        builder: (context, state) => const BkPeerConcernPage(),
      ),
      GoRoute(
        path: AppRoutes.bkPeerConcernHistory,
        name: AppRoutes.bkPeerConcernHistoryName,
        builder: (context, state) => const BkPeerConcernHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.counselorPeerConcernQueue,
        name: AppRoutes.counselorPeerConcernQueueName,
        builder: (context, state) => const CounselorPeerConcernQueuePage(),
      ),
      GoRoute(
        path: AppRoutes.counselorPeerConcernDetail,
        name: AppRoutes.counselorPeerConcernDetailName,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CounselorPeerConcernDetailPage(concernId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: AppRoutes.notificationsName,
        builder: (context, state) => const NotificationsPage(),
      ),

      // App shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: AppRoutes.homeName,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                name: AppRoutes.exploreName,
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.create,
                name: AppRoutes.createName,
                builder: (context, state) => const CreatePostPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bk,
                name: AppRoutes.bkName,
                builder: (context, state) => const BkPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Converts a [Stream] into a [Listenable] for [GoRouter.refreshListenable].
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
