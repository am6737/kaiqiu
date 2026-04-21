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
  /// Delegates to the `ensure_event_conversation` RPC which handles the
  /// find-or-create + membership atomically under SECURITY DEFINER.
  Future<String> ensureEventConversation(String eventId) async {
    if (currentUserId == null) {
      throw StateError('not signed in');
    }
    final convId = await supabase.rpc(
      'ensure_event_conversation',
      params: {'p_event_id': eventId},
    );
    return convId as String;
  }

  /// Idempotently find-or-create a 1v1 DM conversation with [otherUserId].
  /// Returns the conversation id. Atomic on the server via RPC.
  Future<String> ensureDmWith(String otherUserId) async {
    if (currentUserId == null) {
      throw StateError('not signed in');
    }
    final convId = await supabase.rpc(
      'ensure_dm_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    return convId as String;
  }

  /// For a DM conversation, return the OTHER member's user_id
  /// (the peer, i.e. not the current user). Returns null if convId
  /// is not a DM or the current user is not signed in.
  Future<String?> fetchDmPeerId(String convId) async {
    final me = currentUserId;
    if (me == null) return null;
    final row = await supabase
        .from('v_conversation_peers')
        .select('peer_user_id')
        .eq('conv_id', convId)
        .neq('peer_user_id', me)
        .maybeSingle();
    if (row == null) return null;
    return row['peer_user_id'] as String?;
  }
}
