// predictions_repository.dart — 世界杯/赛事竞猜
import '../services/local_storage.dart';
import '../services/supabase.dart';

class Prediction {
  final String id;
  final String userId;
  final String matchId;
  final String choice; // 'A' | 'draw' | 'B'
  final int stake;
  final int? payout;

  Prediction({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.choice,
    required this.stake,
    this.payout,
  });

  factory Prediction.fromMap(Map<String, dynamic> m) => Prediction(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    matchId: m['match_id'] as String,
    choice: m['choice'] as String,
    stake: (m['stake'] as num?)?.toInt() ?? 0,
    payout: (m['payout'] as num?)?.toInt(),
  );
}

/// Aggregated vote counts for a match — rendered as bars in the UI.
class PredictionDistribution {
  final int votesA;
  final int votesDraw;
  final int votesB;

  PredictionDistribution({
    required this.votesA,
    required this.votesDraw,
    required this.votesB,
  });

  int get total => votesA + votesDraw + votesB;
  double pct(int v) => total == 0 ? 0 : v / total;

  static PredictionDistribution empty() =>
      PredictionDistribution(votesA: 0, votesDraw: 0, votesB: 0);
}

class PredictionsRepository {
  /// Upsert (user, match) → choice/stake.
  Future<void> submit({
    required String matchId,
    required String choice, // 'A' | 'draw' | 'B'
    int stake = 0,
  }) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        await supabase.from('predictions').upsert({
          'user_id': uid,
          'match_id': matchId,
          'choice': choice,
          'stake': stake,
        }, onConflict: 'user_id,match_id');
      } catch (_) {
        // fall through to local mirror
      }
    }
    await LocalStore.setPrediction(
      matchId,
      choice,
      stake: stake > 0 ? stake : null,
    );
  }

  Future<Prediction?> getMine(String matchId) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        final row = await supabase
            .from('predictions')
            .select()
            .eq('user_id', uid)
            .eq('match_id', matchId)
            .maybeSingle();
        if (row != null) return Prediction.fromMap(row);
      } catch (_) {
        // fall through
      }
    }
    final raw = LocalStore.getPrediction(matchId);
    if (raw == null) return null;
    final parts = raw.split(':');
    return Prediction(
      id: 'local-$matchId',
      userId: uid ?? '',
      matchId: matchId,
      choice: parts[0],
      stake: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  Future<PredictionDistribution> distribution(String matchId) async {
    try {
      final rows = await supabase
          .from('prediction_distribution')
          .select()
          .eq('match_id', matchId);
      var a = 0, d = 0, b = 0;
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final votes = (r['votes'] as num?)?.toInt() ?? 0;
        switch (r['choice'] as String?) {
          case 'A':
            a = votes;
            break;
          case 'draw':
            d = votes;
            break;
          case 'B':
            b = votes;
            break;
        }
      }
      return PredictionDistribution(votesA: a, votesDraw: d, votesB: b);
    } catch (_) {
      return PredictionDistribution.empty();
    }
  }
}
