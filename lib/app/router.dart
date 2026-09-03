import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/counseling/presentation/pages/bk_appointments_page.dart';
import '../features/counseling/presentation/pages/bk_page.dart';
import '../features/counseling/presentation/pages/bk_conversation_page.dart';
import '../features/counseling/presentation/pages/counselor_appointments_page.dart';
import '../features/counseling/presentation/pages/counselor_availability_page.dart';
import '../features/create_post/presentation/pages/create_post_page.dart';
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
}

/// Whether the given [location] is an auth route (login or register).
bool _isAuthRoute(String location) =>
    location == AppRoutes.login || location == AppRoutes.register;

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
      final session = ref.read(currentSessionProvider);
      final isLoggedIn = session.hasValue && session.value != null;
      final location = state.matchedLocation;

      // Authenticated user on auth page → redirect to home
      if (isLoggedIn && _isAuthRoute(location)) {
        return AppRoutes.home;
      }

      // Unauthenticated user on app page → redirect to login
      if (!isLoggedIn && !_isAuthRoute(location)) {
        return AppRoutes.login;
      }

      return null; // No redirect
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
