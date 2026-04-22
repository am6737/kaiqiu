// events_repository.dart
import '../models/event.dart';
import '../services/supabase.dart';

class EventsRepository {
  Future<List<Event>> listByStatus(EventStatus status) async {
    final rows = await supabase
        .from('events')
        .select()
        .eq('status', status.name)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Event.fromMap)
        .toList();
  }

  Future<Event> fetch(String id) async {
    final row = await supabase.from('events').select().eq('id', id).single();
    return Event.fromMap(row);
  }

  Future<List<Match>> matchesFor(String eventId) async {
    final rows = await supabase
        .from('matches')
        .select()
        .eq('event_id', eventId)
        .order('played_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Match.fromMap)
        .toList();
  }

  Future<Event> create(Map<String, dynamic> payload) async {
    final row = await supabase.from('events').insert(payload).select().single();
    return Event.fromMap(row);
  }

  /// Leaderboard: (avg_score, votes) per rated player for this event, joined
  /// with profile (id, name, position). Sorted by avg_score desc.
  Future<List<PlayerRatingRow>> playerRatingsForEvent(String eventId) async {
    final rows = await supabase
        .from('event_player_ratings')
        .select('avg_score, votes, ratee:profiles!ratee_id(id, name, position)')
        .eq('event_id', eventId)
        .order('avg_score', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PlayerRatingRow.fromMap)
        .toList();
  }

  /// Per-match leaderboard: aggregates raw ratings for a single match, plus
  /// goals/assists derived from the goals table. Sorted by avg_score desc.
  Future<List<PlayerRatingRow>> playerRatingsForMatch(Match match) async {
    final matchId = match.id;
    final ratingRows =
        await supabase
                .from('ratings')
                .select(
                  'ratee_id, score, comment, highlight, created_at, '
                  'ratee:profiles!ratee_id(id, name, position)',
                )
                .eq('match_id', matchId)
            as List;
    final goalRows =
        await supabase
                .from('goals')
                .select('scorer_id, assist_id, is_own_goal')
                .eq('match_id', matchId)
            as List;

    final agg = <String, _RatingAgg>{};
    for (final raw in ratingRows.cast<Map<String, dynamic>>()) {
      final ratee = (raw['ratee'] as Map?)?.cast<String, dynamic>() ?? const {};
      final rateeId =
          (ratee['id'] as String?) ?? (raw['ratee_id'] as String? ?? '');
      if (rateeId.isEmpty) continue;
      final bucket = agg.putIfAbsent(
        rateeId,
        () => _RatingAgg(
          rateeId: rateeId,
          name: (ratee['name'] as String?) ?? '—',
          position: ratee['position'] as String?,
        ),
      );
      bucket.scores.add((raw['score'] as num).toDouble());
      final h = raw['highlight'] as String?;
      if (h != null && h.isNotEmpty && bucket.topHighlight == null) {
        bucket.topHighlight = h;
      }
      final c = raw['comment'] as String?;
      if (c != null && c.isNotEmpty && bucket.topComment == null) {
        bucket.topComment = c;
      }
    }

    for (final raw in goalRows.cast<Map<String, dynamic>>()) {
      final isOwn = (raw['is_own_goal'] as bool?) ?? false;
      final scorerId = raw['scorer_id'] as String?;
      if (scorerId != null && !isOwn && agg.containsKey(scorerId)) {
        agg[scorerId]!.goals += 1;
      }
      final assistId = raw['assist_id'] as String?;
      if (assistId != null && agg.containsKey(assistId)) {
        agg[assistId]!.assists += 1;
      }
    }

    final rows = agg.values.map((a) {
      final avg = a.scores.isEmpty
          ? 0.0
          : a.scores.reduce((x, y) => x + y) / a.scores.length;
      final highlight = a.topHighlight ?? _autoHighlight(a.goals, a.assists);
      return PlayerRatingRow(
        rateeId: a.rateeId,
        name: a.name,
        position: a.position,
        avgScore: double.parse(avg.toStringAsFixed(2)),
        votes: a.scores.length,
        goals: a.goals,
        assists: a.assists,
        topHighlight: highlight,
        topComment: a.topComment,
        side: null,
      );
    }).toList()..sort((x, y) => y.avgScore.compareTo(x.avgScore));
    return rows;
  }

  /// List events created by [userId].
  Future<List<Event>> listByCreator(String userId) async {
    final rows = await supabase
        .from('events')
        .select()
        .eq('creator_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Event.fromMap)
        .toList();
  }

  /// List events where [userId] is captain of a registered team.
  Future<List<Event>> listRegisteredByUser(String userId) async {
    final rows = await supabase
        .from('teams')
        .select('event:events(*)')
        .eq('captain_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => Event.fromMap((r['event'] as Map).cast<String, dynamic>()))
        .toList();
  }

  /// List events by a list of ids (used for favorites).
  Future<List<Event>> listByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await supabase.from('events').select().inFilter('id', ids);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Event.fromMap)
        .toList();
  }

  Future<void> updateEventStatus(String eventId, EventStatus status) async {
    await supabase
        .from('events')
        .update({'status': status.name})
        .eq('id', eventId);
  }

  Future<void> startMatch(String matchId) async {
    await supabase.from('matches').update({
      'status': 'live',
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'livekit_room': 'match_$matchId',
    }).eq('id', matchId);
  }

  Future<void> endMatch(String matchId, int scoreA, int scoreB) async {
    await supabase.from('matches').update({
      'status': 'finished',
      'done': true,
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'score_a': scoreA,
      'score_b': scoreB,
    }).eq('id', matchId);
  }

  Future<void> updateMatchScore(
    String matchId, {
    required int scoreA,
    required int scoreB,
    required int minute,
  }) async {
    await supabase.from('matches').update({
      'score_a': scoreA,
      'score_b': scoreB,
      'minute': minute,
    }).eq('id', matchId);
  }

  Future<List<Match>> liveMatchesForEvent(String eventId) async {
    final rows = await supabase
        .from('matches')
        .select()
        .eq('event_id', eventId)
        .eq('status', 'live');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Match.fromMap)
        .toList();
  }

  Future<void> insertMatch(Map<String, dynamic> payload) async {
    await supabase.from('matches').insert(payload);
  }

  Future<void> insertMatches(List<Map<String, dynamic>> rows) async {
    await supabase.from('matches').insert(rows);
  }
}

class _RatingAgg {
  final String rateeId;
  final String name;
  final String? position;
  final List<double> scores = [];
  int goals = 0;
  int assists = 0;
  String? topHighlight;
  String? topComment;
  _RatingAgg({required this.rateeId, required this.name, this.position});
}

/// Short stat string from goals/assists when the rater didn't supply one.
String? _autoHighlight(int goals, int assists) {
  if (goals == 0 && assists == 0) return null;
  final parts = <String>[];
  if (goals > 0) parts.add('$goals球');
  if (assists > 0) parts.add('$assists助');
  return parts.join(' ');
}
