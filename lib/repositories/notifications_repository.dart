import '../models/notification_item.dart';
import '../services/supabase.dart';

class NotificationsRepository {
  bool _seeded = false;

  Future<void> _ensureDemoData() async {
    if (_seeded || currentUserId == null) return;
    _seeded = true;
    try {
      await supabase.rpc('seed_demo_inbox');
    } catch (_) {}
  }

  Future<List<NotificationItem>> listMine() async {
    final uid = currentUserId;
    if (uid == null) return [];
    await _ensureDemoData();
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
