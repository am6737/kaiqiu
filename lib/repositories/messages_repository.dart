// messages_repository.dart — conversations + messages + Realtime

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../services/supabase.dart';

class ConversationRow {
  final String id;
  final String? title;
  final String kind;
  final DateTime updatedAt;
  final int unread;

  const ConversationRow({
    required this.id,
    this.title,
    required this.kind,
    required this.updatedAt,
    this.unread = 0,
  });

  factory ConversationRow.fromJoined(Map<String, dynamic> m) {
    final conv = m['conversations'] as Map<String, dynamic>;
    return ConversationRow(
      id: conv['id'] as String,
      title: conv['title'] as String?,
      kind: (conv['kind'] as String?) ?? 'dm',
      updatedAt: DateTime.parse(conv['updated_at'] as String),
      unread: (m['unread'] as int?) ?? 0,
    );
  }
}

class MessagesRepository {
  /// Conversations the current user belongs to. Sorted by most recent.
  Future<List<ConversationRow>> listConversations() async {
    final rows = await supabase
        .from('conversation_members')
        .select('unread, conversations(id, title, kind, updated_at)')
        .eq('user_id', currentUserId!)
        .order('updated_at',
            referencedTable: 'conversations', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ConversationRow.fromJoined)
        .toList();
  }

  /// Bootstrap: creates a demo conversation if the caller has none, returns its id.
  Future<String> ensureDemoConversation() async {
    final id = await supabase.rpc('ensure_demo_conversation') as String;
    return id;
  }

  /// Initial fetch of a conversation's messages (oldest first).
  Future<List<Message>> listMessages(String convId) async {
    final rows = await supabase
        .from('messages')
        .select()
        .eq('conv_id', convId)
        .order('created_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Message.fromMap)
        .toList();
  }

  /// Insert a text message. Returns the new row.
  Future<Message> send(String convId, String body) async {
    final row = await supabase
        .from('messages')
        .insert({
          'conv_id': convId,
          'sender_id': currentUserId,
          'body': body,
        })
        .select()
        .single();
    return Message.fromMap(row);
  }

  /// Stream of the full messages list for [convId], live-updated via Realtime.
  /// Yields an initial fetch then re-yields whenever new rows arrive.
  Stream<List<Message>> streamMessages(String convId) {
    final controller = StreamController<List<Message>>();
    var current = <Message>[];
    late final RealtimeChannel channel;

    Future<void> init() async {
      current = await listMessages(convId);
      controller.add(List.unmodifiable(current));

      channel = supabase
          .channel('messages:$convId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conv_id',
              value: convId,
            ),
            callback: (payload) {
              final m = Message.fromMap(payload.newRecord);
              // De-dupe: if already present (we just sent it), skip.
              if (current.any((x) => x.id == m.id)) return;
              current = [...current, m];
              controller.add(List.unmodifiable(current));
            },
          )
          .subscribe();
    }

    controller.onListen = init;
    controller.onCancel = () async {
      await supabase.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }
}
