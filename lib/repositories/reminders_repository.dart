// reminders_repository.dart — 比赛提醒（给 S4 推送使用）
import '../services/local_storage.dart';
import '../services/supabase.dart';

class MatchReminder {
  final String id;
  final String userId;
  final String matchId;
  final DateTime remindAt;
  final DateTime? sentAt;

  MatchReminder({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.remindAt,
    this.sentAt,
  });

  factory MatchReminder.fromMap(Map<String, dynamic> m) => MatchReminder(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    matchId: m['match_id'] as String,
    remindAt: DateTime.parse(m['remind_at'] as String).toLocal(),
    sentAt: (m['sent_at'] as String?) != null
        ? DateTime.parse(m['sent_at'] as String).toLocal()
        : null,
  );
}

class RemindersRepository {
  /// Upsert a reminder. Mirrors to LocalStore.
  Future<void> schedule({
    required String matchId,
    required DateTime remindAt,
  }) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        await supabase.from('match_reminders').upsert({
          'user_id': uid,
          'match_id': matchId,
          'remind_at': remindAt.toUtc().toIso8601String(),
          // sent_at reset to null so pg_cron picks it up again.
          'sent_at': null,
        }, onConflict: 'user_id,match_id');
      } catch (_) {
        // fall through
      }
    }
    if (!LocalStore.hasReminder(matchId)) {
      await LocalStore.toggleReminder(matchId);
    }
  }

  Future<void> cancel(String matchId) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        await supabase
            .from('match_reminders')
            .delete()
            .eq('user_id', uid)
            .eq('match_id', matchId);
      } catch (_) {
        // ignore; keep local
      }
    }
    if (LocalStore.hasReminder(matchId)) {
      await LocalStore.toggleReminder(matchId);
    }
  }

  Future<bool> isSet(String matchId) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        final row = await supabase
            .from('match_reminders')
            .select('id')
            .eq('user_id', uid)
            .eq('match_id', matchId)
            .maybeSingle();
        if (row != null) return true;
      } catch (_) {
        // fall through
      }
    }
    return LocalStore.hasReminder(matchId);
  }

  Future<List<MatchReminder>> listMine() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final rows = await supabase
          .from('match_reminders')
          .select()
          .eq('user_id', uid)
          .order('remind_at', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(MatchReminder.fromMap)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
