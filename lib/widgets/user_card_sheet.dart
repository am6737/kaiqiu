import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/feed.dart';
import '../providers.dart';
import '../repositories/favorites_repository.dart';
import '../services/local_storage.dart';
import '../services/supabase.dart';
import '../theme/app_tokens.dart';
import '../utils/toast.dart';
import 'network_avatar.dart';
import 'primary_button.dart';

Future<void> showUserCardSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UserCardSheetBody(userId: userId),
  );
}

class _UserCardSheetBody extends ConsumerStatefulWidget {
  final String userId;
  const _UserCardSheetBody({required this.userId});

  @override
  ConsumerState<_UserCardSheetBody> createState() => _UserCardSheetBodyState();
}

class _UserCardSheetBodyState extends ConsumerState<_UserCardSheetBody> {
  bool _busy = false;
  int _tabIndex = 0;

  bool get _isSelf {
    try {
      return currentUserId == widget.userId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startDm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final convId =
          await ref.read(messagesRepoProvider).ensureDmWith(widget.userId);
      if (!mounted) return;
      final router = GoRouter.of(context);
      ref.invalidate(conversationsProvider);
      Navigator.of(context).pop();
      router.push('/chat/$convId');
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('profile_incomplete')) {
        showToast(context, context.l10n.onboarding_profile_required,
            error: true);
        Navigator.of(context).pop();
        GoRouter.of(context).push('/onboarding');
      } else {
        showToast(context, '${context.l10n.messages_new_failed}: $e',
            error: true);
      }
      setState(() => _busy = false);
    }
  }

  void _toggleFollow() {
    ref.read(favoritesRepoProvider).toggle(FavoriteEntity.user, widget.userId);
  }

  double _bannerHue(String id) =>
      (id.codeUnitAt(0) * 7 + id.codeUnitAt(1)) % 360.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final profileAsync = ref.watch(profileByIdProvider(widget.userId));
    ref.watch(localStoreProvider);
    final following = LocalStore.isFollowing(widget.userId);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: profileAsync.when(
        loading: () => SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator(color: t.accent)),
        ),
        error: (e, _) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 20, color: t.danger),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${l.messages_new_failed}: $e',
                    style: TextStyle(color: t.danger),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: Text(l.messages_new_dm_not_found,
                    style: TextStyle(color: t.inkSub)),
              ),
            );
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final hue = _bannerHue(widget.userId);
          final bannerColor =
              HSLColor.fromAHSL(1, hue, 0.4, isDark ? 0.18 : 0.82);
          final handle = profile.handle != null
              ? '@${profile.handle}'
              : '@${profile.id.substring(0, 6)}';
          final locationParts = [
            if ((profile.city ?? '').isNotEmpty) profile.city!,
            if ((profile.district ?? '').isNotEmpty) profile.district!,
          ];
          final location =
              locationParts.isNotEmpty ? locationParts.join(' · ') : null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ──
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Scrollable content ──
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Banner + Avatar ──
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (profile.bannerUrl != null &&
                              profile.bannerUrl!.isNotEmpty)
                            SizedBox(
                              height: 120,
                              width: double.infinity,
                              child: Image.network(
                                profile.bannerUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _GradientBanner(
                                    color: bannerColor, isDark: isDark),
                              ),
                            )
                          else
                            _GradientBanner(
                                color: bannerColor, isDark: isDark),
                          Positioned(
                            bottom: -36,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: t.elev1,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: NetworkAvatar(profile.name,
                                    url: profile.avatarUrl, size: 68),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 42),

                      // ── Name ──
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: t.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // ── Handle ──
                      Text(
                        handle,
                        style: TextStyle(
                          fontFamily: t.fontMono,
                          fontFamilyFallback: t.monoFallbacks,
                          fontSize: 13,
                          color: t.inkSub,
                        ),
                      ),

                      // ── Location ──
                      if (location != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: t.inkDim),
                            const SizedBox(width: 3),
                            Text(
                              location,
                              style: TextStyle(
                                  fontSize: 12, color: t.inkDim),
                            ),
                          ],
                        ),
                      ],

                      // ── Following / Followers ──
                      const SizedBox(height: 14),
                      _SocialStats(
                        userId: widget.userId,
                        userName: profile.name,
                      ),

                      // ── Action buttons ──
                      if (!_isSelf) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  label: following
                                      ? l.common_unfollow
                                      : l.common_follow,
                                  variant: following
                                      ? BtnVariant.ghost
                                      : BtnVariant.primary,
                                  size: BtnSize.md,
                                  full: true,
                                  onPressed: _toggleFollow,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PrimaryButton(
                                  label: l.messages_new_dm,
                                  variant: BtnVariant.ghost,
                                  size: BtnSize.md,
                                  full: true,
                                  disabled: _busy,
                                  onPressed: _busy ? null : _startDm,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Tab bar ──
                      const SizedBox(height: 16),
                      _buildTabBar(l, t),

                      // ── Tab content ──
                      if (_tabIndex == 0)
                        _PostsContent(userId: widget.userId)
                      else
                        _ArticlesContent(userId: widget.userId),

                      SafeArea(
                        top: false,
                        child: const SizedBox(height: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar(dynamic l, AppTokens t) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line, width: 1)),
      ),
      child: Row(
        children: [
          _tabItem(l.profile_tab_activities, 0, t),
          const SizedBox(width: 24),
          _tabItem(l.profile_tab_articles, 1, t),
        ],
      ),
    );
  }

  Widget _tabItem(String label, int index, AppTokens t) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? t.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? t.ink : t.inkDim,
          ),
        ),
      ),
    );
  }
}

// ── Posts content ──
class _PostsContent extends ConsumerWidget {
  final String userId;
  const _PostsContent({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final postsAsync = ref.watch(userActivitiesProvider(userId));

    return postsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: t.accent),
        )),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text(l.error_load_failed,
                style: TextStyle(fontSize: 13, color: t.inkSub))),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.article_outlined, size: 36, color: t.inkMute),
                  const SizedBox(height: 8),
                  Text(l.empty_no_data,
                      style: TextStyle(fontSize: 13, color: t.inkSub)),
                ],
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              for (var i = 0; i < posts.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.line),
                _PostItem(post: posts[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Articles content ──
class _ArticlesContent extends ConsumerWidget {
  final String userId;
  const _ArticlesContent({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final articlesAsync = ref.watch(userArticlesProvider(userId));

    return articlesAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: t.accent),
        )),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text(l.error_load_failed,
                style: TextStyle(fontSize: 13, color: t.inkSub))),
      ),
      data: (articles) {
        if (articles.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.menu_book_outlined, size: 36, color: t.inkMute),
                  const SizedBox(height: 8),
                  Text(l.empty_no_data,
                      style: TextStyle(fontSize: 13, color: t.inkSub)),
                ],
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              for (var i = 0; i < articles.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.line),
                _ArticleItem(article: articles[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Compact post item ──
class _PostItem extends StatelessWidget {
  final FeedActivity post;
  const _PostItem({required this.post});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        GoRouter.of(context).push('/post/${post.id}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: t.ink, height: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.favorite_border, size: 14, color: t.inkMute),
                const SizedBox(width: 3),
                Text('${post.likes}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
                const SizedBox(width: 14),
                Icon(Icons.chat_bubble_outline, size: 14, color: t.inkMute),
                const SizedBox(width: 3),
                Text('${post.comments}',
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
                const Spacer(),
                Text(post.displayTime,
                    style: TextStyle(fontSize: 11, color: t.inkMute)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact article item ──
class _ArticleItem extends StatelessWidget {
  final FeedArticle article;
  const _ArticleItem({required this.article});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        GoRouter.of(context).push('/article/${article.id}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        article.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.remove_red_eye_outlined,
                          size: 13, color: t.inkMute),
                      const SizedBox(width: 3),
                      Text('${article.viewCount}',
                          style:
                              TextStyle(fontSize: 11, color: t.inkMute)),
                      const SizedBox(width: 10),
                      Icon(Icons.favorite_border,
                          size: 13, color: t.inkMute),
                      const SizedBox(width: 3),
                      Text('${article.likes}',
                          style:
                              TextStyle(fontSize: 11, color: t.inkMute)),
                    ],
                  ),
                ],
              ),
            ),
            if (article.coverUrl != null &&
                article.coverUrl!.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  article.coverUrl!,
                  width: 72,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 72,
                    height: 54,
                    color: t.elev3,
                    child: Icon(Icons.image_outlined,
                        size: 20, color: t.inkMute),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Gradient banner fallback ──
// ── Social stats (following / followers) ──
class _SocialStats extends ConsumerWidget {
  final String userId;
  final String userName;
  const _SocialStats({required this.userId, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final followingAsync = ref.watch(userFollowingCountProvider(userId));
    final followersAsync = ref.watch(userFollowersCountProvider(userName));

    final followingCount = followingAsync.valueOrNull ?? 0;
    final followersCount = followersAsync.valueOrNull ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: _statCol('$followingCount', l.profile_following, t),
          ),
          Container(width: 1, height: 28, color: t.line),
          Expanded(
            child: _statCol('$followersCount', l.profile_followers, t),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label, AppTokens t) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: t.inkSub)),
      ],
    );
  }
}

class _GradientBanner extends StatelessWidget {
  final HSLColor color;
  final bool isDark;
  const _GradientBanner({required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.toColor(),
            color.withLightness(isDark ? 0.12 : 0.72).toColor(),
          ],
        ),
      ),
    );
  }
}
