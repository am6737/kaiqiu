int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class ExternalMatch {
  final String id;
  final String teamA;
  final String teamB;
  final String? flagA;
  final String? flagB;
  final String? competition;
  final DateTime? kickOff;
  final bool isLive;
  final int? scoreA;
  final int? scoreB;
  final String? minute;
  final String? status;
  final int viewers;

  const ExternalMatch({
    required this.id,
    required this.teamA,
    required this.teamB,
    this.flagA,
    this.flagB,
    this.competition,
    this.kickOff,
    this.isLive = false,
    this.scoreA,
    this.scoreB,
    this.minute,
    this.status,
    this.viewers = 0,
  });

  String get time {
    if (kickOff == null) return '';
    final d = kickOff!;
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  factory ExternalMatch.fromMap(Map<String, dynamic> m) => ExternalMatch(
    id: m['id'] as String,
    teamA: m['team_a'] as String,
    teamB: m['team_b'] as String,
    flagA: m['flag_a'] as String?,
    flagB: m['flag_b'] as String?,
    competition: m['competition'] as String?,
    kickOff: m['kick_off'] != null
        ? DateTime.parse(m['kick_off'] as String)
        : null,
    isLive: (m['is_live'] as bool?) ?? false,
    scoreA: _toInt(m['score_a']),
    scoreB: _toInt(m['score_b']),
    minute: m['minute'] as String?,
    status: m['status'] as String?,
    viewers: (m['viewers'] as num?)?.toInt() ?? 0,
  );
}
