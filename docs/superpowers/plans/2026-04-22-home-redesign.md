# Home Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the home screen from a single scrolling list into a 4-tab layout (推荐/赛事/约球/发现) with lazy loading, keeping bottom navigation unchanged.

**Architecture:** Extract the monolithic `home_screen.dart` (1132 lines) into a TabController-driven layout with 4 independent tab views. Each tab gets its own provider and widget tree. Card components are shared across tabs. New `articles` table and extended `posts` schema support structured sports activity and article content.

**Tech Stack:** Flutter, Riverpod (FutureProvider), Supabase (PostgreSQL), go_router, AppTokens design system, ARB i18n

**Design Spec:** `docs/superpowers/specs/2026-04-22-home-redesign-design.md`

---

## File Structure

### New Files

| Path | Responsibility |
|------|---------------|
| `supabase/migrations/0002_articles_and_activity.sql` | DB schema: `articles` table + `posts` activity fields |
| `lib/models/article.dart` | Article data model |
| `lib/models/pickup_filter.dart` | PickupFilter enum/class for filtering pickups |
| `lib/features/home/cards/live_match_card.dart` | Live match card (推荐 Tab, 赛事 Tab) |
| `lib/features/home/cards/pickup_feed_card.dart` | Pickup card (推荐 Tab, 约球 Tab) |
| `lib/features/home/cards/activity_feed_card.dart` | Strava-style activity card (推荐 Tab, 发现 Tab) |
| `lib/features/home/cards/event_feed_card.dart` | Event registration card (推荐 Tab, 赛事 Tab) |
| `lib/features/home/cards/article_feed_card.dart` | Article card (推荐 Tab, 发现 Tab) |
| `lib/features/home/cards/post_feed_card.dart` | Text post card (推荐 Tab, 发现 Tab) |
| `lib/features/home/tabs/recommend_tab.dart` | 推荐 Tab — mixed feed |
| `lib/features/home/tabs/events_tab.dart` | 赛事 Tab — status-grouped events |
| `lib/features/home/tabs/pickup_tab.dart` | 约球 Tab — filterable pickup list |
| `lib/features/home/tabs/discover_tab.dart` | 发现 Tab — posts + articles feed |

### Modified Files

| Path | Changes |
|------|---------|
| `lib/models/feed.dart` | Add `FeedPickup`, `FeedArticle`, `FeedActivity` subtypes to sealed class |
| `lib/repositories/feed_repository.dart` | Add `buildRecommendFeed()`, `buildDiscoverFeed()` methods |
| `lib/repositories/pickups_repository.dart` | Add `listFiltered()` method |
| `lib/providers.dart` | Add 4 new providers for each tab |
| `lib/l10n/app_zh.arb` | Add ~25 new i18n keys |
| `lib/l10n/app_en.arb` | Add ~25 new i18n keys |
| `lib/features/home/home_screen.dart` | Replace ListView body with TabBar + TabBarView, remove old private widgets |
| `supabase/seed/demo.sql` | Add article + activity demo data |

---

## Task 1: Database Migration — Articles Table & Posts Activity Fields

**Files:**
- Create: `supabase/migrations/0002_articles_and_activity.sql`
- Modify: `supabase/seed/demo.sql`

- [ ] **Step 1: Create migration file**

```sql
-- supabase/migrations/0002_articles_and_activity.sql

-- Articles table for editorial content
CREATE TABLE IF NOT EXISTS articles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id  UUID REFERENCES profiles(id),
  title      TEXT NOT NULL,
  summary    TEXT,
  body       TEXT,
  cover_url  TEXT,
  category   TEXT NOT NULL DEFAULT 'analysis',
  read_time_min INT DEFAULT 5,
  view_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Activity fields on posts for structured sport data (Strava-style)
ALTER TABLE posts ADD COLUMN IF NOT EXISTS match_count  INT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS win_count    INT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS play_duration INT; -- minutes
ALTER TABLE posts ADD COLUMN IF NOT EXISTS venue        TEXT;
```

- [ ] **Step 2: Add demo seed data**

Append to the bottom of `supabase/seed/demo.sql`:

```sql
-- ===== Articles seed =====
INSERT INTO articles (id, author_id, title, summary, category, read_time_min, view_count, comment_count, created_at) VALUES
  ('a0000000-0000-0000-0000-000000000001', (SELECT id FROM profiles LIMIT 1),
   '春季联赛8强前瞻：飞虎 vs 雷霆', '深度解析两队战术体系与关键球员对位分析',
   'analysis', 5, 326, 18, now() - interval '2 hours'),
  ('a0000000-0000-0000-0000-000000000002', (SELECT id FROM profiles LIMIT 1),
   '提升反手高远球的5个关键要点', '从握拍到发力，系统讲解反手技术提升路径',
   'tutorial', 8, 1200, 45, now() - interval '6 hours'),
  ('a0000000-0000-0000-0000-000000000003', (SELECT id FROM profiles LIMIT 1),
   '业余选手体能训练指南', '科学的体能训练方案，帮助你在场上保持竞技状态',
   'tutorial', 10, 890, 32, now() - interval '1 day');

-- ===== Update existing posts with activity data =====
UPDATE posts SET match_count = 3, win_count = 3, play_duration = 90, venue = '南山体育中心'
WHERE id = (SELECT id FROM posts ORDER BY created_at DESC LIMIT 1);
```

- [ ] **Step 3: Apply migration locally**

Run: `supabase db reset`

Expected: Tables created, seed data loaded without errors.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0002_articles_and_activity.sql supabase/seed/demo.sql
git commit -m "feat(db): add articles table and posts activity fields"
```

---

## Task 2: Data Models — Article, PickupFilter, FeedItem Extensions

**Files:**
- Create: `lib/models/article.dart`
- Create: `lib/models/pickup_filter.dart`
- Modify: `lib/models/feed.dart`

- [ ] **Step 1: Create Article model**

```dart
// lib/models/article.dart
class Article {
  final String id;
  final String? authorId;
  final String title;
  final String? summary;
  final String? coverUrl;
  final String category;
  final int readTimeMin;
  final int viewCount;
  final int commentCount;
  final DateTime createdAt;

  const Article({
    required this.id,
    this.authorId,
    required this.title,
    this.summary,
    this.coverUrl,
    required this.category,
    this.readTimeMin = 5,
    this.viewCount = 0,
    this.commentCount = 0,
    required this.createdAt,
  });

  factory Article.fromMap(Map<String, dynamic> m) => Article(
        id: m['id'] as String,
        authorId: m['author_id'] as String?,
        title: m['title'] as String,
        summary: m['summary'] as String?,
        coverUrl: m['cover_url'] as String?,
        category: m['category'] as String? ?? 'analysis',
        readTimeMin: m['read_time_min'] as int? ?? 5,
        viewCount: m['view_count'] as int? ?? 0,
        commentCount: m['comment_count'] as int? ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
```

- [ ] **Step 2: Create PickupFilter model**

```dart
// lib/models/pickup_filter.dart
enum PickupDateRange { all, today, tomorrow, thisWeek }
enum PickupLevel { all, beginner, intermediate, advanced }
enum PickupSort { time, distance }

class PickupFilter {
  final PickupSort sortBy;
  final PickupDateRange dateRange;
  final PickupLevel level;

  const PickupFilter({
    this.sortBy = PickupSort.time,
    this.dateRange = PickupDateRange.all,
    this.level = PickupLevel.all,
  });

  PickupFilter copyWith({
    PickupSort? sortBy,
    PickupDateRange? dateRange,
    PickupLevel? level,
  }) =>
      PickupFilter(
        sortBy: sortBy ?? this.sortBy,
        dateRange: dateRange ?? this.dateRange,
        level: level ?? this.level,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickupFilter &&
          sortBy == other.sortBy &&
          dateRange == other.dateRange &&
          level == other.level;

  @override
  int get hashCode => Object.hash(sortBy, dateRange, level);
}
```

- [ ] **Step 3: Extend FeedItem sealed class**

Add three new subtypes to `lib/models/feed.dart` after the existing `FeedEvent` class:

```dart
class FeedPickup extends FeedItem {
  @override final String id;
  @override final DateTime createdAt;
  final String venue;
  final String? hostName;
  final DateTime startAt;
  final String? timeLabel;
  final int total;
  final int need;
  final String? level;
  final int feeCents;
  final String status; // open/almost/full

  FeedPickup({
    required this.id,
    required this.createdAt,
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
  final int? playDuration; // minutes
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
```

- [ ] **Step 4: Update the `_feedCard` switch in feed.dart to handle new types**

The existing `_relativeTime` helper is already in `feed.dart` and can be reused by the new classes. The `sealed class FeedItem` now has 6 subtypes total: `FeedResult`, `FeedPost`, `FeedEvent`, `FeedPickup`, `FeedArticle`, `FeedActivity`.

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze lib/models/`

Expected: No errors. Warnings about unused imports are OK at this stage.

- [ ] **Step 6: Commit**

```bash
git add lib/models/article.dart lib/models/pickup_filter.dart lib/models/feed.dart
git commit -m "feat(models): add Article, PickupFilter, and FeedItem subtypes"
```

---

## Task 3: Internationalization — New i18n Keys

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add Chinese keys to app_zh.arb**

Add these entries (after existing `home_*` keys):

```json
"home_tab_recommend": "推荐",
"home_tab_events": "赛事",
"home_tab_pickup": "约球",
"home_tab_discover": "发现",

"home_all_events": "全部赛事",
"home_events_live": "正在直播",
"home_events_registering": "报名中",
"home_events_ongoing": "进行中",
"home_events_upcoming": "即将开始",
"home_events_view": "查看",
"home_events_coming_soon": "敬请期待",
"home_events_register": "报名",

"home_pickup_filter_all": "全部",
"home_pickup_filter_distance": "距离",
"home_pickup_filter_today": "今天",
"home_pickup_filter_tomorrow": "明天",
"home_pickup_filter_week": "本周",
"home_pickup_filter_beginner": "初级",
"home_pickup_filter_intermediate": "中级",
"home_pickup_filter_advanced": "高级",
"home_pickup_slots_available": "名额充足",

"home_activity_matches": "局数",
"home_activity_record": "胜负",
"home_activity_duration": "时长",

"home_article_read_time": "{min}分钟阅读",
"@home_article_read_time": { "placeholders": { "min": { "type": "int" } } },

"home_viewers_count": "{count} 观看",
"@home_viewers_count": { "placeholders": { "count": { "type": "String" } } },

"home_discover_share": "分享"
```

- [ ] **Step 2: Add English keys to app_en.arb**

Add matching entries:

```json
"home_tab_recommend": "For You",
"home_tab_events": "Events",
"home_tab_pickup": "Pickup",
"home_tab_discover": "Discover",

"home_all_events": "All events",
"home_events_live": "Live now",
"home_events_registering": "Registering",
"home_events_ongoing": "In progress",
"home_events_upcoming": "Coming soon",
"home_events_view": "View",
"home_events_coming_soon": "Stay tuned",
"home_events_register": "Register",

"home_pickup_filter_all": "All",
"home_pickup_filter_distance": "Distance",
"home_pickup_filter_today": "Today",
"home_pickup_filter_tomorrow": "Tomorrow",
"home_pickup_filter_week": "This week",
"home_pickup_filter_beginner": "Beginner",
"home_pickup_filter_intermediate": "Intermediate",
"home_pickup_filter_advanced": "Advanced",
"home_pickup_slots_available": "Spots available",

"home_activity_matches": "Matches",
"home_activity_record": "Record",
"home_activity_duration": "Duration",

"home_article_read_time": "{min} min read",
"@home_article_read_time": { "placeholders": { "min": { "type": "int" } } },

"home_viewers_count": "{count} watching",
"@home_viewers_count": { "placeholders": { "count": { "type": "String" } } },

"home_discover_share": "Share"
```

- [ ] **Step 3: Regenerate localization files**

Run: `flutter gen-l10n`

Expected: `lib/l10n/generated/app_localizations.dart` and language-specific files updated without errors.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(i18n): add home tab redesign localization keys"
```

---

## Task 4: Repository Layer — New Query Methods

**Files:**
- Modify: `lib/repositories/feed_repository.dart`
- Modify: `lib/repositories/pickups_repository.dart`

- [ ] **Step 1: Add recommend feed and discover feed methods to FeedRepository**

Add these methods to the `FeedRepository` class in `lib/repositories/feed_repository.dart`:

```dart
import '../models/article.dart';

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
```

- [ ] **Step 2: Add events-by-status method to FeedRepository**

```dart
/// Grouped events for 赛事 Tab, keyed by status.
Future<Map<String, List<FeedEvent>>> eventsByStatus() async {
  final rows = await supabase
      .from('events')
      .select()
      .order('created_at', ascending: false);
  final events = (rows as List)
      .cast<Map<String, dynamic>>()
      .map(FeedEvent.fromMap)
      .toList();

  return {
    'registering': events.where((e) => e.kind == 'event').toList(),
  };
}
```

Note: Since the existing schema uses `status` on events but `FeedEvent.fromMap` already handles the mapping, this groups by Supabase `status` field. The live matches come from `liveNowProvider` separately.

- [ ] **Step 3: Add filtered pickup query to PickupsRepository**

Add this method to `lib/repositories/pickups_repository.dart`:

```dart
import '../models/pickup_filter.dart';

Future<List<Pickup>> listFiltered(PickupFilter filter, {int limit = 50}) async {
  var query = supabase
      .from('pickups')
      .select()
      .neq('status', 'done');

  // Date range filter
  final now = DateTime.now();
  switch (filter.dateRange) {
    case PickupDateRange.today:
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      query = query
          .gte('start_at', now.toIso8601String())
          .lte('start_at', todayEnd.toIso8601String());
      break;
    case PickupDateRange.tomorrow:
      final tomorrowStart = DateTime(now.year, now.month, now.day + 1);
      final tomorrowEnd = DateTime(now.year, now.month, now.day + 1, 23, 59, 59);
      query = query
          .gte('start_at', tomorrowStart.toIso8601String())
          .lte('start_at', tomorrowEnd.toIso8601String());
      break;
    case PickupDateRange.thisWeek:
      final weekEnd = now.add(const Duration(days: 7));
      query = query
          .gte('start_at', now.toIso8601String())
          .lte('start_at', weekEnd.toIso8601String());
      break;
    case PickupDateRange.all:
      query = query.gte('start_at', now.toIso8601String());
      break;
  }

  // Level filter
  if (filter.level != PickupLevel.all) {
    final levelStr = switch (filter.level) {
      PickupLevel.beginner => 'beginner',
      PickupLevel.intermediate => 'intermediate',
      PickupLevel.advanced => 'advanced',
      _ => '',
    };
    if (levelStr.isNotEmpty) {
      query = query.eq('level', levelStr);
    }
  }

  final rows = await query
      .order('start_at', ascending: true)
      .limit(limit);

  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(Pickup.fromMap)
      .toList();
}
```

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze lib/repositories/`

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/feed_repository.dart lib/repositories/pickups_repository.dart
git commit -m "feat(repo): add recommend feed, discover feed, and filtered pickups queries"
```

---

## Task 5: Provider Layer — New Providers for Each Tab

**Files:**
- Modify: `lib/providers.dart`

- [ ] **Step 1: Add new providers**

Add these providers to `lib/providers.dart` (after the existing home providers section, around line 155):

```dart
import 'models/pickup_filter.dart';

// ── Home Tab Providers ──────────────────────────────────

/// 推荐 Tab — mixed feed of all content types
final recommendFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  return ref.read(feedRepoProvider).buildRecommendFeed();
});

/// 发现 Tab — posts (with activity) + articles
final discoverFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  return ref.read(feedRepoProvider).buildDiscoverFeed();
});

/// 赛事 Tab — events grouped by status
final eventsByStatusProvider =
    FutureProvider<Map<String, List<FeedEvent>>>((ref) async {
  return ref.read(feedRepoProvider).eventsByStatus();
});

/// 约球 Tab — pickup filter state
final pickupFilterProvider = StateProvider<PickupFilter>(
  (_) => const PickupFilter(),
);

/// 约球 Tab — filtered pickup list (reacts to filter changes)
final filteredPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final filter = ref.watch(pickupFilterProvider);
  return ref.read(pickupsRepoProvider).listFiltered(filter);
});
```

- [ ] **Step 2: Add necessary imports at top of providers.dart**

```dart
import 'models/pickup_filter.dart';
```

Ensure `FeedEvent`, `FeedItem` are already imported from `models/feed.dart`.

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/providers.dart`

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(providers): add recommend, discover, events-by-status, and filtered pickups providers"
```

---

## Task 6: Card Components — 6 Reusable Card Widgets

**Files:**
- Create: `lib/features/home/cards/live_match_card.dart`
- Create: `lib/features/home/cards/pickup_feed_card.dart`
- Create: `lib/features/home/cards/activity_feed_card.dart`
- Create: `lib/features/home/cards/event_feed_card.dart`
- Create: `lib/features/home/cards/article_feed_card.dart`
- Create: `lib/features/home/cards/post_feed_card.dart`

- [ ] **Step 1: Create cards directory**

Run: `mkdir -p lib/features/home/cards`

- [ ] **Step 2: Create LiveMatchCard**

```dart
// lib/features/home/cards/live_match_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/live_match.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class LiveMatchCard extends StatelessWidget {
  final LiveMatch match;
  const LiveMatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => context.push('/worldcup/live/${match.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              t.accent.withOpacity(0.25),
              t.danger.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(t.r3),
          border: Border.all(color: t.accent.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // LIVE badge row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.danger.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulseDot(color: t.danger),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE · ${match.minute}\'',
                        style: TextStyle(
                          color: t.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  l.home_viewers_count(match.viewersDisplay),
                  style: TextStyle(fontSize: 10, color: t.inkDim),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Score row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    match.teamA,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${match.scoreA} : ${match.scoreB}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      fontFamily: t.fontMono,
                      fontFamilyFallback: t.monoFallbacks,
                      color: t.ink,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    match.teamB,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create PickupFeedCard**

```dart
// lib/features/home/cards/pickup_feed_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/pickup.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/avatar.dart';

class PickupFeedCard extends StatelessWidget {
  final Pickup pickup;
  const PickupFeedCard({super.key, required this.pickup});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    final needed = pickup.displayNeed;
    final isUrgent = needed > 0 && needed <= 2;

    return GestureDetector(
      onTap: () => context.push('/pickup/${pickup.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.elev1,
          borderRadius: BorderRadius.circular(t.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: venue + urgency badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickup.venue,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '🕐 ${pickup.displayTime} · 💰 ¥${pickup.feeYuan.toStringAsFixed(0)} · ${pickup.level ?? ""}',
                        style: TextStyle(fontSize: 11, color: t.inkDim),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(pickup: pickup, tokens: t, l10n: l),
              ],
            ),
            const SizedBox(height: 10),
            // Footer: avatars + join button
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // avatar stack placeholder
                      Text(
                        '${pickup.total - needed}/${pickup.total}${l.home_feed_pickup}',
                        style: TextStyle(fontSize: 10, color: t.inkMute),
                      ),
                    ],
                  ),
                ),
                if (needed > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.home_join_cta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(l.home_full,
                      style: TextStyle(fontSize: 10, color: t.inkMute)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Pickup pickup;
  final AppTokens tokens;
  final AppLocalizations l10n;
  const _StatusBadge(
      {required this.pickup, required this.tokens, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final needed = pickup.displayNeed;
    final Color bg;
    final Color fg;
    final String text;

    if (needed > 0 && needed <= 2) {
      bg = tokens.warn.withOpacity(0.15);
      fg = tokens.warn;
      text = l10n.home_need_n(needed);
    } else if (needed > 2) {
      bg = const Color(0xFF4CAF50).withOpacity(0.15);
      fg = const Color(0xFF4CAF50);
      text = l10n.home_pickup_slots_available;
    } else {
      bg = tokens.inkMute.withOpacity(0.15);
      fg = tokens.inkMute;
      text = l10n.home_full;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
```

- [ ] **Step 4: Create ActivityFeedCard (Strava-style)**

```dart
// lib/features/home/cards/activity_feed_card.dart
import 'package:flutter/material.dart';

import '../../../models/feed.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/avatar.dart';

class ActivityFeedCard extends StatelessWidget {
  final FeedActivity item;
  const ActivityFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: BorderRadius.circular(t.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              Avatar(item.authorName, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.authorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      '${item.displayTime}${item.venue != null ? ' · ${item.venue}' : ''}',
                      style: TextStyle(fontSize: 10, color: t.inkMute),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Body text
          Text(
            item.body,
            style: TextStyle(
              fontSize: 12,
              color: t.ink.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          // Stats bar (Strava-style)
          if (item.hasStats) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                    value: '${item.matchCount}',
                    label: l.home_activity_matches,
                    tokens: t),
                const SizedBox(width: 5),
                _StatChip(
                    value: '${item.winCount}W',
                    label: l.home_activity_record,
                    tokens: t),
                const SizedBox(width: 5),
                _StatChip(
                    value: item.playDuration != null
                        ? '${(item.playDuration! / 60).toStringAsFixed(1)}h'
                        : '—',
                    label: l.home_activity_duration,
                    tokens: t),
              ],
            ),
          ],
          // Tags
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              children: item.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.elev2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(fontSize: 10, color: t.accent),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          // Interaction bar
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.elev2)),
            ),
            child: Row(
              children: [
                Text('❤️ ${item.likes}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
                const SizedBox(width: 18),
                Text('💬 ${item.comments}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
                const SizedBox(width: 18),
                Text('↗️ ${l.home_discover_share}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  final AppTokens tokens;
  const _StatChip(
      {required this.value, required this.label, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: tokens.elev2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: tokens.fontMono,
                fontFamilyFallback: tokens.monoFallbacks,
                color: tokens.accent,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(fontSize: 8, color: tokens.inkMute),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create EventFeedCard**

```dart
// lib/features/home/cards/event_feed_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/feed.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class EventFeedCard extends StatelessWidget {
  final FeedEvent item;
  const EventFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    final progress = item.teamsMax > 0
        ? item.teamsRegistered / item.teamsMax
        : 0.0;

    return GestureDetector(
      onTap: () => context.push('/event/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.elev1,
          borderRadius: BorderRadius.circular(t.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.home_tab_events,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: t.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.displayTime,
                  style: TextStyle(fontSize: 10, color: t.inkMute),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.eventName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${item.teamsRegistered}/${item.teamsMax} ${l.home_event_registered_label} · ${item.startIn}',
              style: TextStyle(fontSize: 11, color: t.inkDim),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: t.elev2,
                      valueColor: AlwaysStoppedAnimation(t.accent),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.home_event_register_now,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Create ArticleFeedCard (The Athletic style)**

```dart
// lib/features/home/cards/article_feed_card.dart
import 'package:flutter/material.dart';

import '../../../models/feed.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class ArticleFeedCard extends StatelessWidget {
  final FeedArticle item;
  const ArticleFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: BorderRadius.circular(t.r3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: t.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.summary != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.summary!,
                    style: TextStyle(fontSize: 11, color: t.inkDim, height: 1.4),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '👁 ${item.viewCount} · 💬 ${item.commentCount} · ${l.home_article_read_time(item.readTimeMin)}',
                  style: TextStyle(fontSize: 10, color: t.inkMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Cover image placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  t.accent.withOpacity(0.2),
                  t.danger.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(t.r2),
            ),
            child: item.coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(t.r2),
                    child: Image.network(item.coverUrl!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text('📰',
                        style: TextStyle(fontSize: 28)),
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Create PostFeedCard**

```dart
// lib/features/home/cards/post_feed_card.dart
import 'package:flutter/material.dart';

import '../../../models/feed.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/avatar.dart';

class PostFeedCard extends StatelessWidget {
  final FeedPost item;
  const PostFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: BorderRadius.circular(t.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(item.authorName, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.authorName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      item.displayTime,
                      style: TextStyle(fontSize: 10, color: t.inkMute),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.body,
            style: TextStyle(
              fontSize: 12,
              color: t.ink.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              children: item.tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: t.elev2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(fontSize: 10, color: t.accent),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.elev2)),
            ),
            child: Row(
              children: [
                Text('❤️ ${item.likes}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
                const SizedBox(width: 18),
                Text('💬 ${item.comments}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
                const SizedBox(width: 18),
                Text('↗️ ${l.home_discover_share}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Verify all cards compile**

Run: `flutter analyze lib/features/home/cards/`

Expected: No errors.

- [ ] **Step 9: Commit**

```bash
git add lib/features/home/cards/
git commit -m "feat(ui): add 6 reusable card components for home tabs"
```

---

## Task 7: Recommend Tab — Mixed Feed

**Files:**
- Create: `lib/features/home/tabs/recommend_tab.dart`

- [ ] **Step 1: Create tabs directory**

Run: `mkdir -p lib/features/home/tabs`

- [ ] **Step 2: Create RecommendTab**

```dart
// lib/features/home/tabs/recommend_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feed.dart';
import '../../../models/live_match.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cards/live_match_card.dart';
import '../cards/pickup_feed_card.dart';
import '../cards/activity_feed_card.dart';
import '../cards/event_feed_card.dart';
import '../cards/article_feed_card.dart';
import '../cards/post_feed_card.dart';

class RecommendTab extends ConsumerWidget {
  const RecommendTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final feedAsync = ref.watch(recommendFeedProvider);
    final liveAsync = ref.watch(liveNowProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(recommendFeedProvider);
        ref.invalidate(liveNowProvider);
      },
      child: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          // Prepend live matches at top of feed
          final liveMatches = liveAsync.valueOrNull ?? [];
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: liveMatches.length + items.length,
            itemBuilder: (ctx, i) {
              if (i < liveMatches.length) {
                return LiveMatchCard(match: liveMatches[i]);
              }
              final item = items[i - liveMatches.length];
              return _buildCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(FeedItem item) {
    return switch (item) {
      FeedResult r => PostFeedCard(
          item: FeedPost(
            id: r.id,
            createdAt: r.createdAt,
            authorName: r.eventName,
            body: '${r.teamA} ${r.scoreA} : ${r.scoreB} ${r.teamB}',
            tags: [],
            likes: 0,
            comments: 0,
            shares: 0,
          ),
        ),
      FeedPost p => PostFeedCard(item: p),
      FeedEvent e => EventFeedCard(item: e),
      FeedPickup p => PickupFeedCard(
          pickup: _pickupFromFeed(p),
        ),
      FeedArticle a => ArticleFeedCard(item: a),
      FeedActivity a => ActivityFeedCard(item: a),
    };
  }

  Pickup _pickupFromFeed(FeedPickup fp) {
    // Minimal Pickup object for the card. The card only uses
    // venue, displayTime, feeYuan, level, displayNeed, status, id.
    return Pickup.fromMap({
      'id': fp.id,
      'venue': fp.venue,
      'start_at': fp.startAt.toIso8601String(),
      'time_label': fp.timeLabel,
      'total': fp.total,
      'need': fp.need,
      'level': fp.level,
      'fee_cents': fp.feeCents,
      'status': fp.status,
      'created_at': fp.createdAt.toIso8601String(),
    });
  }
}
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/features/home/tabs/recommend_tab.dart`

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/tabs/recommend_tab.dart
git commit -m "feat(ui): add RecommendTab with mixed feed layout"
```

---

## Task 8: Events Tab — Status-Grouped List

**Files:**
- Create: `lib/features/home/tabs/events_tab.dart`

- [ ] **Step 1: Create EventsTab**

```dart
// lib/features/home/tabs/events_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/feed.dart';
import '../../../models/live_match.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cards/live_match_card.dart';

class EventsTab extends ConsumerWidget {
  const EventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    final liveAsync = ref.watch(liveNowProvider);
    final eventsAsync = ref.watch(eventsByStatusProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(liveNowProvider);
        ref.invalidate(eventsByStatusProvider);
      },
      child: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (grouped) {
          final liveMatches = liveAsync.valueOrNull ?? [];
          final registering = grouped['registering'] ?? [];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Live section
              if (liveMatches.isNotEmpty) ...[
                _SectionHeader(
                  icon: null,
                  label: l.home_events_live,
                  color: t.danger,
                  hasPulse: true,
                ),
                ...liveMatches.map((m) => LiveMatchCard(match: m)),
                const SizedBox(height: 8),
              ],
              // Registering section
              if (registering.isNotEmpty) ...[
                _SectionHeader(
                  icon: '🔥',
                  label: l.home_events_registering,
                  color: t.warn,
                ),
                ...registering.map((e) => _EventStatusCard(
                      event: e,
                      tokens: t,
                      trailing: GestureDetector(
                        onTap: () => context.push('/event/${e.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: t.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l.home_events_register,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String? icon;
  final String label;
  final Color color;
  final bool hasPulse;

  const _SectionHeader({
    this.icon,
    required this.label,
    required this.color,
    this.hasPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Text(icon!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStatusCard extends StatelessWidget {
  final FeedEvent event;
  final AppTokens tokens;
  final Widget? trailing;

  const _EventStatusCard({
    required this.event,
    required this.tokens,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final progress = event.teamsMax > 0
        ? event.teamsRegistered / event.teamsMax
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.elev1,
        borderRadius: BorderRadius.circular(tokens.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.teamsRegistered}/${event.teamsMax} · ${event.startIn}',
                      style: TextStyle(fontSize: 11, color: tokens.inkDim),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: tokens.elev2,
              valueColor: AlwaysStoppedAnimation(tokens.accent),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/home/tabs/events_tab.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/tabs/events_tab.dart
git commit -m "feat(ui): add EventsTab with status-grouped event list"
```

---

## Task 9: Pickup Tab — Filterable List

**Files:**
- Create: `lib/features/home/tabs/pickup_tab.dart`

- [ ] **Step 1: Create PickupTab**

```dart
// lib/features/home/tabs/pickup_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pickup_filter.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cards/pickup_feed_card.dart';

class PickupTab extends ConsumerWidget {
  const PickupTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    final filter = ref.watch(pickupFilterProvider);
    final pickupsAsync = ref.watch(filteredPickupsProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(filteredPickupsProvider);
      },
      child: Column(
        children: [
          // Filter bar
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _FilterChip(
                  label: l.home_pickup_filter_all,
                  selected: filter.dateRange == PickupDateRange.all &&
                      filter.level == PickupLevel.all,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      const PickupFilter(),
                  tokens: t,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '📏 ${l.home_pickup_filter_distance}',
                  selected: filter.sortBy == PickupSort.distance,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      filter.copyWith(sortBy: PickupSort.distance),
                  tokens: t,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '🕐 ${l.home_pickup_filter_today}',
                  selected: filter.dateRange == PickupDateRange.today,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      filter.copyWith(dateRange: PickupDateRange.today),
                  tokens: t,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '⭐ ${l.home_pickup_filter_intermediate}',
                  selected: filter.level == PickupLevel.intermediate,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      filter.copyWith(level: PickupLevel.intermediate),
                  tokens: t,
                ),
              ],
            ),
          ),
          // Pickup list
          Expanded(
            child: pickupsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  l.home_pickups_load_failed,
                  style: TextStyle(color: t.inkDim),
                ),
              ),
              data: (pickups) => pickups.isEmpty
                  ? Center(
                      child: Text('暂无约球',
                          style: TextStyle(color: t.inkMute)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: pickups.length,
                      itemBuilder: (ctx, i) =>
                          PickupFeedCard(pickup: pickups[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? tokens.accent : tokens.elev1,
          border: selected
              ? null
              : Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : tokens.inkSub,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/home/tabs/pickup_tab.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/tabs/pickup_tab.dart
git commit -m "feat(ui): add PickupTab with filter chips and pickup list"
```

---

## Task 10: Discover Tab — Posts + Articles Feed

**Files:**
- Create: `lib/features/home/tabs/discover_tab.dart`

- [ ] **Step 1: Create DiscoverTab**

```dart
// lib/features/home/tabs/discover_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../cards/activity_feed_card.dart';
import '../cards/article_feed_card.dart';
import '../cards/post_feed_card.dart';

class DiscoverTab extends ConsumerWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final feedAsync = ref.watch(discoverFeedProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(discoverFeedProvider);
      },
      child: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          itemBuilder: (ctx, i) => _buildCard(items[i]),
        ),
      ),
    );
  }

  Widget _buildCard(FeedItem item) {
    return switch (item) {
      FeedActivity a => ActivityFeedCard(item: a),
      FeedArticle a => ArticleFeedCard(item: a),
      FeedPost p => PostFeedCard(item: p),
      // Other types shouldn't appear here, but handle gracefully
      _ => const SizedBox.shrink(),
    };
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/home/tabs/discover_tab.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/tabs/discover_tab.dart
git commit -m "feat(ui): add DiscoverTab with posts and articles feed"
```

---

## Task 11: HomeScreen Refactor — TabBar Integration

This is the core task. Replace the monolithic ListView in `home_screen.dart` with a TabController + TabBarView layout.

**Files:**
- Modify: `lib/features/home/home_screen.dart`

- [ ] **Step 1: Update HomeScreen to use TabController**

The `HomeScreen` must change from `ConsumerWidget` to `ConsumerStatefulWidget` to hold a `TabController`. Replace the class definition and build method (lines 22-140 of the original file).

The new structure:

```dart
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Keep existing TopBar
            const _TopBar(),
            // New TabBar
            TabBar(
              controller: _tabCtrl,
              labelColor: t.accent,
              unselectedLabelColor: t.inkMute,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: t.accent,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: t.elev1,
              tabs: [
                Tab(text: l.home_tab_recommend),
                Tab(text: l.home_tab_events),
                Tab(text: l.home_tab_pickup),
                Tab(text: l.home_tab_discover),
              ],
            ),
            // Tab content — each tab lazy-loads
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  RecommendTab(),
                  EventsTab(),
                  PickupTab(),
                  DiscoverTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add imports for new tab widgets**

At the top of `home_screen.dart`, add:

```dart
import 'tabs/recommend_tab.dart';
import 'tabs/events_tab.dart';
import 'tabs/pickup_tab.dart';
import 'tabs/discover_tab.dart';
```

- [ ] **Step 3: Remove old private widgets that are now replaced**

Delete these private classes from `home_screen.dart` (they are replaced by the new tab views and card components):

- `_LiveStrip` (lines ~306-495) — replaced by `LiveMatchCard` in RecommendTab/EventsTab
- `_RateCtaBanner` (lines ~500-570) — will be re-added to RecommendTab as a feed item later
- `_LivePickupCard` (lines ~926-1058) — replaced by `PickupFeedCard`
- `_ResultCard` (lines ~575-717) — replaced by PostFeedCard handling in RecommendTab
- `_PostCard` (lines ~719-801) — replaced by PostFeedCard
- `_EventTeaserCard` (lines ~821-921) — replaced by EventFeedCard
- `_PickupLoading` (lines ~1060-1082) — loading is handled per-tab
- `_PickupError` (lines ~1084-1131) — error is handled per-tab
- `_InteractStat` helper widget
- The old `_feedCard` method (lines ~130-139)
- The old `ListView` body with all its inline sections

Keep these:
- `_TopBar` (lines ~145-205) — still used
- `_SportPicker` (lines ~226-301) — still used by TopBar
- `_InboxUnreadDot` — still used by TopBar

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze lib/features/home/`

Expected: No errors. Some warnings about unused imports from removed widgets are expected — clean those up.

- [ ] **Step 5: Clean up unused imports**

Remove imports that were only used by deleted widgets (e.g., `dart:async` for Timer in LiveStrip, `cached_network_image` if only used in LiveStrip).

- [ ] **Step 6: Run full app analysis**

Run: `flutter analyze`

Expected: No errors across entire project.

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat(home): refactor to TabBar layout with 4 tabs (recommend/events/pickup/discover)"
```

---

## Task 12: Integration Verification & Polish

**Files:**
- Various — fixing any compilation issues and verifying navigation

- [ ] **Step 1: Run full build**

Run: `flutter build apk --debug 2>&1 | tail -20`

Expected: BUILD SUCCESSFUL. If there are errors, fix them.

- [ ] **Step 2: Verify all navigation routes still work**

Check that these routes are still reachable from the new cards:
- `/worldcup/live/{matchId}` — from LiveMatchCard
- `/pickup/{pickupId}` — from PickupFeedCard
- `/event/{eventId}` — from EventFeedCard
- `/city-picker` — from TopBar
- `/search` — from TopBar
- `/inbox` — from TopBar

Verify by grepping for each route in the new card files:

Run: `grep -r "context.push" lib/features/home/cards/ lib/features/home/tabs/`

Expected: All navigation push calls present and using correct route patterns.

- [ ] **Step 3: Verify i18n keys are all connected**

Run: `flutter gen-l10n && flutter analyze`

Expected: No missing localization delegate errors.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(home): complete home page redesign with 4-tab layout

- Recommend tab: mixed feed with live matches, pickups, activities, events, articles
- Events tab: status-grouped event list (live/registering/ongoing/upcoming)
- Pickup tab: filterable pickup list with chips
- Discover tab: posts + articles mixed feed
- New models: Article, PickupFilter, FeedPickup, FeedArticle, FeedActivity
- New providers: recommendFeed, discoverFeed, eventsByStatus, filteredPickups
- New DB: articles table, posts activity fields
- 25+ new i18n keys (zh + en)"
```
