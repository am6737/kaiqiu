# Like & Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real like toggle and share buttons to discovery feed cards and detail screens.

**Architecture:** New `likes` table with `target_type`/`target_id` columns, a `LikesRepository` for toggle/query, Riverpod providers for batch liked-state, and UI changes across 5 widget files. Share uses existing `share_plus` via `share_helper.dart`.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase (PostgreSQL + RLS), share_plus

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `supabase/migrations/0011_likes.sql` | likes table, RLS, trigger, articles.likes column |
| Create | `lib/repositories/likes_repository.dart` | toggle, isLiked, likedIds |
| Modify | `lib/models/article.dart` | Add `likes` field |
| Modify | `lib/models/feed.dart` | Add `likes` field to `FeedArticle` |
| Modify | `lib/providers.dart` | Add likes repo + liked IDs providers |
| Modify | `lib/utils/share_helper.dart` | Add sharePost, shareArticle |
| Modify | `lib/l10n/app_zh.arb` | Add like_login_required string |
| Modify | `lib/l10n/app_en.arb` | Add like_login_required string |
| Modify | `lib/features/home/cards/post_feed_card.dart` | Interactive like + share |
| Modify | `lib/features/home/cards/activity_feed_card.dart` | Interactive like + share |
| Modify | `lib/features/home/cards/article_feed_card.dart` | Add interaction row with like + share |
| Modify | `lib/features/post/post_detail_screen.dart` | Interactive like + share |
| Modify | `lib/features/article/article_detail_screen.dart` | Add like + share row |

---

### Task 1: Database Migration — `likes` table

**Files:**
- Create: `supabase/migrations/0011_likes.sql`

- [ ] **Step 1: Create migration file**

```sql
-- 0011_likes.sql — Universal likes table for posts & articles

-- 1. likes table
create table likes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'article')),
  target_id   uuid not null,
  created_at  timestamptz not null default now(),
  unique (user_id, target_type, target_id)
);

create index idx_likes_target on likes(target_type, target_id);

-- 2. RLS
alter table likes enable row level security;

create policy "Anyone can read likes"
  on likes for select using (true);

create policy "Authenticated users can insert own likes"
  on likes for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own likes"
  on likes for delete
  using (auth.uid() = user_id);

-- 3. Add likes column to articles (posts already has one)
alter table articles add column if not exists likes int not null default 0;

-- 4. Unified trigger to keep posts.likes and articles.likes in sync
create or replace function sync_likes_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    if new.target_type = 'post' then
      update posts set likes = likes + 1 where id = new.target_id;
    elsif new.target_type = 'article' then
      update articles set likes = likes + 1 where id = new.target_id;
    end if;
  elsif tg_op = 'DELETE' then
    if old.target_type = 'post' then
      update posts set likes = greatest(likes - 1, 0) where id = old.target_id;
    elsif old.target_type = 'article' then
      update articles set likes = greatest(likes - 1, 0) where id = old.target_id;
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger trg_sync_likes
  after insert or delete on likes
  for each row execute function sync_likes_count();
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0011_likes.sql
git commit -m "feat(db): add universal likes table with RLS and sync trigger"
```

---

### Task 2: LikesRepository

**Files:**
- Create: `lib/repositories/likes_repository.dart`

- [ ] **Step 1: Create the repository**

```dart
import '../services/supabase.dart';

class LikesRepository {
  Future<bool> toggle(String targetType, String targetId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final existing = await supabase
        .from('likes')
        .select('id')
        .eq('user_id', uid)
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .maybeSingle();
    if (existing != null) {
      await supabase
          .from('likes')
          .delete()
          .eq('user_id', uid)
          .eq('target_type', targetType)
          .eq('target_id', targetId);
      return false;
    } else {
      await supabase.from('likes').insert({
        'user_id': uid,
        'target_type': targetType,
        'target_id': targetId,
      });
      return true;
    }
  }

  Future<bool> isLiked(String targetType, String targetId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final row = await supabase
        .from('likes')
        .select('id')
        .eq('user_id', uid)
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .maybeSingle();
    return row != null;
  }

  Future<Set<String>> likedIds(String targetType) async {
    final uid = currentUserId;
    if (uid == null) return {};
    final rows = await supabase
        .from('likes')
        .select('target_id')
        .eq('user_id', uid)
        .eq('target_type', targetType);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['target_id'] as String)
        .toSet();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/repositories/likes_repository.dart
git commit -m "feat: add LikesRepository with toggle/isLiked/likedIds"
```

---

### Task 3: Models — Add `likes` to Article and FeedArticle

**Files:**
- Modify: `lib/models/article.dart`
- Modify: `lib/models/feed.dart`

- [ ] **Step 1: Add `likes` field to Article**

In `lib/models/article.dart`, add the `likes` field to the class, constructor, and factory:

```dart
class Article {
  final String id;
  final String? authorId;
  final String title;
  final String? summary;
  final String? body;
  final String? coverUrl;
  final String category;
  final int readTimeMin;
  final int viewCount;
  final int commentCount;
  final int likes;
  final DateTime createdAt;

  const Article({
    required this.id,
    this.authorId,
    required this.title,
    this.summary,
    this.body,
    this.coverUrl,
    required this.category,
    this.readTimeMin = 5,
    this.viewCount = 0,
    this.commentCount = 0,
    this.likes = 0,
    required this.createdAt,
  });

  factory Article.fromMap(Map<String, dynamic> m) => Article(
        id: m['id'] as String,
        authorId: m['author_id'] as String?,
        title: m['title'] as String,
        summary: m['summary'] as String?,
        body: m['body'] as String?,
        coverUrl: m['cover_url'] as String?,
        category: m['category'] as String? ?? 'analysis',
        readTimeMin: m['read_time_min'] as int? ?? 5,
        viewCount: m['view_count'] as int? ?? 0,
        commentCount: m['comment_count'] as int? ?? 0,
        likes: m['likes'] as int? ?? 0,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
```

- [ ] **Step 2: Add `likes` field to FeedArticle**

In `lib/models/feed.dart`, add `likes` to `FeedArticle`:

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/models/article.dart lib/models/feed.dart
git commit -m "feat(models): add likes field to Article and FeedArticle"
```

---

### Task 4: Providers — likes repo + liked IDs

**Files:**
- Modify: `lib/providers.dart`

- [ ] **Step 1: Add import and providers**

Add import at top of `lib/providers.dart`:

```dart
import 'repositories/likes_repository.dart';
```

Add after the existing repository providers (after `final livekitRepoProvider = ...`):

```dart
final likesRepoProvider = Provider((_) => LikesRepository());

final likedPostIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(likesRepoProvider).likedIds('post');
});

final likedArticleIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(likesRepoProvider).likedIds('article');
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(providers): add likes repo and liked IDs providers"
```

---

### Task 5: Share Helper — add sharePost and shareArticle

**Files:**
- Modify: `lib/utils/share_helper.dart`

- [ ] **Step 1: Add sharePost and shareArticle functions**

Add at the end of `lib/utils/share_helper.dart`, before the `_fmt` helper:

```dart
Future<void> sharePost({
  required String authorName,
  required String body,
  List<String> tags = const [],
}) async {
  final preview = body.length > 150 ? '${body.substring(0, 150)}...' : body;
  final text = [
    '\u{1F4DD} $authorName 的动态',
    preview,
    if (tags.isNotEmpty) tags.map((t) => '#$t').join(' '),
  ].join('\n');
  await Share.share(text, subject: '开球·动态');
}

Future<void> shareArticle({
  required String title,
  required String category,
  String? summary,
}) async {
  final text = [
    '\u{1F4F0} $category | $title',
    if (summary != null) summary,
  ].join('\n');
  await Share.share(text, subject: '开球·文章');
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/utils/share_helper.dart
git commit -m "feat(share): add sharePost and shareArticle helpers"
```

---

### Task 6: l10n — add like_login_required string

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add string to app_zh.arb**

Add after the `comment_login_required` entry:

```json
  "like_login_required": "请先登录后再点赞",
```

- [ ] **Step 2: Add string to app_en.arb**

Add the corresponding entry:

```json
  "like_login_required": "Please sign in to like",
```

- [ ] **Step 3: Regenerate l10n**

```bash
cd /home/coder/workspaces/qiuju_app && flutter gen-l10n
```

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add like_login_required string"
```

---

### Task 7: PostFeedCard — interactive like + share

**Files:**
- Modify: `lib/features/home/cards/post_feed_card.dart`

- [ ] **Step 1: Rewrite PostFeedCard as ConsumerWidget with like/share**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/avatar.dart';

class PostFeedCard extends ConsumerWidget {
  final FeedPost item;
  const PostFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final likedIds = ref.watch(likedPostIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(item.id);

    return GestureDetector(
      onTap: () => context.push('/post/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Avatar(item.authorName, size: 32),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.authorName,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.ink)),
                      Text(item.displayTime,
                          style: TextStyle(fontSize: 10, color: t.inkMute)),
                    ])),
              ]),
              const SizedBox(height: 8),
              Text(item.body,
                  style: TextStyle(
                      fontSize: 12,
                      color: t.ink.withValues(alpha: 0.8),
                      height: 1.5)),
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
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('#$tag',
                                  style:
                                      TextStyle(fontSize: 10, color: t.accent)),
                            ))
                        .toList()),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.elev2))),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _toggleLike(context, ref),
                    child: Text(
                      '${isLiked ? "❤️" : "🤍"} ${item.likes}',
                      style: TextStyle(fontSize: 11, color: t.inkMute),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text('💬 ${item.comments}',
                      style: TextStyle(fontSize: 11, color: t.inkMute)),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () => sharePost(
                      authorName: item.authorName,
                      body: item.body,
                      tags: item.tags,
                    ),
                    child: Text('↗️ ${l.home_discover_share}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                  ),
                ]),
              ),
            ]),
      ),
    );
  }

  void _toggleLike(BuildContext context, WidgetRef ref) async {
    if (!isSignedIn) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.like_login_required)),
      );
      return;
    }
    await ref.read(likesRepoProvider).toggle('post', item.id);
    ref.invalidate(likedPostIdsProvider);
    ref.invalidate(discoverFeedProvider);
  }
}
```

- [ ] **Step 2: Verify no compile errors**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/home/cards/post_feed_card.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/cards/post_feed_card.dart
git commit -m "feat(ui): add interactive like and share to PostFeedCard"
```

---

### Task 8: ActivityFeedCard — interactive like + share

**Files:**
- Modify: `lib/features/home/cards/activity_feed_card.dart`

- [ ] **Step 1: Rewrite ActivityFeedCard as ConsumerWidget with like/share**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/avatar.dart';

class ActivityFeedCard extends ConsumerWidget {
  final FeedActivity item;
  const ActivityFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final likedIds = ref.watch(likedPostIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(item.id);

    return GestureDetector(
      onTap: () => context.push('/post/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author
              Row(children: [
                Avatar(item.authorName, size: 32),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.authorName,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.ink)),
                      Text(
                          '${item.displayTime}${item.venue != null ? ' · ${item.venue}' : ''}',
                          style: TextStyle(fontSize: 10, color: t.inkMute)),
                    ])),
              ]),
              const SizedBox(height: 8),
              // Body
              Text(item.body,
                  style: TextStyle(
                      fontSize: 12,
                      color: t.ink.withValues(alpha: 0.8),
                      height: 1.5)),
              // Stats bar
              if (item.hasStats) ...[
                const SizedBox(height: 8),
                Row(children: [
                  _stat(t, '${item.matchCount}', l.home_activity_matches),
                  const SizedBox(width: 5),
                  _stat(t, '${item.winCount}W', l.home_activity_record),
                  const SizedBox(width: 5),
                  _stat(
                      t,
                      item.playDuration != null
                          ? '${(item.playDuration! / 60).toStringAsFixed(1)}h'
                          : '—',
                      l.home_activity_duration),
                ]),
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
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('#$tag',
                                  style:
                                      TextStyle(fontSize: 10, color: t.accent)),
                            ))
                        .toList()),
              ],
              const SizedBox(height: 8),
              // Interactions
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.elev2))),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => _toggleLike(context, ref),
                    child: Text(
                      '${isLiked ? "❤️" : "🤍"} ${item.likes}',
                      style: TextStyle(fontSize: 11, color: t.inkMute),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text('💬 ${item.comments}',
                      style: TextStyle(fontSize: 11, color: t.inkMute)),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () => sharePost(
                      authorName: item.authorName,
                      body: item.body,
                      tags: item.tags,
                    ),
                    child: Text('↗️ ${l.home_discover_share}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                  ),
                ]),
              ),
            ]),
      ),
    );
  }

  void _toggleLike(BuildContext context, WidgetRef ref) async {
    if (!isSignedIn) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.like_login_required)),
      );
      return;
    }
    await ref.read(likesRepoProvider).toggle('post', item.id);
    ref.invalidate(likedPostIdsProvider);
    ref.invalidate(discoverFeedProvider);
  }

  Widget _stat(AppTokens t, String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: BoxDecoration(
              color: t.elev2, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: t.fontMono,
                    fontFamilyFallback: t.monoFallbacks,
                    color: t.accent)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(fontSize: 8, color: t.inkMute)),
          ]),
        ),
      );
}
```

- [ ] **Step 2: Verify no compile errors**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/home/cards/activity_feed_card.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/cards/activity_feed_card.dart
git commit -m "feat(ui): add interactive like and share to ActivityFeedCard"
```

---

### Task 9: ArticleFeedCard — add interaction row with like + share

**Files:**
- Modify: `lib/features/home/cards/article_feed_card.dart`

- [ ] **Step 1: Rewrite ArticleFeedCard as ConsumerWidget with interaction row**

Replace the entire file content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/share_helper.dart';

class ArticleFeedCard extends ConsumerWidget {
  final FeedArticle item;
  const ArticleFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final likedIds = ref.watch(likedArticleIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(item.id);

    return GestureDetector(
      onTap: () => context.push('/article/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.category,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: t.accent)),
                  const SizedBox(height: 3),
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                          height: 1.4)),
                  if (item.summary != null) ...[
                    const SizedBox(height: 3),
                    Text(item.summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: t.inkDim, height: 1.4)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                      '👁 ${item.viewCount} · 💬 ${item.commentCount} · ${l.home_article_read_time(item.readTimeMin)}',
                      style: TextStyle(fontSize: 10, color: t.inkMute)),
                ])),
            const SizedBox(width: 12),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.accent.withValues(alpha: 0.2),
                      t.danger.withValues(alpha: 0.1)
                    ]),
                borderRadius: BorderRadius.circular(t.r2),
              ),
              child: item.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(t.r2),
                      child:
                          Image.network(item.coverUrl!, fit: BoxFit.cover))
                  : const Center(
                      child: Text('📰', style: TextStyle(fontSize: 28))),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.elev2))),
            child: Row(children: [
              GestureDetector(
                onTap: () => _toggleLike(context, ref),
                child: Text(
                  '${isLiked ? "❤️" : "🤍"} ${item.likes}',
                  style: TextStyle(fontSize: 11, color: t.inkMute),
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                onTap: () => shareArticle(
                  title: item.title,
                  category: item.category,
                  summary: item.summary,
                ),
                child: Text('↗️ ${l.home_discover_share}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _toggleLike(BuildContext context, WidgetRef ref) async {
    if (!isSignedIn) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.like_login_required)),
      );
      return;
    }
    await ref.read(likesRepoProvider).toggle('article', item.id);
    ref.invalidate(likedArticleIdsProvider);
    ref.invalidate(discoverFeedProvider);
  }
}
```

- [ ] **Step 2: Verify no compile errors**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/home/cards/article_feed_card.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/cards/article_feed_card.dart
git commit -m "feat(ui): add interactive like and share to ArticleFeedCard"
```

---

### Task 10: PostDetailScreen — interactive like + share

**Files:**
- Modify: `lib/features/post/post_detail_screen.dart`

- [ ] **Step 1: Add imports**

Add these imports at the top of `lib/features/post/post_detail_screen.dart`:

```dart
import '../../repositories/likes_repository.dart';
import '../../utils/share_helper.dart';
```

- [ ] **Step 2: Convert `_Body` to ConsumerWidget and add like/share state**

Replace the `_Body` class with a `ConsumerWidget` that reads liked state and passes callbacks:

```dart
class _Body extends ConsumerWidget {
  final Map<String, dynamic> data;
  final AsyncValue<List<Comment>> commentsAsync;
  const _Body({required this.data, required this.commentsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final author = data['author'] as Map<String, dynamic>?;
    final authorName = (author?['name'] as String?) ?? '匿名';
    final body = data['body'] as String? ?? '';
    final rawTags = data['tags'];
    final tags = rawTags is List ? rawTags.cast<String>() : <String>[];
    final likes = (data['likes'] as int?) ?? 0;
    final commentCount = (data['comments'] as int?) ?? 0;
    final shares = (data['shares'] as int?) ?? 0;
    final createdAt = DateTime.parse(data['created_at'] as String);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
    final postId = data['id'] as String;

    final matchCount = data['match_count'] as int?;
    final winCount = data['win_count'] as int?;
    final playDuration = data['play_duration'] as int?;
    final venue = data['venue'] as String?;
    final hasStats = matchCount != null;

    final likedIds = ref.watch(likedPostIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(postId);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // App bar
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.elev2,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new,
                        size: 16, color: t.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasStats ? l.activity_detail_title : l.post_detail_title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Author row
          Row(
            children: [
              Avatar(authorName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: t.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr${venue != null ? ' · $venue' : ''}',
                      style: TextStyle(fontSize: 11, color: t.inkMute),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Body
          Text(
            body,
            style: TextStyle(fontSize: 15, color: t.ink, height: 1.8),
          ),

          // Activity stats
          if (hasStats) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: t.elev2,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(t.r3),
              ),
              child: Row(
                children: [
                  _StatCell(
                    value: '$matchCount',
                    label: l.home_activity_matches,
                    accent: t.accent,
                  ),
                  _StatCell(
                    value: '${winCount ?? 0}W',
                    label: l.home_activity_record,
                  ),
                  _StatCell(
                    value: playDuration != null
                        ? '${(playDuration / 60).toStringAsFixed(1)}h'
                        : '—',
                    label: l.home_activity_duration,
                  ),
                ],
              ),
            ),
          ],

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: t.elev2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('#$tag',
                            style:
                                TextStyle(fontSize: 12, color: t.accent)),
                      ))
                  .toList(),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: t.line, height: 1),
          const SizedBox(height: 16),

          // Interaction stats — now interactive
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!isSignedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.like_login_required)),
                    );
                    return;
                  }
                  ref.read(likesRepoProvider).toggle('post', postId).then((_) {
                    ref.invalidate(likedPostIdsProvider);
                    ref.invalidate(postDetailProvider(postId));
                  });
                },
                child: _InteractionBtn(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '$likes',
                    color: isLiked ? t.danger : t.inkSub),
              ),
              const SizedBox(width: 28),
              _InteractionBtn(
                  icon: Icons.chat_bubble_outline,
                  label: '$commentCount',
                  color: t.inkSub),
              const SizedBox(width: 28),
              GestureDetector(
                onTap: () => sharePost(
                  authorName: authorName,
                  body: body,
                  tags: tags,
                ),
                child: _InteractionBtn(
                    icon: Icons.share_outlined,
                    label: '$shares',
                    color: t.inkSub),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: t.line, height: 1),
          const SizedBox(height: 20),

          // Comments section
          Label('${l.post_comments_title} · $commentCount'),
          const SizedBox(height: 14),

          // Real comments list
          ...commentsAsync.when(
            data: (list) => list.isEmpty
                ? [
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 20),
                        child: Text(l.post_no_comments,
                            style: TextStyle(
                                fontSize: 13, color: t.inkDim)),
                      ),
                    ),
                  ]
                : list
                    .map<Widget>(
                        (c) => _CommentTile(comment: c))
                    .toList(),
            loading: () => [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: t.accent, strokeWidth: 2),
                  ),
                ),
              ),
            ],
            error: (_, _) => [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(l.error_load_failed,
                      style:
                          TextStyle(fontSize: 12, color: t.inkSub)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify no compile errors**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/post/post_detail_screen.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/post/post_detail_screen.dart
git commit -m "feat(ui): add interactive like and share to PostDetailScreen"
```

---

### Task 11: ArticleDetailScreen — add like + share

**Files:**
- Modify: `lib/features/article/article_detail_screen.dart`

- [ ] **Step 1: Add imports**

Add these imports at the top of `lib/features/article/article_detail_screen.dart`:

```dart
import '../../repositories/likes_repository.dart';
import '../../utils/share_helper.dart';
```

- [ ] **Step 2: Convert `_Body` to ConsumerWidget and add like/share row**

Replace the `_Body` class. The key change is: `_Body` becomes `ConsumerWidget`, and after the existing stats row (`👁 viewCount · 💬 commentCount`) we add a new interactive row with like and share buttons.

Replace the stats row block in `_Body.build()` — find the existing `Row` with view count and comment count, and replace it plus add the like/share row after:

Find this block in the `_Body` build method (inside the `SliverToBoxAdapter` child Column):

```dart
                Row(
                  children: [
                    Text('👁 ${article.viewCount}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                    const SizedBox(width: 14),
                    Text('💬 ${article.commentCount}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                  ],
                ),
```

Replace with:

```dart
                Row(
                  children: [
                    Text('👁 ${article.viewCount}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                    const SizedBox(width: 14),
                    Text('💬 ${article.commentCount}',
                        style: TextStyle(fontSize: 11, color: t.inkMute)),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () {
                        if (!isSignedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l.like_login_required)),
                          );
                          return;
                        }
                        ref.read(likesRepoProvider).toggle('article', article.id).then((_) {
                          ref.invalidate(likedArticleIdsProvider);
                          ref.invalidate(articleDetailProvider(article.id));
                        });
                      },
                      child: Text(
                        '${isLiked ? "❤️" : "🤍"} ${article.likes}',
                        style: TextStyle(fontSize: 11, color: t.inkMute),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => shareArticle(
                        title: article.title,
                        category: _categoryLabel(context, article.category),
                        summary: article.summary,
                      ),
                      child: Text('↗️ ${l.common_share}',
                          style: TextStyle(fontSize: 11, color: t.inkMute)),
                    ),
                  ],
                ),
```

The `_Body` class needs these changes:
1. Change `extends StatelessWidget` to `extends ConsumerWidget`
2. Change `Widget build(BuildContext context)` to `Widget build(BuildContext context, WidgetRef ref)`
3. Add at the start of build: `final likedIds = ref.watch(likedArticleIdsProvider).valueOrNull ?? {};` and `final isLiked = likedIds.contains(article.id);`

- [ ] **Step 3: Verify no compile errors**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/article/article_detail_screen.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/article/article_detail_screen.dart
git commit -m "feat(ui): add interactive like and share to ArticleDetailScreen"
```

---

### Task 12: Final verification

- [ ] **Step 1: Run full project analysis**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze
```

Expected: No errors. Warnings/info are acceptable.

- [ ] **Step 2: Verify build compiles**

```bash
cd /home/coder/workspaces/qiuju_app && flutter build apk --debug 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: resolve any analysis issues from like-share feature"
```
