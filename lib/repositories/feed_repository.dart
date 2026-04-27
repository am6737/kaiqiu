// feed_repository.dart — Builds home feed from multiple Supabase tables.

import '../models/feed.dart';
import '../services/supabase.dart';

class FeedRepository {
  /// Mixed feed for 推荐 Tab — all content types, sorted by time.
  Future<List<FeedItem>> buildRecommendFeed({int limit = 20}) async {
    final results = await Future.wait([
      _recentResults(limit: limit),
      _recentPosts(limit: limit),
      _registeringEvents(limit: limit),
      _recentPickups(limit: limit),
      _recentArticles(limit: limit),
    ]);
    final items = <FeedItem>[
      ...results[0],
      ...results[1],
      ...results[2],
      ...results[3],
      ...results[4],
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.length > limit) return items.sublist(0, limit);
    return items;
  }

  /// Mixed feed for 发现 Tab — posts (with activity data) + articles.
  Future<List<FeedItem>> buildDiscoverFeed({int limit = 20}) async {
    final results = await Future.wait([
      _recentActivities(limit: limit),
      _recentArticles(limit: limit),
    ]);
    final items = <FeedItem>[...results[0], ...results[1]];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (items.length > limit) return items.sublist(0, limit);
    return items;
  }

  /// Grouped events for 赛事 Tab, keyed by status.
  Future<Map<String, List<FeedEvent>>> eventsByStatus() async {
    final rows = await supabase
        .from('events')
        .select()
        .order('created_at', ascending: false);
    final all = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedEvent.fromMap)
        .toList();
    return {
      'registering': all.where((e) => e.kind == 'event').toList(),
    };
  }

  Future<List<FeedPickup>> _recentPickups({required int limit}) async {
    final rows = await supabase
        .from('pickups')
        .select()
        .neq('status', 'done')
        .order('start_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedPickup.fromMap)
        .toList();
  }

  Future<List<FeedArticle>> _recentArticles({required int limit}) async {
    final rows = await supabase
        .from('articles')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedArticle.fromMap)
        .toList();
  }

  Future<List<FeedActivity>> _recentActivities({required int limit}) async {
    final rows = await supabase
        .from('posts')
        .select('*, author:profiles!author_id(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedActivity.fromMap)
        .toList();
  }

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

  /// All posts (with or without stats) authored by the current user.
  Future<List<FeedActivity>> myActivities({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return [];
    final rows = await supabase
        .from('posts')
        .select('*, author:profiles!author_id(name)')
        .eq('author_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedActivity.fromMap)
        .toList();
  }

  /// Articles authored by the current user.
  Future<List<FeedArticle>> myArticles({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return [];
    final rows = await supabase
        .from('articles')
        .select()
        .eq('author_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedArticle.fromMap)
        .toList();
  }

  Future<List<FeedActivity>> userActivities(String userId,
      {int limit = 5}) async {
    final rows = await supabase
        .from('posts')
        .select('*, author:profiles!author_id(name)')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedActivity.fromMap)
        .toList();
  }

  Future<List<FeedArticle>> userArticles(String userId,
      {int limit = 5}) async {
    final rows = await supabase
        .from('articles')
        .select()
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FeedArticle.fromMap)
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
