// ratings_repository.dart
import '../models/rating.dart';
import '../services/supabase.dart';

class RatingsRepository {
  /// Submit or update a single rating (upsert on unique match+rater+ratee key).
  Future<Rating> submit({
    required String matchId,
    required String raterId,
    required String rateeId,
    required double score,
    String? comment,
    String? highlight,
  }) async {
    final row = await supabase
        .from('ratings')
        .upsert({
          'match_id': matchId,
          'rater_id': raterId,
          'ratee_id': rateeId,
          'score': score,
          'comment': comment,
          'highlight': highlight,
        }, onConflict: 'match_id,rater_id,ratee_id')
        .select()
        .single();
    return Rating.fromMap(row);
  }

  /// Event-level leaderboard.
  Future<List<PlayerRatingSummary>> eventLeaderboard(String eventId) async {
    final rows = await supabase
        .from('event_player_ratings')
        .select()
        .eq('event_id', eventId)
        .order('avg_score', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PlayerRatingSummary.fromMap)
        .toList();
  }

  /// All-time summary for one player.
  Future<PlayerRatingSummary?> playerSummary(String userId) async {
    final rows = await supabase
        .from('player_rating_summary')
        .select()
        .eq('ratee_id', userId)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    return list.isEmpty ? null : PlayerRatingSummary.fromMap(list.first);
  }

  /// Ratings cast on a specific player in a specific match (for histogram/comments).
  Future<List<Rating>> forPlayerInMatch({
    required String matchId,
    required String rateeId,
  }) async {
    final rows = await supabase
        .from('ratings')
        .select('*, rating_likes(count)')
        .eq('match_id', matchId)
        .eq('ratee_id', rateeId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Rating.fromMap)
        .toList();
  }

  /// Set of rating IDs the current user has liked within a match.
  Future<Set<String>> likedRatingIds(String matchId) async {
    final uid = currentUserId;
    if (uid == null) return {};
    final rows = await supabase
        .from('rating_likes')
        .select('rating_id, ratings!inner(match_id)')
        .eq('user_id', uid)
        .eq('ratings.match_id', matchId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['rating_id'] as String)
        .toSet();
  }

  /// Players participating in a match (for the rating submission screen).
  Future<List<MatchParticipant>> matchParticipants(String matchId) async {
    final rows = await supabase
        .from('match_participants')
        .select('*, profile:profiles!user_id(name, position)')
        .eq('match_id', matchId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MatchParticipant.fromMap)
        .toList();
  }

  /// Score distribution for a match: a list of 11 ints (index 0..10).
  Future<List<int>> scoreDistribution(String matchId) async {
    final rows = await supabase
        .from('ratings')
        .select('score')
        .eq('match_id', matchId);
    final dist = List<int>.filled(11, 0);
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final s = ((r['score'] as num).toDouble()).round().clamp(0, 10);
      dist[s]++;
    }
    return dist;
  }

  /// Top comments for a match (most recent, with rater profile info).
  Future<List<RatingComment>> topComments(
    String matchId, {
    int limit = 20,
  }) async {
    final rows = await supabase
        .from('ratings')
        .select('id, score, comment, created_at, rater:profiles!rater_id(name)')
        .eq('match_id', matchId)
        .neq('comment', '')
        .order('created_at', ascending: false)
        .limit(limit);
    final comments = <RatingComment>[];
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      final ratingId = r['id'] as String;
      final rater = r['rater'] as Map<String, dynamic>?;
      final likesRows = await supabase
          .from('rating_likes')
          .select('rating_id')
          .eq('rating_id', ratingId);
      comments.add(RatingComment(
        ratingId: ratingId,
        user: (rater?['name'] as String?) ?? '匿名',
        text: r['comment'] as String,
        score: (r['score'] as num).toDouble(),
        likes: (likesRows as List).length,
        createdAt: DateTime.parse(r['created_at'] as String),
      ));
    }
    return comments;
  }

  Future<void> toggleLike(String ratingId) async {
    final uid = currentUserId;
    if (uid == null) return;
    final existing = await supabase
        .from('rating_likes')
        .select('rating_id')
        .eq('rating_id', ratingId)
        .eq('user_id', uid)
        .maybeSingle();
    if (existing != null) {
      await supabase
          .from('rating_likes')
          .delete()
          .eq('rating_id', ratingId)
          .eq('user_id', uid);
    } else {
      await supabase
          .from('rating_likes')
          .insert({'rating_id': ratingId, 'user_id': uid});
    }
  }
}
