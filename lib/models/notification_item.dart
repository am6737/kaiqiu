class NotificationItem {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? icon;
  final String? route;
  final bool read;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.icon,
    this.route,
    this.read = false,
    required this.createdAt,
  });

  String get group => type;

  factory NotificationItem.fromMap(Map<String, dynamic> m) => NotificationItem(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    type: m['type'] as String? ?? 'system',
    title: m['title'] as String,
    body: m['body'] as String,
    icon: m['icon'] as String?,
    route: m['route'] as String?,
    read: (m['read'] as bool?) ?? false,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}
