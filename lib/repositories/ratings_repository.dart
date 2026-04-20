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
        .select()
        .eq('match_id', matchId)
        .eq('ratee_id', rateeId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Rating.fromMap)
        .toList();
  }
}
