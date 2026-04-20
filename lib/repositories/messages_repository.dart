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

  static ConversationRow? fromJoined(Map<String, dynamic> m) {
    final conv = (m['conversations'] as Map?)?.cast<String, dynamic>();
    if (conv == null) return null;
    final updatedAtStr = conv['updated_at'] as String?;
    if (updatedAtStr == null) return null;
    return ConversationRow(
      id: conv['id'] as String,
      title: conv['title'] as String?,
      kind: (conv['kind'] as String?) ?? 'dm',
      updatedAt: DateTime.parse(updatedAtStr),
      unread: (m['unread'] as int?) ?? 0,
    );
  }
}

class MessagesRepository {
  /// Conversations the current user belongs to. Sorted by most recent.
  Future<List<ConversationRow>> listConversations() async {
    final rows = await supabase
        .from('conversation_members')
        .select('unread, conversations!inner(id, title, kind, updated_at)')
        .eq('user_id', currentUserId!)
        .order(
          'updated_at',
          referencedTable: 'conversations',
          ascending: false,
        );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ConversationRow.fromJoined)
        .whereType<ConversationRow>()
        .toList();
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
        .insert({'conv_id': convId, 'sender_id': currentUserId, 'body': body})
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

  /// Create a new conversation and add the current user as a member.
  /// Returns the new conversation id.
  Future<String> createConversation({
    String? title,
    String kind = 'group',
  }) async {
    final row = await supabase
        .from('conversations')
        .insert({'title': title, 'kind': kind})
        .select()
        .single();
    final id = row['id'] as String;
    final uid = currentUserId;
    if (uid != null) {
      await supabase.from('conversation_members').insert({
        'conv_id': id,
        'user_id': uid,
        'unread': 0,
      });
    }
    return id;
  }

  Future<void> deleteConversation(String convId) async {
    await supabase.from('messages').delete().eq('conv_id', convId);
    await supabase.from('conversation_members').delete().eq('conv_id', convId);
    await supabase.from('conversations').delete().eq('id', convId);
  }

  Future<void> clearMessages(String convId) async {
    await supabase.from('messages').delete().eq('conv_id', convId);
  }

  Future<void> markRead(String convId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await supabase
        .from('conversation_members')
        .update({'unread': 0})
        .eq('conv_id', convId)
        .eq('user_id', uid);
  }

  Future<void> markUnread(String convId, {int count = 1}) async {
    final uid = currentUserId;
    if (uid == null) return;
    await supabase
        .from('conversation_members')
        .update({'unread': count})
        .eq('conv_id', convId)
        .eq('user_id', uid);
  }

  /// Returns (or creates) a conversation keyed by an event id so multiple
  /// users can join the event discussion. Title format: `event:{id}`.
  Future<String> ensureEventConversation(String eventId) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('not signed in');
    }
    final title = 'event:$eventId';
    final existing = await supabase
        .from('conversations')
        .select('id')
        .eq('title', title)
        .maybeSingle();
    String convId;
    if (existing != null) {
      convId = existing['id'] as String;
    } else {
      final row = await supabase
          .from('conversations')
          .insert({'title': title, 'kind': 'group'})
          .select()
          .single();
      convId = row['id'] as String;
    }
    // Ensure membership (upsert-like)
    final member = await supabase
        .from('conversation_members')
        .select('id')
        .eq('conv_id', convId)
        .eq('user_id', uid)
        .maybeSingle();
    if (member == null) {
      await supabase.from('conversation_members').insert({
        'conv_id': convId,
        'user_id': uid,
        'unread': 0,
      });
    }
    return convId;
  }
}
