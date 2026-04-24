# Content Creation Feature — Design Spec

## Goal

Add content creation capability to the QiuJu app: a FAB entry point on the profile page, a post creation screen (with optional activity/stats mode), and an article creation screen. Includes data layer (repositories, providers) and a Supabase RLS migration for articles.

## Architecture

Two new full-screen pages (`CreatePostScreen`, `CreateArticleScreen`) follow the same `ConsumerStatefulWidget` + form pattern used by `CreatePickupScreen`. A FAB on `ProfileScreen` opens a bottom sheet to choose which content type to create. Two new repositories (`PostsRepository`, `ArticlesRepository`) handle INSERT operations. Three new providers expose the create methods.

## Components

### 1. Profile FAB Entry Point

**Location:** `lib/features/profile/profile_screen.dart`

Add a `FloatingActionButton` to the existing `Scaffold`. On tap, show a modal bottom sheet with two options:

| Option | Icon | Label (zh) | Route |
|--------|------|-------------|-------|
| Post | `Icons.edit_note` | 发帖子 | `/create-post` |
| Article | `Icons.article_outlined` | 写文章 | `/create-article` |

Bottom sheet style: use `showModalBottomSheet` with `elev2` background, two `ListTile`-style rows, consistent with app design tokens.

### 2. CreatePostScreen

**File:** `lib/features/post/create_post_screen.dart`
**Route:** `/create-post`

**Layout:**
- Top bar: `PageTitleBar` with title "发帖子", back button, and a "发布" action button (right side)
- Body text: `TextField` multi-line, min 3 lines, placeholder "写点什么..."
- Tags section: horizontal chips for added tags + text field to add new ones. Below that, show hot tags from `hotTagsProvider` as tappable chips.
- Activity toggle: a `SwitchListTile` "添加运动数据". When on, expand 4 fields:
  - 场次 (`match_count`) — int input
  - 胜场 (`win_count`) — int input
  - 时长(分钟) (`play_duration`) — int input
  - 场馆 (`venue`) — text input

**Validation:**
- Body is required (non-empty after trim)
- If activity toggle is on, match_count is required
- Publish button disabled while submitting

**On submit:**
- Call `PostsRepository.create(...)` with body, tags, and optional stats fields
- On success: show toast "已发布", invalidate `myPostsProvider`, `myActivitiesProvider`, `discoverFeedProvider`, `recommendFeedProvider`, then `context.pop()`
- On error: show toast with error message

### 3. CreateArticleScreen

**File:** `lib/features/article/create_article_screen.dart`
**Route:** `/create-article`

**Layout:**
- Top bar: `PageTitleBar` with title "写文章", back button, and a "发布" action button
- Title: `TextField` single line, placeholder "文章标题"
- Category: `DropdownButtonFormField` with options:
  - `analysis` — 战术分析
  - `review` — 赛事回顾
  - `news` — 资讯
  - `opinion` — 观点
  - Default: `analysis`
- Summary: `TextField` single line, optional, placeholder "一句话摘要（选填）"
- Body: `TextField` multi-line, min 8 lines, placeholder "正文..."

**Validation:**
- Title required
- Body required
- Publish button disabled while submitting

**On submit:**
- Call `ArticlesRepository.create(...)` with title, category, summary, body
- On success: show toast "已发布", invalidate `myArticlesProvider`, `discoverFeedProvider`, `recommendFeedProvider`, then `context.pop()`
- On error: show toast with error message

### 4. Data Layer

#### PostsRepository

**File:** `lib/repositories/posts_repository.dart`

```dart
class PostsRepository {
  Future<void> create({
    required String body,
    List<String> tags = const [],
    int? matchCount,
    int? winCount,
    int? playDuration,
    String? venue,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    await supabase.from('posts').insert({
      'author_id': uid,
      'body': body,
      'tags': tags,
      if (matchCount != null) 'match_count': matchCount,
      if (winCount != null) 'win_count': winCount,
      if (playDuration != null) 'play_duration': playDuration,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
    });
  }
}
```

#### ArticlesRepository

**File:** `lib/repositories/articles_repository.dart`

```dart
class ArticlesRepository {
  Future<void> create({
    required String title,
    required String body,
    String category = 'analysis',
    String? summary,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    await supabase.from('articles').insert({
      'author_id': uid,
      'title': title,
      'body': body,
      'category': category,
      if (summary != null && summary.isNotEmpty) 'summary': summary,
    });
  }
}
```

#### Providers

**File:** `lib/providers.dart` — add repository providers:

```dart
final postsRepoProvider = Provider((_) => PostsRepository());
final articlesRepoProvider = Provider((_) => ArticlesRepository());
```

### 5. Supabase Migration

**File:** `supabase/migrations/0014_articles_rls.sql`

```sql
create policy "articles self insert" on public.articles for insert
  with check (auth.uid() = author_id);
create policy "articles self update" on public.articles for update
  using (auth.uid() = author_id);
create policy "articles self delete" on public.articles for delete
  using (auth.uid() = author_id);
```

### 6. Routes

**File:** `lib/routes.dart` — add:

```dart
GoRoute(path: '/create-post', builder: (_, s) => const CreatePostScreen()),
GoRoute(path: '/create-article', builder: (_, s) => const CreateArticleScreen()),
```

### 7. L10n Keys

**New keys needed:**

| Key | ZH | EN |
|-----|----|----|
| `create_post_title` | 发帖子 | New Post |
| `create_post_body_hint` | 写点什么... | What's on your mind... |
| `create_post_tags_hint` | 添加标签 | Add tag |
| `create_post_hot_tags` | 热门标签 | Trending |
| `create_post_activity_toggle` | 添加运动数据 | Add activity data |
| `create_post_match_count` | 场次 | Matches |
| `create_post_win_count` | 胜场 | Wins |
| `create_post_duration` | 时长(分钟) | Duration (min) |
| `create_post_venue` | 场馆 | Venue |
| `create_post_published` | 已发布 | Published |
| `create_post_body_required` | 请输入内容 | Content is required |
| `create_article_title` | 写文章 | New Article |
| `create_article_title_hint` | 文章标题 | Article title |
| `create_article_category` | 分类 | Category |
| `create_article_summary_hint` | 一句话摘要（选填） | Brief summary (optional) |
| `create_article_body_hint` | 正文... | Body... |
| `create_article_published` | 已发布 | Published |
| `create_article_title_required` | 请输入标题 | Title is required |
| `create_article_body_required` | 请输入正文 | Body is required |
| `create_article_cat_analysis` | 战术分析 | Tactical Analysis |
| `create_article_cat_review` | 赛事回顾 | Match Review |
| `create_article_cat_news` | 资讯 | News |
| `create_article_cat_opinion` | 观点 | Opinion |
| `profile_fab_post` | 发帖子 | New Post |
| `profile_fab_article` | 写文章 | New Article |
| `common_publish` | 发布 | Publish |

## File Map Summary

| Action | File |
|--------|------|
| Create | `lib/repositories/posts_repository.dart` |
| Create | `lib/repositories/articles_repository.dart` |
| Create | `lib/features/post/create_post_screen.dart` |
| Create | `lib/features/article/create_article_screen.dart` |
| Create | `supabase/migrations/0014_articles_rls.sql` |
| Modify | `lib/features/profile/profile_screen.dart` (add FAB) |
| Modify | `lib/providers.dart` (add repo providers) |
| Modify | `lib/routes.dart` (add routes) |
| Modify | `lib/l10n/app_zh.arb` + `app_en.arb` (add keys) |
