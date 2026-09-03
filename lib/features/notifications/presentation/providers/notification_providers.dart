import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../data/notification_repository.dart';
import '../../data/models/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    return ref
        .watch(notificationRepositoryProvider)
        .fetchMyNotifications(limit: 50, offset: 0);
  },
);

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(notificationRepositoryProvider).fetchUnreadCount();
});

class NotificationController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> markRead(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
    }
  }

  Future<void> markAllRead() async {
    state = const AsyncLoading();
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
    }
  }

  Future<void> refresh() async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, AsyncValue<void>>(
      NotificationController.new,
    );
