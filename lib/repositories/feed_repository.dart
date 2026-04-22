// feed_repository.dart — Builds home feed from multiple Supabase tables.

import '../models/feed.dart';
import '../services/supabase.dart';

class FeedRepository {
  /// Fetches recent feed items from multiple sources, merged and sorted by
  /// time descending. Returns up to [limit] items.
  Future<List<FeedItem>> buildFeed({int limit = 20}) async {
    final results = await Future.wait([
      _recentResults(limit: limit),
      _recentPosts(limit: limit),
      _registeringEvents(limit: limit),
    ]);

    final items = <FeedItem>[
      ...results[0],
      ...results[1],
      ...results[2],
    ];

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.length > limit) return items.sublist(0, limit);
    return items;
  }

  Future<List<FeedResult>> _recentResults({required int limit}) async {
    final rows = await supabase
        .from('matches')
        .select('''
          id, team_a_label, team_b_label, score_a, score_b, played_at,
          event:events!event_id(name),
          goals(scorer_name, is_own_goal, scorer:profiles!scorer_id(name))
        ''')
        .eq('done', true)
        .order('played_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedResult.fromMatch)
        .toList();
  }

  Future<List<FeedPost>> _recentPosts({required int limit}) async {
    final rows = await supabase
        .from('posts')
        .select('*, author:profiles!author_id(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedPost.fromMap)
        .toList();
  }

  Future<List<FeedEvent>> _registeringEvents({required int limit}) async {
    final rows = await supabase
        .from('events')
        .select('id, name, teams_max, starts_at, created_at')
        .eq('status', 'registering')
        .order('created_at', ascending: false)
        .limit(limit);

    final items = <FeedEvent>[];
    for (final m in (rows as List).cast<Map<String, dynamic>>()) {
      final teamsCount = await supabase
          .from('teams')
          .select('id')
          .eq('event_id', m['id'] as String);
      items.add(FeedEvent.fromMap({
        ...m,
        'teams_count': (teamsCount as List).length,
      }));
    }
    return items;
  }
}
