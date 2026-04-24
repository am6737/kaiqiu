# Profile Content Tabs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the "我的" profile page from a settings-menu layout into a content-driven social profile with three tabs (动态 / 帖子 / 文章) to display the user's own content.

**Architecture:** Replace the current `ListView`-based `ProfileScreen` with a `NestedScrollView` containing a `SliverAppBar` (identity header + archive banner) and a sticky `TabBar`. Each tab body is a lazy-loaded list of feed cards (`ActivityFeedCard`, `PostFeedCard`, `ArticleFeedCard`). Settings and management entries move to a dedicated settings hub page reachable from a gear icon. Three new Riverpod `FutureProvider`s fetch user-owned posts, articles, and activities from Supabase by `author_id`.

**Tech Stack:** Flutter 3.x, Riverpod, GoRouter, Supabase (Postgres), existing design token system (`AppTokens`)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `lib/features/profile/profile_settings_screen.dart` | New settings hub page — contains the activity entries (赛事/球局/场馆/队伍/收藏) and settings entries (账号/通知/外观/帮助/关于) + logout, extracted from old profile_screen |
| Modify | `lib/features/profile/profile_screen.dart` | Complete rewrite → NestedScrollView + TabBar (动态/帖子/文章) with identity header |
| Modify | `lib/providers.dart` | Add `myPostsProvider`, `myArticlesProvider`, `myActivitiesProvider` |
| Modify | `lib/repositories/feed_repository.dart` | Add `myPosts()`, `myArticles()`, `myActivities()` methods |
| Modify | `lib/routes.dart` | Add `/me/settings` route |
| Modify | `lib/l10n/app_zh.arb` | Add new l10n keys for tabs, empty states, settings page title |
| Modify | `lib/l10n/app_en.arb` | Add matching English l10n keys |

---

## Task 1: Add data-fetching methods to FeedRepository

**Files:**
- Modify: `lib/repositories/feed_repository.dart`

- [ ] **Step 1: Add `myActivities()` method**

```dart
/// Activities (posts with stats) authored by the current user.
Future<List<FeedActivity>> myActivities({int limit = 50}) async {
  final uid = currentUserId;
  if (uid == null) return [];
  final rows = await supabase
      .from('posts')
      .select('*, author:profiles!author_id(name)')
      .eq('author_id', uid)
      .not('match_count', 'is', null)
      .order('created_at', ascending: false)
      .limit(limit);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(FeedActivity.fromMap)
      .toList();
}
```

- [ ] **Step 2: Add `myPosts()` method**

```dart
/// Plain posts (no activity stats) authored by the current user.
Future<List<FeedPost>> myPosts({int limit = 50}) async {
  final uid = currentUserId;
  if (uid == null) return [];
  final rows = await supabase
      .from('posts')
      .select('*, author:profiles!author_id(name)')
      .eq('author_id', uid)
      .is_('match_count', null)
      .order('created_at', ascending: false)
      .limit(limit);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(FeedPost.fromMap)
      .toList();
}
```

Note: Supabase Dart uses `.isFilter('match_count', null)` — verify the correct method name in the project's Supabase client version. The `_recentActivities` method in the same file already uses the posts table with `author:profiles!author_id(name)` select pattern.

- [ ] **Step 3: Add `myArticles()` method**

```dart
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
```

- [ ] **Step 4: Add the `supabase.dart` import at the top of feed_repository.dart**

The file already imports `../services/supabase.dart` (line 3), so `currentUserId` is available. Verify this — if not, add the import.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/feed_repository.dart
git commit -m "feat(profile): add myActivities/myPosts/myArticles to FeedRepository"
```

---

## Task 2: Add Riverpod providers for user's own content

**Files:**
- Modify: `lib/providers.dart`

- [ ] **Step 1: Add three providers after the existing "My content providers" section (around line 374)**

```dart
/// 我的动态 — activities authored by current user (posts with stats).
final myActivitiesProvider = FutureProvider<List<FeedActivity>>((ref) async {
  return ref.read(feedRepoProvider).myActivities();
});

/// 我的帖子 — plain posts authored by current user (no activity stats).
final myPostsProvider = FutureProvider<List<FeedPost>>((ref) async {
  return ref.read(feedRepoProvider).myPosts();
});

/// 我的文章 — articles authored by current user.
final myArticlesProvider = FutureProvider<List<FeedArticle>>((ref) async {
  return ref.read(feedRepoProvider).myArticles();
});
```

These use the existing `FeedActivity`, `FeedPost`, `FeedArticle` types already imported at line 8 (`import 'models/feed.dart'`).

- [ ] **Step 2: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(profile): add myActivities/myPosts/myArticles providers"
```

---

## Task 3: Add l10n keys

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add keys to app_zh.arb**

Add these after the existing `profile_` keys (around line 460):

```json
"profile_tab_activities": "动态",
"profile_tab_posts": "帖子",
"profile_tab_articles": "文章",
"profile_empty_activities": "还没发过动态",
"profile_empty_activities_sub": "踢完球后记录一下运动数据吧",
"profile_empty_posts": "还没发过帖子",
"profile_empty_posts_sub": "分享你的足球故事",
"profile_empty_articles": "还没写过文章",
"profile_empty_articles_sub": "写一篇战术分析或赛事回顾",
"profile_settings_title": "设置与管理",
```

- [ ] **Step 2: Add matching keys to app_en.arb**

```json
"profile_tab_activities": "Activities",
"profile_tab_posts": "Posts",
"profile_tab_articles": "Articles",
"profile_empty_activities": "No activities yet",
"profile_empty_activities_sub": "Record your match stats after a game",
"profile_empty_posts": "No posts yet",
"profile_empty_posts_sub": "Share your football stories",
"profile_empty_articles": "No articles yet",
"profile_empty_articles_sub": "Write a tactical analysis or match review",
"profile_settings_title": "Settings",
```

- [ ] **Step 3: Run l10n code generation**

```bash
cd /home/coder/workspaces/qiuju_app && flutter gen-l10n
```

Expected: generates updated files in `lib/l10n/generated/`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add profile tab and empty state strings"
```

---

## Task 4: Create the settings hub page

**Files:**
- Create: `lib/features/profile/profile_settings_screen.dart`

This page takes all the menu items that currently live in `profile_screen.dart` (activity entries + settings entries + logout) and puts them in their own screen.

- [ ] **Step 1: Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final teammatesAsync = ref.watch(teammatesProvider);

    final regEventsCount =
        ref.watch(myRegisteredEventsProvider).valueOrNull?.length ?? 0;
    final hostedEventsCount =
        ref.watch(myHostedEventsProvider).valueOrNull?.length ?? 0;
    final eventsCount = regEventsCount + hostedEventsCount;
    final hostedPickupsCount =
        ref.watch(myHostedPickupsProvider).valueOrNull?.length ?? 0;
    final joinedPickupsCount =
        ref.watch(myJoinedPickupsProvider).valueOrNull?.length ?? 0;
    final pickupsCount = hostedPickupsCount + joinedPickupsCount;
    final venuesCount = ref.watch(myVenuesProvider).valueOrNull?.length ?? 0;

    final activity = <_MenuItem>[
      _MenuItem(
        icon: Icons.calendar_today,
        label: l.profile_menu_my_events,
        badge: eventsCount > 0 ? '$eventsCount' : null,
        onTap: () => context.push('/me/events'),
      ),
      _MenuItem(
        icon: Icons.map_outlined,
        label: l.profile_menu_my_pickups,
        badge: pickupsCount > 0 ? '$pickupsCount' : null,
        onTap: () => context.push('/me/pickups'),
      ),
      _MenuItem(
        icon: Icons.stadium_outlined,
        label: '我的场馆',
        badge: venuesCount > 0 ? '$venuesCount' : null,
        onTap: () => context.push('/me/venues'),
      ),
      _MenuItem(
        icon: Icons.person_outline,
        label: l.profile_menu_my_teams,
        badge: (teammatesAsync.valueOrNull?.length ?? 0) > 0
            ? '${teammatesAsync.valueOrNull?.length ?? 0}'
            : null,
        onTap: () => context.push('/me/teams'),
      ),
      _MenuItem(
        icon: Icons.bookmark_border,
        label: l.profile_menu_favorites,
        onTap: () => context.push('/me/favorites'),
      ),
    ];

    final settings = <_MenuItem>[
      _MenuItem(
        icon: Icons.settings_outlined,
        label: l.profile_menu_account,
        onTap: () => context.push('/settings/account'),
      ),
      _MenuItem(
        icon: Icons.notifications_none,
        label: l.profile_menu_notif,
        onTap: () => context.push('/settings/notifications'),
      ),
      _MenuItem(
        icon: Icons.palette_outlined,
        label: l.profile_menu_appearance,
        onTap: () => context.push('/settings/appearance'),
      ),
      _MenuItem(
        icon: Icons.chat_bubble_outline,
        label: l.profile_menu_help,
        onTap: () => context.push('/settings/help'),
      ),
      _MenuItem(
        icon: Icons.emoji_events_outlined,
        label: l.profile_menu_about,
        trailing: 'v0.1',
        onTap: () => context.push('/settings/about'),
      ),
    ];

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.profile_settings_title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _EntrySection(
                    title: l.profile_section_activity,
                    items: activity,
                  ),
                  _EntrySection(
                    title: l.profile_section_settings,
                    items: settings,
                  ),
                  // Sign-out
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: GestureDetector(
                      onTap: () async {
                        final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: t.elev2,
                                content: Text(
                                  l.profile_logout_confirm,
                                  style: TextStyle(color: t.ink),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(
                                      l.common_cancel,
                                      style: TextStyle(color: t.inkSub),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(
                                      l.settings_account_logout,
                                      style: TextStyle(color: t.danger),
                                    ),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (!ok) return;
                        await supabase.auth.signOut();
                        await LocalStore.setRemember(false, null);
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.elev2,
                          border: Border.all(color: t.line),
                          borderRadius: BorderRadius.circular(t.r2),
                        ),
                        child: Text(
                          l.profile_logout,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.danger,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? badge;
  final String? trailing;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.trailing,
    this.onTap,
  });
}

class _EntrySection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _EntrySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.inkSub,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: t.elev2,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(t.r2),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++)
                  _row(context, items[i], i > 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _MenuItem item, bool divider) {
    final t = context.tokens;
    return InkWell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: divider
            ? BoxDecoration(
                border:
                    Border(top: BorderSide(color: t.line, width: 1)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.elev3,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(item.icon, size: 14, color: t.inkSub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  color: t.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: t.elev3,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.badge!,
                  style: TextStyle(
                    fontFamily: t.fontMono,
                    fontFamilyFallback: t.monoFallbacks,
                    fontSize: 10,
                    color: t.inkSub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (item.trailing != null) ...[
              Text(
                item.trailing!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.inkSub,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 14, color: t.inkDim),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/profile/profile_settings_screen.dart
git commit -m "feat(profile): create settings hub page extracted from profile"
```

---

## Task 5: Add the `/me/settings` route

**Files:**
- Modify: `lib/routes.dart`

- [ ] **Step 1: Add import at the top of routes.dart**

After the existing profile imports (around line 33):

```dart
import 'features/profile/profile_settings_screen.dart';
```

- [ ] **Step 2: Add the route**

After the `/me/favorites` route (around line 211), add:

```dart
GoRoute(path: '/me/settings', builder: (_, s) => const ProfileSettingsScreen()),
```

- [ ] **Step 3: Commit**

```bash
git add lib/routes.dart
git commit -m "feat(routes): add /me/settings route"
```

---

## Task 6: Rewrite profile_screen.dart with NestedScrollView + TabBar

**Files:**
- Modify: `lib/features/profile/profile_screen.dart`

This is the main task. The new screen structure:

```
NestedScrollView
├── SliverAppBar (pinned: false, floating: false)
│   └── FlexibleSpaceBar content:
│       ├── Title row with gear icon (right)
│       ├── Centered avatar
│       ├── Name + handle
│       ├── Following / Followers stats
│       ├── [编辑资料] + [球员档案 →] buttons
│       └── bottom: TabBar (动态 / 帖子 / 文章) — pinned
└── TabBarView
    ├── _ActivitiesTab (list of ActivityFeedCard)
    ├── _PostsTab (list of PostFeedCard)
    └── _ArticlesTab (list of ArticleFeedCard)
```

- [ ] **Step 1: Replace the entire file content**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/feed.dart';
import '../../models/player_profile.dart';
import '../../providers.dart';
import '../../services/storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/avatar_picker_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../home/cards/activity_feed_card.dart';
import '../home/cards/article_feed_card.dart';
import '../home/cards/post_feed_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(PlayerProfile? profile) async {
    final result = await showAvatarPickerSheet(
      context,
      current: profile?.avatarUrl,
      name: profile?.name ?? '',
    );
    if (result == null || !mounted) return;

    final uid = currentUserId;
    if (uid == null) return;

    try {
      String? newUrl;
      if (result == kUploadCustom) {
        newUrl = await StorageService().pickCropCompressAndUpload(
          bucket: 'avatars',
          pathPrefix: uid,
          square: true,
        );
        if (newUrl == null || !mounted) return;
      } else {
        newUrl = result;
      }

      await ref.read(profilesRepoProvider).update(uid, {'avatar_url': newUrl});
      ref.invalidate(myProfileProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final PlayerProfile? u = ref.watch(myProfileProvider).valueOrNull;
    ref.watch(localStoreProvider);

    final followingCount = ref.watch(followingCountProvider);
    final followersCount =
        ref.watch(followersCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Title row with gear icon
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.profile_title,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/me/settings'),
                          icon: Icon(
                            Icons.settings_outlined,
                            size: 22,
                            color: t.inkSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Centered avatar
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _pickAvatar(u),
                        child: NetworkAvatar(
                          u?.name ?? '新球友',
                          url: u?.avatarUrl,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                  // Name
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        u?.name ?? '新球友',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Center(
                      child: Text(
                        u?.handle ?? '',
                        style: TextStyle(
                          fontFamily: t.fontMono,
                          fontFamilyFallback: t.monoFallbacks,
                          fontSize: 13,
                          color: t.inkSub,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  // Stats row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/me/following'),
                            child: _StatColumn(
                              count: followingCount,
                              label: l.profile_following,
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: t.line,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                context.push('/me/following?tab=1'),
                            child: _StatColumn(
                              count: followersCount,
                              label: l.profile_followers,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: l.profile_edit_btn,
                            variant: BtnVariant.ghost,
                            size: BtnSize.md,
                            full: true,
                            onPressed: () => context.push('/profile/edit'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => context.push('/archive'),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            decoration: BoxDecoration(
                              color: t.accentSubtle,
                              border: Border.all(
                                  color: t.accent.withAlpha(0x66)),
                              borderRadius:
                                  BorderRadius.circular(t.r2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  u?.position ?? '',
                                  style: TextStyle(
                                    fontFamily: t.fontMono,
                                    fontFamilyFallback:
                                        t.monoFallbacks,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: t.accent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: t.accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Sticky TabBar
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  labelColor: t.ink,
                  unselectedLabelColor: t.inkDim,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  indicatorColor: t.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: t.line,
                  tabs: [
                    Tab(text: l.profile_tab_activities),
                    Tab(text: l.profile_tab_posts),
                    Tab(text: l.profile_tab_articles),
                  ],
                ),
                backgroundColor: t.bg,
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: const [
              _ActivitiesTab(),
              _PostsTab(),
              _ArticlesTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab Delegates ──────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _TabBarDelegate({required this.tabBar, required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}

// ─── Activities Tab ─────────────────────────────────────

class _ActivitiesTab extends ConsumerWidget {
  const _ActivitiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myActivitiesProvider);

    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myActivitiesProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                EmptyState(
                  icon: Icons.directions_run,
                  title: l.profile_empty_activities,
                  subtitle: l.profile_empty_activities_sub,
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) => ActivityFeedCard(item: items[i]),
          );
        },
      ),
    );
  }
}

// ─── Posts Tab ───────────────────────────────────────────

class _PostsTab extends ConsumerWidget {
  const _PostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myPostsProvider);

    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myPostsProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: l.profile_empty_posts,
                  subtitle: l.profile_empty_posts_sub,
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) => PostFeedCard(item: items[i]),
          );
        },
      ),
    );
  }
}

// ─── Articles Tab ───────────────────────────────────────

class _ArticlesTab extends ConsumerWidget {
  const _ArticlesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myArticlesProvider);

    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myArticlesProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                EmptyState(
                  icon: Icons.article_outlined,
                  title: l.profile_empty_articles,
                  subtitle: l.profile_empty_articles_sub,
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) => ArticleFeedCard(item: items[i]),
          );
        },
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final int count;
  final String label;
  const _StatColumn({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        N(
          '$count',
          size: 20,
          weight: FontWeight.w800,
          color: context.tokens.ink,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.tokens.inkSub,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze --no-fatal-infos 2>&1 | head -20
```

Expected: No errors in profile_screen.dart.

- [ ] **Step 3: Commit**

```bash
git add lib/features/profile/profile_screen.dart
git commit -m "feat(profile): rewrite as NestedScrollView with content tabs"
```

---

## Task 7: Verify and fix compilation

**Files:**
- Possibly modify any of the above files if compilation issues arise

- [ ] **Step 1: Run flutter analyze**

```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze --no-fatal-infos
```

- [ ] **Step 2: Fix any issues found**

Common issues to watch for:
- `isFilter` vs `is_` method name in Supabase Dart client — check existing usage patterns in the codebase
- l10n generated code may need `flutter gen-l10n` run first
- Import paths may need adjustment
- `PageTitleBar` and `Label` widgets used in the settings screen come from `section_header.dart` and `typography.dart` respectively — verify imports

- [ ] **Step 3: Run the app on web**

```bash
cd /home/coder/workspaces/qiuju_app && flutter run -d chrome --web-port 8080
```

Navigate to the 我的 tab and verify:
1. Identity header shows correctly (avatar, name, handle, following/followers)
2. Gear icon in top-right navigates to settings page
3. Three tabs are visible and sticky
4. Tabs show empty states when no content
5. Edit profile button still works
6. Archive entry (position badge) still links to /archive
7. Pull-to-refresh works on each tab

- [ ] **Step 4: Commit any fixes**

```bash
git add -u
git commit -m "fix(profile): resolve compilation and runtime issues"
```
