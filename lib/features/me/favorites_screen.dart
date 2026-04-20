// favorites_screen.dart — 收藏与足迹
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';

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
      backgroundColor: T.bg,
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
                  color: T.elev2,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r2),
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
            color: active ? T.elev3 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? T.ink : T.inkSub,
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
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border,
            title: l.empty_no_favorites,
            subtitle: l.empty_no_favorites_sub,
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
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: T.line, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const SportIcon(
                        Sport.football,
                        size: 20,
                        color: T.inkSub,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.venue,
                              style: const TextStyle(
                                fontSize: 14,
                                color: T.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            N(p.displayTime, size: 11, color: T.inkSub),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await LocalStore.toggleFavoritePickup(p.id);
                        },
                        child: const Icon(
                          Icons.favorite,
                          size: 18,
                          color: T.live,
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
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _EventTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myFavoriteEventsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border,
            title: l.empty_no_favorites,
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            for (final e in list)
              ListTile(
                leading: const Icon(Icons.emoji_events, color: T.warn),
                title: Text(
                  e.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: T.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  e.sub ?? (e.city ?? ''),
                  style: const TextStyle(fontSize: 12, color: T.inkSub),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, size: 18, color: T.live),
                  onPressed: () async {
                    await LocalStore.toggleFavoriteEvent(e.id);
                  },
                ),
                onTap: () => context.push('/event/${e.id}'),
              ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _PlayerTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final followed = LocalStore.followedUsers.toList();
    if (followed.isEmpty) {
      return EmptyState(
        icon: Icons.people_alt_outlined,
        title: l.empty_no_favorites,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        for (final name in followed)
          ListTile(
            leading: Avatar(name, size: 36),
            title: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: T.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: TextButton(
              onPressed: () async {
                await LocalStore.toggleFollowUser(name);
              },
              child: Text(
                l.common_unfollow,
                style: const TextStyle(color: T.inkSub),
              ),
            ),
            onTap: () => context.push('/archive'),
          ),
      ],
    );
  }
}
