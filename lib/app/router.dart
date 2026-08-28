import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/counseling/presentation/pages/bk_page.dart';
import '../features/create_post/presentation/pages/create_post_page.dart';
import '../features/explore/presentation/pages/explore_page.dart';
import '../features/feed/presentation/pages/home_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import 'app_shell.dart';

/// Route paths and names. Keep string literals in one place only.
abstract final class AppRoutes {
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
}

/// App router. Auth redirects/guards are intentionally absent in M0 and will
/// be added in M1 Authentication.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
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
