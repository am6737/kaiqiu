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

class FeedPickup extends FeedItem {
  @override final String id;
  @override final DateTime createdAt;
  final String? title;
  final String venue;
  final String? hostName;
  final DateTime startAt;
  final String? timeLabel;
  final int total;
  final int need;
  final String? level;
  final int feeCents;
  final String status;

  FeedPickup({
    required this.id,
    required this.createdAt,
    this.title,
    required this.venue,
    this.hostName,
    required this.startAt,
    this.timeLabel,
    required this.total,
    required this.need,
    this.level,
    this.feeCents = 0,
    this.status = 'open',
  });

  @override String get kind => 'pickup';
  double get feeYuan => feeCents / 100;
  String get displayTime => timeLabel ?? '';
  String get displayHost => hostName ?? '—';

  factory FeedPickup.fromMap(Map<String, dynamic> m) => FeedPickup(
        id: m['id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        title: m['title'] as String?,
        venue: m['venue'] as String,
        hostName: m['host_name'] as String?,
        startAt: DateTime.parse(m['start_at'] as String),
        timeLabel: m['time_label'] as String?,
        total: m['total'] as int,
        need: m['need'] as int? ?? 0,
        level: m['level'] as String?,
        feeCents: m['fee_cents'] as int? ?? 0,
        status: m['status'] as String? ?? 'open',
      );
}

class FeedArticle extends FeedItem {
  @override final String id;
  @override final DateTime createdAt;
  final String title;
  final String? summary;
  final String? coverUrl;
  final String category;
  final int readTimeMin;
  final int viewCount;
  final int commentCount;
  final int likes;

  FeedArticle({
    required this.id,
    required this.createdAt,
    required this.title,
    this.summary,
    this.coverUrl,
    required this.category,
    this.readTimeMin = 5,
    this.viewCount = 0,
    this.commentCount = 0,
    this.likes = 0,
  });

  @override String get kind => 'article';

  factory FeedArticle.fromMap(Map<String, dynamic> m) => FeedArticle(
        id: m['id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        title: m['title'] as String,
        summary: m['summary'] as String?,
        coverUrl: m['cover_url'] as String?,
        category: m['category'] as String? ?? 'analysis',
        readTimeMin: m['read_time_min'] as int? ?? 5,
        viewCount: m['view_count'] as int? ?? 0,
        commentCount: m['comment_count'] as int? ?? 0,
        likes: m['likes'] as int? ?? 0,
      );
}

class FeedActivity extends FeedItem {
  @override final String id;
  @override final DateTime createdAt;
  final String authorName;
  final String body;
  final List<String> tags;
  final int likes;
  final int comments;
  final int shares;
  final int? matchCount;
  final int? winCount;
  final int? playDuration;
  final String? venue;

  FeedActivity({
    required this.id,
    required this.createdAt,
    required this.authorName,
    required this.body,
    this.tags = const [],
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.matchCount,
    this.winCount,
    this.playDuration,
    this.venue,
  });

  @override String get kind => 'activity';
  bool get hasStats => matchCount != null;
  String get displayTime => _relativeTime(createdAt);

  factory FeedActivity.fromMap(Map<String, dynamic> m) {
    final author = m['author'] as Map<String, dynamic>?;
    return FeedActivity(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      authorName: author?['name'] as String? ?? '—',
      body: m['body'] as String? ?? '',
      tags: (m['tags'] as List?)?.cast<String>() ?? [],
      likes: m['likes'] as int? ?? 0,
      comments: m['comments'] as int? ?? 0,
      shares: m['shares'] as int? ?? 0,
      matchCount: m['match_count'] as int?,
      winCount: m['win_count'] as int?,
      playDuration: m['play_duration'] as int?,
      venue: m['venue'] as String?,
    );
  }
}
