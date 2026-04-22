import 'package:intl/intl.dart';

class Comment {
  final String id;
  final String targetType;
  final String targetId;
  final String? authorId;
  final String authorName;
  final String body;
  final int likes;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.authorId,
    required this.authorName,
    required this.body,
    this.likes = 0,
    required this.createdAt,
  });

  String get displayTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM-dd').format(createdAt);
  }

  factory Comment.fromMap(Map<String, dynamic> m) => Comment(
        id: m['id'] as String,
        targetType: m['target_type'] as String,
        targetId: m['target_id'] as String,
        authorId: m['author_id'] as String?,
        authorName: m['author_name'] as String? ?? '匿名球友',
        body: m['body'] as String,
        likes: (m['likes'] as int?) ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
