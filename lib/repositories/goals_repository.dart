// goals_repository.dart — 进球事件 + 赛事射手榜
import '../services/supabase.dart';

class GoalEvent {
  final String id;
  final String matchId;
  final String? scorerId;
  final String? scorerName;
  final String? assistId;
  final int? minute;
  final bool isOwnGoal;
  final bool isPenalty;

  GoalEvent({
    required this.id,
    required this.matchId,
    this.scorerId,
    this.scorerName,
    this.assistId,
    this.minute,
    required this.isOwnGoal,
    required this.isPenalty,
  });

  factory GoalEvent.fromMap(Map<String, dynamic> m) => GoalEvent(
    id: m['id'] as String,
    matchId: m['match_id'] as String,
    scorerId: m['scorer_id'] as String?,
    scorerName: m['scorer_name'] as String?,
    assistId: m['assist_id'] as String?,
    minute: m['minute'] as int?,
    isOwnGoal: (m['is_own_goal'] as bool?) ?? false,
    isPenalty: (m['is_penalty'] as bool?) ?? false,
  );
}

class ScorerRow {
  final String eventId;
  final String? scorerId;
  final String name;
  final int goals;
  final int matches;

  ScorerRow({
    required this.eventId,
    this.scorerId,
    required this.name,
    required this.goals,
    required this.matches,
  });

  factory ScorerRow.fromMap(Map<String, dynamic> m) => ScorerRow(
    eventId: m['event_id'] as String,
    scorerId: m['scorer_id'] as String?,
    name: (m['name'] as String?) ?? '—',
    goals: (m['goals'] as num?)?.toInt() ?? 0,
    matches: (m['matches'] as num?)?.toInt() ?? 0,
  );
}

class GoalsRepository {
  /// All goals for a single match, ordered by minute.
  Future<List<GoalEvent>> listForMatch(String matchId) async {
    final rows = await supabase
        .from('goals')
        .select()
        .eq('match_id', matchId)
        .order('minute', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GoalEvent.fromMap)
        .toList();
  }

  /// All goals for an event (joins via matches).
  Future<List<GoalEvent>> listForEvent(String eventId) async {
    final rows = await supabase
        .from('goals')
        .select('*, matches!inner(event_id)')
        .eq('matches.event_id', eventId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GoalEvent.fromMap)
        .toList();
  }

  /// Scorer leaderboard view for an event.
  Future<List<ScorerRow>> scorersForEvent(String eventId) async {
    final rows = await supabase
        .from('event_scorers')
        .select()
        .eq('event_id', eventId)
        .order('goals', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ScorerRow.fromMap)
        .toList();
  }

  Future<void> add({
    required String matchId,
    String? scorerId,
    String? scorerName,
    String? assistId,
    int? minute,
    bool isOwnGoal = false,
    bool isPenalty = false,
  }) async {
    await supabase.from('goals').insert({
      'match_id': matchId,
      'scorer_id': ?scorerId,
      'scorer_name': ?scorerName,
      'assist_id': ?assistId,
      'minute': ?minute,
      'is_own_goal': isOwnGoal,
      'is_penalty': isPenalty,
    });
  }
}
