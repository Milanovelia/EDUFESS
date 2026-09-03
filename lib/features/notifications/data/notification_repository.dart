import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  Future<List<AppNotification>> fetchMyNotifications({int limit = 20, int offset = 0}) async {
    final data = await _client.rpc('get_my_notifications', params: {'p_limit': limit, 'p_offset': offset});
    final list = data as List;
    return list.map((e) => AppNotification.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<int> fetchUnreadCount() async {
    final data = await _client.rpc('get_my_notification_unread_count');
    return (data as int);
  }

  Future<void> markRead(String notificationId) async {
    await _client.rpc('mark_notification_read', params: {'p_notification_id': notificationId});
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }
}
