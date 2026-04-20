// rating.dart — 虎扑式评分
class Rating {
  final String id;
  final String matchId;
  final String raterId;
  final String rateeId;
  final double score; // 0.0 - 10.0, step 0.5
  final String? comment;
  final String? highlight;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.matchId,
    required this.raterId,
    required this.rateeId,
    required this.score,
    this.comment,
    this.highlight,
    required this.createdAt,
  });

  factory Rating.fromMap(Map<String, dynamic> m) => Rating(
        id: m['id'] as String,
        matchId: m['match_id'] as String,
        raterId: m['rater_id'] as String,
        rateeId: m['ratee_id'] as String,
        score: (m['score'] as num).toDouble(),
        comment: m['comment'] as String?,
        highlight: m['highlight'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'match_id': matchId,
        'rater_id': raterId,
        'ratee_id': rateeId,
        'score': score,
        'comment': comment,
        'highlight': highlight,
      };
}

/// Aggregate view for leaderboards.
class PlayerRatingSummary {
  final String rateeId;
  final double avgScore;
  final int votes;

  const PlayerRatingSummary({
    required this.rateeId,
    required this.avgScore,
    required this.votes,
  });

  factory PlayerRatingSummary.fromMap(Map<String, dynamic> m) =>
      PlayerRatingSummary(
        rateeId: m['ratee_id'] as String,
        avgScore: (m['avg_score'] as num).toDouble(),
        votes: m['votes'] as int,
      );
}
