class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.route,
    required this.isRead,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    return AppNotification(
      id: m['notification_id'] as String? ?? m['id'] as String,
      type: m['type'] as String,
      title: m['title'] as String,
      body: m['body'] as String,
      route: m['route'] as String?,
      isRead: m['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(m['created_at'] as String),
      readAt: m['read_at'] != null ? DateTime.parse(m['read_at'] as String) : null,
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final String? route;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
}
