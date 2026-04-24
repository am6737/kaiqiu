# Unified InteractionBtn Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a public `InteractionBtn` widget from the post detail screen and replace all emoji-based interaction buttons across feed cards and article detail with the same Material Icon style.

**Architecture:** Create one new public widget file. Then update 5 existing files to import and use it, replacing emoji text with `InteractionBtn` instances. No logic changes — only visual replacement.

**Tech Stack:** Flutter, Material Icons, Riverpod (existing providers unchanged)

---

### Task 1: Create public InteractionBtn widget

**Files:**
- Create: `lib/widgets/interaction_btn.dart`

- [ ] **Step 1: Create the widget file**

```dart
// lib/widgets/interaction_btn.dart
import 'package:flutter/material.dart';

class InteractionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const InteractionBtn(
      {super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `dart analyze lib/widgets/interaction_btn.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/interaction_btn.dart
git commit -m "feat(widgets): extract public InteractionBtn component"
```

---

### Task 2: Update post_detail_screen.dart to use public InteractionBtn

**Files:**
- Modify: `lib/features/post/post_detail_screen.dart`

- [ ] **Step 1: Add import**

Add this import after the existing imports (around line 14):

```dart
import '../../widgets/interaction_btn.dart';
```

- [ ] **Step 2: Replace all `_InteractionBtn` references with `InteractionBtn`**

In the interaction row (lines 346, 352-355, 363-366), replace `_InteractionBtn` with `InteractionBtn`. There are 3 usages:

Line 346:
```dart
// before
child: _InteractionBtn(
// after
child: InteractionBtn(
```

Lines 352-355:
```dart
// before
_InteractionBtn(
    icon: Icons.chat_bubble_outline,
    label: '$commentCount',
    color: t.inkSub),
// after
InteractionBtn(
    icon: Icons.chat_bubble_outline,
    label: '$commentCount',
    color: t.inkSub),
```

Lines 363-366:
```dart
// before
child: _InteractionBtn(
// after
child: InteractionBtn(
```

- [ ] **Step 3: Delete the private `_InteractionBtn` class**

Delete lines 503-521 (the entire `_InteractionBtn` class at the bottom of the file):

```dart
// DELETE THIS ENTIRE BLOCK:
class _InteractionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InteractionBtn(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify no analysis errors**

Run: `dart analyze lib/features/post/post_detail_screen.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/features/post/post_detail_screen.dart
git commit -m "refactor(post): use public InteractionBtn in post detail"
```

---

### Task 3: Update post_feed_card.dart

**Files:**
- Modify: `lib/features/home/cards/post_feed_card.dart`

- [ ] **Step 1: Add import**

Add after the existing imports (after line 10):

```dart
import '../../../widgets/interaction_btn.dart';
```

- [ ] **Step 2: Replace the interaction row**

Replace lines 77-97 (the Row inside the bottom Container) with:

```dart
child: Row(children: [
  GestureDetector(
    onTap: () => _toggleLike(context, ref),
    child: InteractionBtn(
        icon: isLiked ? Icons.favorite : Icons.favorite_border,
        label: '${item.likes}',
        color: isLiked ? t.danger : t.inkSub),
  ),
  const SizedBox(width: 18),
  InteractionBtn(
      icon: Icons.chat_bubble_outline,
      label: '${item.comments}',
      color: t.inkSub),
  const SizedBox(width: 18),
  GestureDetector(
    onTap: () => sharePost(
      authorName: item.authorName,
      body: item.body,
      tags: item.tags,
    ),
    child: InteractionBtn(
        icon: Icons.share_outlined,
        label: l.home_discover_share,
        color: t.inkSub),
  ),
]),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `dart analyze lib/features/home/cards/post_feed_card.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/cards/post_feed_card.dart
git commit -m "refactor(home): use InteractionBtn in post feed card"
```

---

### Task 4: Update activity_feed_card.dart

**Files:**
- Modify: `lib/features/home/cards/activity_feed_card.dart`

- [ ] **Step 1: Add import**

Add after the existing imports (after line 10):

```dart
import '../../../widgets/interaction_btn.dart';
```

- [ ] **Step 2: Replace the interaction row**

Replace lines 98-118 (the Row inside the bottom Container) with:

```dart
child: Row(children: [
  GestureDetector(
    onTap: () => _toggleLike(context, ref),
    child: InteractionBtn(
        icon: isLiked ? Icons.favorite : Icons.favorite_border,
        label: '${item.likes}',
        color: isLiked ? t.danger : t.inkSub),
  ),
  const SizedBox(width: 18),
  InteractionBtn(
      icon: Icons.chat_bubble_outline,
      label: '${item.comments}',
      color: t.inkSub),
  const SizedBox(width: 18),
  GestureDetector(
    onTap: () => sharePost(
      authorName: item.authorName,
      body: item.body,
      tags: item.tags,
    ),
    child: InteractionBtn(
        icon: Icons.share_outlined,
        label: l.home_discover_share,
        color: t.inkSub),
  ),
]),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `dart analyze lib/features/home/cards/activity_feed_card.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/cards/activity_feed_card.dart
git commit -m "refactor(home): use InteractionBtn in activity feed card"
```

---

### Task 5: Update article_feed_card.dart

**Files:**
- Modify: `lib/features/home/cards/article_feed_card.dart`

- [ ] **Step 1: Add import**

Add after the existing imports (after line 10):

```dart
import '../../../widgets/interaction_btn.dart';
```

- [ ] **Step 2: Replace the interaction row**

Replace lines 93-118 (the Row inside the bottom Container) with:

```dart
child: Row(children: [
  GestureDetector(
    onTap: () => _toggleLike(context, ref),
    child: InteractionBtn(
        icon: isLiked ? Icons.favorite : Icons.favorite_border,
        label: '${item.likes}',
        color: isLiked ? t.danger : t.inkSub),
  ),
  const SizedBox(width: 18),
  GestureDetector(
    onTap: () => _toggleFavorite(context, ref),
    child: InteractionBtn(
        icon: isFav ? Icons.bookmark : Icons.bookmark_border,
        label: isFav ? l.common_unfavorite : l.common_favorite,
        color: isFav ? t.danger : t.inkSub),
  ),
  const SizedBox(width: 18),
  GestureDetector(
    onTap: () => shareArticle(
      title: item.title,
      category: item.category,
      summary: item.summary,
    ),
    child: InteractionBtn(
        icon: Icons.share_outlined,
        label: l.home_discover_share,
        color: t.inkSub),
  ),
]),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `dart analyze lib/features/home/cards/article_feed_card.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/cards/article_feed_card.dart
git commit -m "refactor(home): use InteractionBtn in article feed card"
```

---

### Task 6: Update article_detail_screen.dart

**Files:**
- Modify: `lib/features/article/article_detail_screen.dart`

- [ ] **Step 1: Add import**

Add after the existing imports (around line 15):

```dart
import '../../widgets/interaction_btn.dart';
```

- [ ] **Step 2: Replace the stats/interaction row**

Replace lines 307-361 (the Row containing view count, comment, like, bookmark, share) with:

```dart
Row(
  children: [
    InteractionBtn(
        icon: Icons.visibility_outlined,
        label: '${article.viewCount}',
        color: t.inkSub),
    const SizedBox(width: 28),
    InteractionBtn(
        icon: Icons.chat_bubble_outline,
        label: '${article.commentCount}',
        color: t.inkSub),
    const SizedBox(width: 28),
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
      child: InteractionBtn(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: '${article.likes}',
          color: isLiked ? t.danger : t.inkSub),
    ),
    const SizedBox(width: 28),
    GestureDetector(
      onTap: () {
        if (!isSignedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.like_login_required)),
          );
          return;
        }
        ref.read(favoritesRepoProvider).toggle(FavoriteEntity.article, article.id).then((_) {
          ref.invalidate(favoriteArticleIdsProvider);
        });
      },
      child: InteractionBtn(
          icon: isFav ? Icons.bookmark : Icons.bookmark_border,
          label: isFav ? l.common_unfavorite : l.common_favorite,
          color: isFav ? t.danger : t.inkSub),
    ),
    const SizedBox(width: 28),
    GestureDetector(
      onTap: () => shareArticle(
        title: article.title,
        category: _categoryLabel(context, article.category),
        summary: article.summary,
      ),
      child: InteractionBtn(
          icon: Icons.share_outlined,
          label: l.common_share,
          color: t.inkSub),
    ),
  ],
),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `dart analyze lib/features/article/article_detail_screen.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/features/article/article_detail_screen.dart
git commit -m "refactor(article): use InteractionBtn in article detail"
```

---

### Task 7: Replace emoji in article_feed_card meta line

**Files:**
- Modify: `lib/features/home/cards/article_feed_card.dart`

- [ ] **Step 1: Replace emoji meta text**

Line 62 currently reads:
```dart
Text(
    '👁 ${item.viewCount} · 💬 ${item.commentCount} · ${l.home_article_read_time(item.readTimeMin)}',
    style: TextStyle(fontSize: 10, color: t.inkMute)),
```

Replace with a Row using small Icons for consistency:
```dart
Row(children: [
  Icon(Icons.visibility_outlined, size: 12, color: t.inkMute),
  const SizedBox(width: 3),
  Text('${item.viewCount}',
      style: TextStyle(fontSize: 10, color: t.inkMute)),
  Text(' · ', style: TextStyle(fontSize: 10, color: t.inkMute)),
  Icon(Icons.chat_bubble_outline, size: 12, color: t.inkMute),
  const SizedBox(width: 3),
  Text('${item.commentCount}',
      style: TextStyle(fontSize: 10, color: t.inkMute)),
  Text(' · ', style: TextStyle(fontSize: 10, color: t.inkMute)),
  Text(l.home_article_read_time(item.readTimeMin),
      style: TextStyle(fontSize: 10, color: t.inkMute)),
]),
```

- [ ] **Step 2: Verify no analysis errors**

Run: `dart analyze lib/features/home/cards/article_feed_card.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/cards/article_feed_card.dart
git commit -m "refactor(home): replace emoji with icons in article card meta"
```

---

### Task 8: Final verification

- [ ] **Step 1: Run full project analysis**

Run: `dart analyze lib/`
Expected: No issues found (or only pre-existing warnings unrelated to this change)

- [ ] **Step 2: Build check**

Run: `flutter build apk --debug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit if any fixes were needed**

Only if analysis or build revealed issues that required fixes.
