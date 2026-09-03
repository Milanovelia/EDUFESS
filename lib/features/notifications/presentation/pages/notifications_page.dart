import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadAsync = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          unreadAsync.maybeWhen(
            data: (count) => count > 0
                ? TextButton(
                    onPressed: () async {
                      await ref.read(notificationControllerProvider.notifier).markAllRead();
                    },
                    child: const Text('Tandai semua dibaca'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
          await ref.read(notificationsProvider.future);
        },
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Gagal memuat notifikasi: ${e.toString().replaceAll('Exception: ', '')}', textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(onPressed: () => ref.invalidate(notificationsProvider), child: const Text('Coba lagi')),
                ],
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.notifications_none, size: 48),
                  SizedBox(height: AppSpacing.md),
                  Center(child: Text('Belum ada notifikasi.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (c, i) {
                final n = list[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  color: n.isRead ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: ListTile(
                    leading: Icon(n.isRead ? Icons.notifications_none : Icons.notifications, color: n.isRead ? Colors.grey : Theme.of(context).colorScheme.primary),
                    title: Text(n.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(_timeAgo(n.createdAt), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                    trailing: n.isRead ? null : Container(width: 8, height: 8, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
                    onTap: () async {
                      if (!n.isRead) {
                        await ref.read(notificationControllerProvider.notifier).markRead(n.id);
                      }
                      if (n.route != null && n.route!.isNotEmpty && context.mounted) {
                        context.push(n.route!);
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
