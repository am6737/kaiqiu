// favorites_screen.dart — 收藏与足迹
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../widgets/avatar.dart';
import '../../widgets/user_card_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.me_favorites_title,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Row(
                  children: [
                    _Tab(
                      label: l.me_favorites_tab_pickups,
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _Tab(
                      label: l.me_favorites_tab_events,
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                    _Tab(
                      label: l.me_favorites_tab_players,
                      active: _tab == 2,
                      onTap: () => setState(() => _tab = 2),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _PickupTab(),
                1 => _EventTab(),
                _ => _PlayerTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? context.tokens.elev3 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? context.tokens.ink : context.tokens.inkSub,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myFavoritePickupsProvider);
    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myFavoritePickupsProvider),
      child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.bookmark_border,
                  title: l.empty_no_favorites,
                  subtitle: l.empty_no_favorites_sub,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
            for (final p in list)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/pickup/${p.id}'),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
                  ),
                  child: Row(
                    children: [
                      SportIcon(
                        Sport.football,
                        size: 20,
                        color: context.tokens.inkSub,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.venue,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.tokens.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            N(p.displayTime, size: 11, color: context.tokens.inkSub),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await ref
                              .read(favoritesRepoProvider)
                              .toggle(FavoriteEntity.pickup, p.id);
                        },
                        child: Icon(
                          Icons.favorite,
                          size: 18,
                          color: context.tokens.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
      ),
    );
  }
}

class _EventTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myFavoriteEventsProvider);
    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myFavoriteEventsProvider),
      child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.bookmark_border,
                  title: l.empty_no_favorites,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              for (final e in list)
                ListTile(
                  leading: Icon(Icons.emoji_events, color: context.tokens.warn),
                  title: Text(
                    e.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.tokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    e.sub ?? (e.city ?? ''),
                    style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.favorite, size: 18, color: context.tokens.accent),
                    onPressed: () async {
                      await ref
                          .read(favoritesRepoProvider)
                          .toggle(FavoriteEntity.event, e.id);
                    },
                  ),
                  onTap: () => context.push('/event/${e.id}'),
                ),
            ],
          );
        },
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
      ),
    );
  }
}

class _PlayerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final followedAsync = ref.watch(myFollowingListProvider);
    return followedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => EmptyState(
        icon: Icons.people_alt_outlined,
        title: l.empty_no_favorites,
      ),
      data: (followed) {
    if (followed.isEmpty) {
      return EmptyState(
        icon: Icons.people_alt_outlined,
        title: l.empty_no_favorites,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        for (final userId in followed)
          _FollowedUserTile(userId: userId),
      ],
    );
      },
    );
  }
}

class _FollowedUserTile extends ConsumerWidget {
  final String userId;
  const _FollowedUserTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = ref.watch(profileByIdProvider(userId));
    final name = profileAsync.valueOrNull?.name ?? userId;
    return ListTile(
      leading: Avatar(name, size: 36),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 14,
          color: context.tokens.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: TextButton(
        onPressed: () async {
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
          await ref
              .read(favoritesRepoProvider)
              .toggle(FavoriteEntity.user, userId);
          ref.invalidate(myFollowingListProvider);
        },
        child: Text(
          l.common_unfollow,
          style: TextStyle(color: context.tokens.inkSub),
        ),
      ),
      onTap: () => showUserCardSheet(context, ref, userId: userId),
    );
  }
}
