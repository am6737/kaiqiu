// message.dart — 会话 + 消息
class Conversation {
  final String id;
  final String kind; // dm / group / team
  final String? title;
  final DateTime updatedAt;
  final int unread;

  const Conversation({
    required this.id,
    required this.kind,
    this.title,
    required this.updatedAt,
    this.unread = 0,
  });

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
        id: m['id'] as String,
        kind: (m['kind'] as String?) ?? 'dm',
        title: m['title'] as String?,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        unread: (m['unread'] as int?) ?? 0,
      );
}

class Message {
  final String id;
  final String convId;
  final String? senderId;
  final String? body;
  final String kind; // text / image / system
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.convId,
    this.senderId,
    this.body,
    this.kind = 'text',
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'] as String,
        convId: m['conv_id'] as String,
        senderId: m['sender_id'] as String?,
        body: m['body'] as String?,
        kind: (m['kind'] as String?) ?? 'text',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
