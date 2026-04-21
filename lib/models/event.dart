// event.dart — 赛事 + 比赛
enum EventStatus { registering, ongoing, done }

EventStatus _parseEventStatus(String? s) => switch (s) {
  'ongoing' => EventStatus.ongoing,
  'done' => EventStatus.done,
  _ => EventStatus.registering,
};

class Event {
  final String id;
  final String? creatorId;
  final String name;
  final String? sub;
  final String? city;
  final String? template;
  final int teamSize;
  final int? teamsMax;
  final int? prizeCents;
  final int? feeCents;
  final DateTime? deadline;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final EventStatus status;
  final String? coverUrl;

  const Event({
    required this.id,
    this.creatorId,
    required this.name,
    this.sub,
    this.city,
    this.template,
    this.teamSize = 11,
    this.teamsMax,
    this.prizeCents,
    this.feeCents,
    this.deadline,
    this.startsAt,
    this.endsAt,
    this.status = EventStatus.registering,
    this.coverUrl,
  });

  factory Event.fromMap(Map<String, dynamic> m) => Event(
    id: m['id'] as String,
    creatorId: m['creator_id'] as String?,
    name: m['name'] as String,
    sub: m['sub'] as String?,
    city: m['city'] as String?,
    template: m['template'] as String?,
    teamSize: (m['team_size'] as int?) ?? 11,
    teamsMax: m['teams_max'] as int?,
    prizeCents: m['prize_cents'] as int?,
    feeCents: m['fee_cents'] as int?,
    deadline: m['deadline'] != null ? DateTime.parse(m['deadline']) : null,
    startsAt: m['starts_at'] != null ? DateTime.parse(m['starts_at']) : null,
    endsAt: m['ends_at'] != null ? DateTime.parse(m['ends_at']) : null,
    status: _parseEventStatus(m['status'] as String?),
    coverUrl: m['cover_url'] as String?,
  );
}

class Match {
  final String id;
  final String eventId;
  final String? round;
  final String? teamAId;
  final String? teamBId;
  final String? teamALabel;
  final String? teamBLabel;
  final int? scoreA;
  final int? scoreB;
  final String? pkScore;
  final DateTime? playedAt;
  final bool done;

  const Match({
    required this.id,
    required this.eventId,
    this.round,
    this.teamAId,
    this.teamBId,
    this.teamALabel,
    this.teamBLabel,
    this.scoreA,
    this.scoreB,
    this.pkScore,
    this.playedAt,
    this.done = false,
  });

  factory Match.fromMap(Map<String, dynamic> m) => Match(
    id: m['id'] as String,
    eventId: m['event_id'] as String,
    round: m['round'] as String?,
    teamAId: m['team_a_id'] as String?,
    teamBId: m['team_b_id'] as String?,
    teamALabel: m['team_a_label'] as String?,
    teamBLabel: m['team_b_label'] as String?,
    scoreA: m['score_a'] as int?,
    scoreB: m['score_b'] as int?,
    pkScore: m['pk_score'] as String?,
    playedAt: m['played_at'] != null ? DateTime.parse(m['played_at']) : null,
    done: (m['done'] as bool?) ?? false,
  );
}

/// Which side of a match a player is on — derived heuristically from goals.
enum MatchSide { a, b }

/// Row returned by `event_player_ratings` view joined with profiles.
///
/// Match-scoped rows also carry per-match extras (goals / assists / top
/// highlight / top comment / team side) derived client-side.
class PlayerRatingRow {
  final String rateeId;
  final String name;
  final String? position;
  final double avgScore;
  final int votes;

  // Match-scoped extras. Null for event-wide rows.
  final int goals;
  final int assists;
  final String? topHighlight;
  final String? topComment;
  final MatchSide? side;

  const PlayerRatingRow({
    required this.rateeId,
    required this.name,
    this.position,
    required this.avgScore,
    required this.votes,
    this.goals = 0,
    this.assists = 0,
    this.topHighlight,
    this.topComment,
    this.side,
  });

  factory PlayerRatingRow.fromMap(Map<String, dynamic> m) {
    final ratee = (m['ratee'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlayerRatingRow(
      rateeId: (ratee['id'] as String?) ?? (m['ratee_id'] as String? ?? ''),
      name: (ratee['name'] as String?) ?? '—',
      position: ratee['position'] as String?,
      avgScore: (m['avg_score'] as num).toDouble(),
      votes: (m['votes'] as num).toInt(),
    );
  }

  PlayerRatingRow copyWith({
    int? goals,
    int? assists,
    String? topHighlight,
    String? topComment,
    MatchSide? side,
  }) => PlayerRatingRow(
    rateeId: rateeId,
    name: name,
    position: position,
    avgScore: avgScore,
    votes: votes,
    goals: goals ?? this.goals,
    assists: assists ?? this.assists,
    topHighlight: topHighlight ?? this.topHighlight,
    topComment: topComment ?? this.topComment,
    side: side ?? this.side,
  );
}
