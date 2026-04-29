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
  final String? lastMessageBody;

  const ConversationRow({
    required this.id,
    this.title,
    required this.kind,
    required this.updatedAt,
    this.unread = 0,
    this.lastMessageBody,
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
      lastMessageBody: conv['last_message_body'] as String?,
    );
  }
}

class MessagesRepository {
  final _conversationRefreshTrigger = StreamController<void>.broadcast();

  void refreshConversations() => _conversationRefreshTrigger.add(null);

  /// Conversations the current user belongs to. Sorted by most recent.
  Future<List<ConversationRow>> listConversations() async {
    final rows = await supabase
        .from('conversation_members')
        .select('unread, conversations!inner(id, title, kind, last_message_body, updated_at)')
        .eq('user_id', currentUserId!)
        .order(
          'updated_at',
          referencedTable: 'conversations',
          ascending: false,
        );
    const hiddenTitles = {'球局 · 新手大厅', '系统通知'};
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ConversationRow.fromJoined)
        .whereType<ConversationRow>()
        .where((c) =>
            !hiddenTitles.contains(c.title) &&
            !(c.title?.startsWith('event:') ?? false))
        .toList();
  }

  /// Live stream of conversations, auto-refreshes on new messages via Realtime.
  Stream<List<ConversationRow>> streamConversations() {
    final controller = StreamController<List<ConversationRow>>();
    late final RealtimeChannel channel;

    Future<void> refresh() async {
      try {
        final list = await listConversations();
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    late final StreamSubscription<void> triggerSub;

    Future<void> init() async {
      await refresh();
      triggerSub = _conversationRefreshTrigger.stream.listen((_) => refresh());
      channel = supabase
          .channel('conversations_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'conversation_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: currentUserId!,
            ),
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'conversation_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: currentUserId!,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    }

    controller.onListen = init;
    controller.onCancel = () async {
      triggerSub.cancel();
      await supabase.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
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

  /// Insert a message. Returns the new row.
  Future<Message> send(String convId, String body, {String kind = 'text'}) async {
    final row = await supabase
        .from('messages')
        .insert({
          'conv_id': convId,
          'sender_id': currentUserId,
          'body': body,
          'kind': kind,
        })
        .select()
        .single();
    return Message.fromMap(row);
  }

  /// Global stream that emits every new message across all conversations.
  /// Used for in-app notifications and unread badge refresh.
  Stream<Message> streamGlobalNewMessages() {
    final controller = StreamController<Message>();
    late final RealtimeChannel channel;

    void init() {
      channel = supabase
          .channel('global_new_messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final m = Message.fromMap(payload.newRecord);
              if (m.senderId != currentUserId) {
                controller.add(m);
              }
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
