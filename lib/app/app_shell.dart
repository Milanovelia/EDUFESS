import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/notifications/presentation/providers/notification_providers.dart';

/// Bottom navigation shell holding the five top-level Edufess destinations.
///
/// Each destination is a separate `StatefulShellBranch`, so tab state and
/// scroll position survive tab switches.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab returns to that branch's first route.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.maybeWhen(data: (c) => c, orElse: () => 0);
    final theme = Theme.of(context);
    final selected = theme.colorScheme.primary;
    final unselected = theme.colorScheme.onSurfaceVariant;
    NavigationDestination destination({
      required IconData icon,
      required IconData selectedIcon,
      required String label,
    }) {
      return NavigationDestination(
        icon: Icon(icon, color: unselected),
        selectedIcon: Icon(selectedIcon, color: selected),
        label: label,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EduFess',
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: selected,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifikasi',
                onPressed: () => context.push('/notifications'),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selected,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: theme.navigationBarTheme.copyWith(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return theme.textTheme.labelSmall?.copyWith(
              color: isSelected ? selected : unselected,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            destination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
            destination(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Explore'),
            destination(icon: Icons.add_circle_outline, selectedIcon: Icons.add_circle, label: 'Create'),
            destination(icon: Icons.support_agent_outlined, selectedIcon: Icons.support_agent, label: 'BK'),
            destination(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
