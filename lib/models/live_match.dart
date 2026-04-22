// live_match.dart — Live match from Supabase matches table.

class LiveMatch {
  final String id;
  final String eventId;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final String minute;
  final int viewers;
  final String? posterUrl;

  const LiveMatch({
    required this.id,
    required this.eventId,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.minute,
    required this.viewers,
    this.posterUrl,
  });

  String get viewersDisplay {
    if (viewers >= 1000) return '${(viewers / 1000).toStringAsFixed(0)}K';
    return '$viewers';
  }

  factory LiveMatch.fromMap(Map<String, dynamic> m) => LiveMatch(
    id: m['id'] as String,
    eventId: m['event_id'] as String,
    teamA: (m['team_a_label'] as String?) ?? '队伍A',
    teamB: (m['team_b_label'] as String?) ?? '队伍B',
    scoreA: (m['score_a'] as int?) ?? 0,
    scoreB: (m['score_b'] as int?) ?? 0,
    minute: (m['minute'] as String?) ?? '',
    viewers: (m['viewers'] as int?) ?? 0,
    posterUrl: m['poster_url'] as String?,
  );
}
