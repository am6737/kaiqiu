// live_match.dart — Live match from Supabase matches table.

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class LiveMatch {
  final String id;
  final String eventId;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final int minute;
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

  String get minuteDisplay => "$minute'";

  String get viewersDisplay {
    if (viewers >= 1000) return '${(viewers / 1000).toStringAsFixed(0)}K';
    return '$viewers';
  }

  factory LiveMatch.fromMap(Map<String, dynamic> m) => LiveMatch(
    id: m['id'] as String,
    eventId: m['event_id'] as String,
    teamA: (m['team_a_label'] as String?) ?? '队伍A',
    teamB: (m['team_b_label'] as String?) ?? '队伍B',
    scoreA: _toInt(m['score_a']) ?? 0,
    scoreB: _toInt(m['score_b']) ?? 0,
    minute: _toInt(m['minute']) ?? 0,
    viewers: _toInt(m['viewers']) ?? 0,
    posterUrl: m['poster_url'] as String?,
  );
}
