import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_item.dart';
import '../services/supabase.dart';

class NotificationsRepository {
  Future<List<NotificationItem>> listMine() async {
    final uid = currentUserId;
    if (uid == null) return [];
    final rows = await supabase
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(NotificationItem.fromMap)
        .toList();
  }

  Stream<List<NotificationItem>> streamMine() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    final controller = StreamController<List<NotificationItem>>();
    late final RealtimeChannel channel;

    Future<void> refresh() async {
      try {
        final list = await listMine();
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    Future<void> init() async {
      await refresh();
      channel = supabase
          .channel('notifications_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (_) => refresh(),
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

  Future<void> markRead(String id) async {
    await supabase.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    final uid = currentUserId;
    if (uid == null) return;
    await supabase
        .from('notifications')
        .update({'read': true})
        .eq('user_id', uid)
        .eq('read', false);
  }

  Future<int> unreadCount() async {
    final uid = currentUserId;
    if (uid == null) return 0;
    final rows = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('read', false);
    return (rows as List).length;
  }
}
