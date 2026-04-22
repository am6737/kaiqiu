// feed.dart — Home feed item types (sealed class hierarchy).

import 'package:intl/intl.dart';

sealed class FeedItem {
  String get kind;
  String get id;
  DateTime get createdAt;
}

class FeedResult extends FeedItem {
  @override
  final String id;
  @override
  final DateTime createdAt;
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final String eventName;
  final List<String> scorers;

  FeedResult({
    required this.id,
    required this.createdAt,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.eventName,
    this.scorers = const [],
  });

  @override
  String get kind => 'result';

  String get displayTime => _relativeTime(createdAt);

  factory FeedResult.fromMatch(Map<String, dynamic> m) {
    final event = m['event'] as Map<String, dynamic>?;
    final goalsList = m['goals'] as List? ?? [];
    final scorerNames = goalsList
        .whereType<Map<String, dynamic>>()
        .where((g) => g['is_own_goal'] != true)
        .map((g) {
          final name = (g['scorer_name'] as String?) ??
              ((g['scorer'] as Map?)?['name'] as String?) ??
              '?';
          return name;
        })
        .toList();

    final scorerCounts = <String, int>{};
    for (final s in scorerNames) {
      scorerCounts[s] = (scorerCounts[s] ?? 0) + 1;
    }
    final scorerDisplay =
        scorerCounts.entries.map((e) => '${e.key} ${e.value}').toList();

    return FeedResult(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['played_at'] as String),
      teamA: (m['team_a_label'] as String?) ?? '队伍A',
      teamB: (m['team_b_label'] as String?) ?? '队伍B',
      scoreA: (m['score_a'] as int?) ?? 0,
      scoreB: (m['score_b'] as int?) ?? 0,
      eventName: (event?['name'] as String?) ?? '',
      scorers: scorerDisplay,
    );
  }
}

class FeedPost extends FeedItem {
  @override
  final String id;
  @override
  final DateTime createdAt;
  final String authorName;
  final String body;
  final List<String> tags;
  final int likes;
  final int comments;
  final int shares;

  FeedPost({
    required this.id,
    required this.createdAt,
    required this.authorName,
    required this.body,
    this.tags = const [],
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
  });

  @override
  String get kind => 'post';

  String get displayTime => _relativeTime(createdAt);

  factory FeedPost.fromMap(Map<String, dynamic> m) {
    final author = m['author'] as Map<String, dynamic>?;
    final rawTags = m['tags'];
    final tags = rawTags is List ? rawTags.cast<String>() : <String>[];
    return FeedPost(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      authorName: (author?['name'] as String?) ?? '匿名',
      body: m['body'] as String,
      tags: tags,
      likes: (m['likes'] as int?) ?? 0,
      comments: (m['comments'] as int?) ?? 0,
      shares: (m['shares'] as int?) ?? 0,
    );
  }
}

class FeedEvent extends FeedItem {
  @override
  final String id;
  @override
  final DateTime createdAt;
  final String eventName;
  final int teamsRegistered;
  final int teamsMax;
  final DateTime? startsAt;

  FeedEvent({
    required this.id,
    required this.createdAt,
    required this.eventName,
    required this.teamsRegistered,
    required this.teamsMax,
    this.startsAt,
  });

  @override
  String get kind => 'event';

  String get displayTime => _relativeTime(createdAt);

  String get startIn {
    if (startsAt == null) return '';
    final diff = startsAt!.difference(DateTime.now());
    if (diff.isNegative) return '已开赛';
    if (diff.inDays > 0) return '${diff.inDays}天后开赛';
    if (diff.inHours > 0) return '${diff.inHours}小时后开赛';
    return '即将开赛';
  }

  factory FeedEvent.fromMap(Map<String, dynamic> m) {
    final teamsCount = (m['teams_count'] as int?) ?? 0;
    return FeedEvent(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      eventName: m['name'] as String,
      teamsRegistered: teamsCount,
      teamsMax: (m['teams_max'] as int?) ?? 16,
      startsAt:
          m['starts_at'] != null ? DateTime.parse(m['starts_at']) : null,
    );
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return DateFormat('MM-dd').format(dt);
}
