# Like & Share for Discover Feed

Date: 2026-04-22

## Problem

Discovery page cards (ActivityFeedCard, PostFeedCard, ArticleFeedCard) and detail screens (PostDetailScreen, ArticleDetailScreen) display like counts and share labels but none of them are interactive. Tapping does nothing.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Like storage | Universal `likes` table (`target_type` + `target_id`) | Matches existing `comments` table pattern; avoids table proliferation |
| Share content | Plain-text summary via `share_plus` | Consistent with existing `sharePickup`/`shareEvent`; no deep-link config needed |
| Scope | Feed cards + detail screens | Complete user experience everywhere content appears |

## 1. Database — `likes` table

```sql
create table likes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'article')),
  target_id   uuid not null,
  created_at  timestamptz not null default now(),
  unique (user_id, target_type, target_id)
);

create index idx_likes_target on likes(target_type, target_id);

alter table likes enable row level security;

create policy "Anyone can read likes"
  on likes for select using (true);

create policy "Authenticated users can insert own likes"
  on likes for insert
  with check (auth.uid() = user_id);

create policy "Users can delete own likes"
  on likes for delete
  using (auth.uid() = user_id);
```

### Trigger — sync `posts.likes` counter

```sql
(See unified trigger in the articles section below.)
```

Articles also need a `likes` column:

```sql
alter table articles add column if not exists likes int not null default 0;
```

The trigger handles both:

```sql
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

## 2. Repository — `LikesRepository`

File: `lib/repositories/likes_repository.dart`

```dart
class LikesRepository {
  Future<void> toggle(String targetType, String targetId);
  Future<bool> isLiked(String targetType, String targetId);
  Future<Set<String>> likedIds(String targetType);
}
```

- **toggle**: check existing row → delete if exists, insert if not (same pattern as `RatingsRepository.toggleLike`)
- **isLiked**: `maybeSingle()` check for current user
- **likedIds**: `select('target_id').eq('target_type', type).eq('user_id', uid)` — returns Set for O(1) lookup in feed

## 3. Providers

```dart
final likesRepoProvider = Provider((_) => LikesRepository());

final likedPostIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(likesRepoProvider).likedIds('post');
});

final likedArticleIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(likesRepoProvider).likedIds('article');
});
```

After a `toggle()` call, invalidate the relevant provider to refresh the feed state.

## 4. Share Helper additions

File: `lib/utils/share_helper.dart`

```dart
Future<void> sharePost({
  required String authorName,
  required String body,
  List<String> tags = const [],
}) async {
  final preview = body.length > 150 ? '${body.substring(0, 150)}...' : body;
  final text = [
    '📝 $authorName 的动态',
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
    '📰 $category | $title',
    if (summary != null) summary,
  ].join('\n');
  await Share.share(text, subject: '开球·文章');
}
```

## 5. UI Changes

### Feed Cards

All three cards (ActivityFeedCard, PostFeedCard, ArticleFeedCard) get:

- **Like button**: `GestureDetector` wrapping the heart label. On tap → optimistic toggle (flip icon to filled red heart, +1/-1 count), call `LikesRepository.toggle()`, on error revert.
- **Share button**: `GestureDetector` wrapping the share label. On tap → call `sharePost()` or `shareArticle()`.
- Cards become `ConsumerWidget` to access providers for liked state.
- ArticleFeedCard gets a new interaction row at the bottom (like + share), similar to PostFeedCard.

### Detail Screens

**PostDetailScreen** `_InteractionBtn` row:
- Like button: wrap in `GestureDetector`, toggle like, show filled/outlined heart icon
- Share button: wrap in `GestureDetector`, call `sharePost()` with data from the post detail map

**ArticleDetailScreen** stats row:
- Add like count + share button alongside existing view count and comment count
- Same toggle + share behavior

## 6. Files to create/modify

| Action | File |
|--------|------|
| Create | `supabase/migrations/0011_likes.sql` |
| Create | `lib/repositories/likes_repository.dart` |
| Modify | `lib/providers.dart` — add likesRepo + likedIds providers |
| Modify | `lib/utils/share_helper.dart` — add sharePost, shareArticle |
| Modify | `lib/features/home/cards/activity_feed_card.dart` — interactive like + share |
| Modify | `lib/features/home/cards/post_feed_card.dart` — interactive like + share |
| Modify | `lib/features/home/cards/article_feed_card.dart` — add interaction row with like + share |
| Modify | `lib/features/post/post_detail_screen.dart` — interactive like + share |
| Modify | `lib/features/article/article_detail_screen.dart` — add like + share |
| Modify | `lib/models/article.dart` — add `likes` field |
