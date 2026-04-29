import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/player_profile.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../home/cards/activity_feed_card.dart';
import '../home/cards/article_feed_card.dart';
import '../home/cards/pickup_feed_card.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _dmBusy = false;

  bool get _isSelf {
    try {
      return currentUserId == widget.userId;
    } catch (_) {
      return false;
    }
  }

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

  Future<void> _startDm() async {
    if (_dmBusy) return;
    setState(() => _dmBusy = true);
    try {
      final convId =
          await ref.read(messagesRepoProvider).ensureDmWith(widget.userId);
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      context.push('/chat/$convId');
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('profile_incomplete')) {
        showToast(context, context.l10n.onboarding_profile_required,
            error: true);
        context.push('/onboarding');
      } else {
        showToast(context, '${context.l10n.messages_new_failed}: $e',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _dmBusy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final isFollowing =
        ref.read(isFollowingProvider(widget.userId)).valueOrNull ?? false;
    if (isFollowing) {
      final l = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.common_unfollow_confirm_title),
          content: Text(l.common_unfollow_confirm_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.common_confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref
        .read(favoritesRepoProvider)
        .toggle(FavoriteEntity.user, widget.userId);
    ref.invalidate(isFollowingProvider(widget.userId));
    ref.invalidate(userFollowersCountProvider);
    ref.invalidate(userFollowingCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final async = ref.watch(fullProfileByIdProvider(widget.userId));
    final following = ref.watch(isFollowingProvider(widget.userId)).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: t.bg,
      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => _buildError(e),
        data: (profile) {
          if (profile == null) return _buildNotFound();
          return _buildContent(profile, following);
        },
      ),
    );
  }

  Widget _buildError(Object e) {
    final l = context.l10n;
    final t = context.tokens;
    return SafeArea(
      child: Column(
        children: [
          _backRow(),
          Expanded(
            child: Center(
              child: Text('${l.error_load_failed}: $e',
                  style: TextStyle(color: t.inkSub, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    final l = context.l10n;
    final t = context.tokens;
    return SafeArea(
      child: Column(
        children: [
          _backRow(),
          Expanded(
            child: Center(
              child: Text(l.messages_new_dm_not_found,
                  style: TextStyle(color: t.inkSub, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backRow() {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PlayerProfile u, bool following) {
    final l = context.l10n;
    final t = context.tokens;

    final followingCount =
        ref.watch(userFollowingCountProvider(widget.userId)).valueOrNull ?? 0;
    final followersCount = ref
            .watch(userFollowersCountProvider(widget.userId))
            .valueOrNull ??
        0;

    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Banner + avatar ──
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (u.bannerUrl != null && u.bannerUrl!.isNotEmpty)
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: Image.network(
                          u.bannerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _GradientBanner(),
                        ),
                      )
                    else
                      const _GradientBanner(),
                    Positioned(
                      top: 12,
                      left: 8,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0x40000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -44,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: t.bg,
                            shape: BoxShape.circle,
                          ),
                          child:
                              NetworkAvatar(u.name, url: u.avatarUrl, size: 84),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 52),
                // ── Name ──
                Text(
                  u.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                if (u.handle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    u.handle,
                    style: TextStyle(
                      fontFamily: t.fontMono,
                      fontFamilyFallback: t.monoFallbacks,
                      fontSize: 13,
                      color: t.inkSub,
                    ),
                  ),
                ],
                // ── Following / Followers ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 20, 40, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          count: followingCount,
                          label: l.profile_following,
                        ),
                      ),
                      Container(width: 1, height: 32, color: t.line),
                      Expanded(
                        child: _StatColumn(
                          count: followersCount,
                          label: l.profile_followers,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Action buttons ──
                if (!_isSelf) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 18, 40, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label:
                                following ? l.common_unfollow : l.common_follow,
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
                            disabled: _dmBusy,
                            onPressed: _dmBusy ? null : _startDm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          // ── Sticky TabBar ──
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
                  Tab(text: l.profile_tab_pickups),
                  Tab(text: l.profile_tab_articles),
                ],
              ),
              backgroundColor: t.bg,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ActivitiesTab(userId: widget.userId),
            _PickupsTab(userId: widget.userId),
            _ArticlesTab(userId: widget.userId),
          ],
        ),
      ),
    );
  }
}

// ── Activities tab ──
class _ActivitiesTab extends ConsumerWidget {
  final String userId;
  const _ActivitiesTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(userActivitiesProvider(userId));

    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(userActivitiesProvider(userId)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: [
              EmptyState(
                icon: Icons.directions_run,
                title: l.profile_empty_activities,
                subtitle: l.profile_empty_activities_sub,
              ),
            ]);
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

// ── Pickups tab ──
class _PickupsTab extends ConsumerWidget {
  final String userId;
  const _PickupsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userPickupsProvider(userId));

    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(userPickupsProvider(userId)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: const [
              EmptyState(
                icon: Icons.sports_soccer,
                title: '还没参加过约球',
                subtitle: '发起或加入一场约球吧',
              ),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                PickupFeedCard(pickup: items[i].pickup),
          );
        },
      ),
    );
  }
}

// ── Articles tab ──
class _ArticlesTab extends ConsumerWidget {
  final String userId;
  const _ArticlesTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(userArticlesProvider(userId));

    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(userArticlesProvider(userId)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(children: [
              EmptyState(
                icon: Icons.article_outlined,
                title: l.profile_empty_articles,
                subtitle: l.profile_empty_articles_sub,
              ),
            ]);
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

// ── Stat column ──
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

// ── TabBar delegate ──
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

// ── Gradient banner fallback ──
class _GradientBanner extends StatelessWidget {
  const _GradientBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2C2C2E),
            Color(0xFF1C1C1E),
          ],
        ),
      ),
    );
  }
}
