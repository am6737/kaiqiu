// rating.dart — 虎扑式评分
class Rating {
  final String id;
  final String matchId;
  final String raterId;
  final String rateeId;
  final double score; // 0.0 - 10.0, step 0.5
  final String? comment;
  final String? highlight;
  final int likes;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.matchId,
    required this.raterId,
    required this.rateeId,
    required this.score,
    this.comment,
    this.highlight,
    this.likes = 0,
    required this.createdAt,
  });

  factory Rating.fromMap(Map<String, dynamic> m) {
    int likesCount = 0;
    final rl = m['rating_likes'];
    if (rl is List && rl.isNotEmpty) {
      final first = rl.first;
      if (first is Map && first.containsKey('count')) {
        likesCount = (first['count'] as num).toInt();
      } else {
        likesCount = rl.length;
      }
    }
    return Rating(
      id: m['id'] as String,
      matchId: m['match_id'] as String,
      raterId: m['rater_id'] as String,
      rateeId: m['ratee_id'] as String,
      score: (m['score'] as num).toDouble(),
      comment: m['comment'] as String?,
      highlight: m['highlight'] as String?,
      likes: likesCount,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'match_id': matchId,
    'rater_id': raterId,
    'ratee_id': rateeId,
    'score': score,
    'comment': comment,
    'highlight': highlight,
  };
}

/// A participant in a match (for the rating screen player list).
class MatchParticipant {
  final String id;
  final String matchId;
  final String displayName;
  final String side; // 'a' or 'b'
  final String? userId;
  final String? position;

  const MatchParticipant({
    required this.id,
    required this.matchId,
    required this.displayName,
    required this.side,
    this.userId,
    this.position,
  });

  factory MatchParticipant.fromMap(Map<String, dynamic> m) {
    final profile = m['profile'] as Map<String, dynamic>?;
    return MatchParticipant(
      id: m['id'] as String,
      matchId: m['match_id'] as String,
      displayName: (profile?['name'] as String?) ??
          (m['display_name'] as String?) ??
          '球员',
      side: (m['side'] as String?) ?? 'a',
      userId: m['user_id'] as String?,
      position: (profile?['position'] as String?) ??
          (m['position'] as String?),
    );
  }
}

/// A rating comment for the match ratings screen.
class RatingComment {
  final String ratingId;
  final String user;
  final String text;
  final double score;
  final int likes;
  final DateTime createdAt;

  const RatingComment({
    required this.ratingId,
    required this.user,
    required this.text,
    required this.score,
    this.likes = 0,
    required this.createdAt,
  });
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
