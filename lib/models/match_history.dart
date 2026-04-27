int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class MatchHistoryEntry {
  final String matchId;
  final DateTime playedAt;
  final String eventName;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final int myGoals;
  final int myAssists;

  const MatchHistoryEntry({
    required this.matchId,
    required this.playedAt,
    required this.eventName,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.myGoals,
    required this.myAssists,
  });

  String get score => '$scoreA - $scoreB';

  factory MatchHistoryEntry.fromMap(Map<String, dynamic> m) =>
      MatchHistoryEntry(
        matchId: m['match_id'] as String,
        playedAt: DateTime.parse(m['played_at'] as String),
        eventName: (m['event_name'] as String?) ?? '',
        teamA: (m['team_a'] as String?) ?? '',
        teamB: (m['team_b'] as String?) ?? '',
        scoreA: _toInt(m['score_a']) ?? 0,
        scoreB: _toInt(m['score_b']) ?? 0,
        myGoals: _toInt(m['my_goals']) ?? 0,
        myAssists: _toInt(m['my_assists']) ?? 0,
      );
}
