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
        scoreA: (m['score_a'] as int?) ?? 0,
        scoreB: (m['score_b'] as int?) ?? 0,
        myGoals: (m['my_goals'] as int?) ?? 0,
        myAssists: (m['my_assists'] as int?) ?? 0,
      );
}
