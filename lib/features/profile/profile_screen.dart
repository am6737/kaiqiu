import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
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
import '../../models/pickup.dart';
import '../home/cards/activity_feed_card.dart';
import '../home/cards/article_feed_card.dart';

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

  Future<void> _pickBanner(PlayerProfile? profile) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final newUrl = await StorageService().pickCropCompressAndUpload(
        bucket: 'avatars',
        pathPrefix: '$uid/banner',
        square: false,
      );
      if (newUrl == null || !mounted) return;
      await ref.read(profilesRepoProvider).update(uid, {'banner_url': newUrl});
      ref.invalidate(myProfileProvider);
    } catch (_) {}
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

  void _create() {
    final route = switch (_tabController.index) {
      0 => '/create-post',
      1 => '/create-pickup',
      _ => '/create-article',
    };
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final PlayerProfile? u = ref.watch(myProfileProvider).valueOrNull;
    ref.watch(localStoreProvider);

    final followingCount = ref.watch(followingCountProvider).valueOrNull ?? 0;
    final followersCount =
        ref.watch(followersCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: t.accent,
        child: Icon(Icons.add, color: t.accentInk),
      ),
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Banner + avatar
                  _ProfileBanner(
                    profile: u,
                    onTapAvatar: () => _pickAvatar(u),
                    onTapBanner: () => _pickBanner(u),
                    onSettings: () => context.push('/me/settings'),
                  ),
                  // Name (extra top for avatar overhang)
                  Padding(
                    padding: const EdgeInsets.only(top: 44),
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
            children: const [
              _ActivitiesTab(),
              _PickupsTab(),
              _ArticlesTab(),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _PickupsTab extends ConsumerWidget {
  const _PickupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final uid = currentUserId;
    if (uid == null) {
      return Center(child: Text(l.error_please_login, style: TextStyle(color: t.inkSub)));
    }
    final async = ref.watch(userPickupsProvider(uid));

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async => ref.invalidate(userPickupsProvider(uid)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: [
                EmptyState(
                  icon: Icons.sports_soccer,
                  title: l.empty_no_pickups,
                  subtitle: l.empty_no_pickups_sub,
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return _PickupListTile(
                pickup: item.pickup,
                isHost: item.isHost,
              );
            },
          );
        },
      ),
    );
  }
}

class _PickupListTile extends StatelessWidget {
  final Pickup pickup;
  final bool isHost;
  const _PickupListTile({required this.pickup, required this.isHost});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final roleLabel = isHost ? l.profile_pickup_organized : l.profile_pickup_participated;
    final roleColor = isHost ? t.accent : t.inkSub;

    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/pickup/${pickup.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.elev1,
          borderRadius: BorderRadius.circular(t.r2),
          border: Border.all(color: t.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkAvatar(pickup.displayHost, url: pickup.hostAvatarUrl, size: 40, square: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _StatusLabel(status: pickup.status, tokens: t, l10n: l),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pickup.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: t.inkMute),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pickup.venue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: t.inkDim),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.schedule, size: 14, color: t.inkMute),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(pickup.startAt),
                        style: TextStyle(fontSize: 12, color: t.inkMute),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusLabel extends StatelessWidget {
  final PickupStatus status;
  final AppTokens tokens;
  final dynamic l10n;
  const _StatusLabel({required this.status, required this.tokens, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (Color color, String text) = switch (status) {
      PickupStatus.open => (tokens.accent, l10n.home_status_open),
      PickupStatus.almost => (tokens.warn, l10n.home_status_almost),
      PickupStatus.full => (tokens.inkMute, l10n.home_status_full),
      PickupStatus.done => (tokens.inkMute, l10n.pickup_detail_status_done),
      PickupStatus.cancelled => (tokens.danger, l10n.pickup_status_cancelled),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

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

class _ProfileBanner extends StatelessWidget {
  final PlayerProfile? profile;
  final VoidCallback onTapAvatar;
  final VoidCallback onTapBanner;
  final VoidCallback onSettings;
  const _ProfileBanner({
    required this.profile,
    required this.onTapAvatar,
    required this.onTapBanner,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bannerUrl = profile?.bannerUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner area
        GestureDetector(
          onTap: onTapBanner,
          child: Stack(
            children: [
              if (bannerUrl != null && bannerUrl.isNotEmpty)
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(bannerUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback()),
                )
              else
                _fallback(),
              // Camera hint
              Positioned(
                right: 12,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x66000000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 14, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('换背景',
                          style: TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Settings button
        Positioned(
          top: 6,
          right: 8,
          child: IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 20,
                color: Colors.white70),
          ),
        ),
        // Avatar overlapping bottom edge
        Positioned(
          bottom: -36,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onTapAvatar,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: t.bg,
                  shape: BoxShape.circle,
                ),
                child: NetworkAvatar(
                  profile?.name ?? '新球友',
                  url: profile?.avatarUrl,
                  size: 72,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() => Container(
        height: 180,
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
