import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/local_storage.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../theme/app_tokens.dart';

class FollowingScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const FollowingScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends ConsumerState<FollowingScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.me_following_title,
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
                      label: l.profile_following,
                      active: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _Tab(
                      label: l.profile_followers,
                      active: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _FollowingTab(),
                _ => _FollowersTab(),
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

class _FollowingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myFollowingListProvider);
    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myFollowingListProvider),
      child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.people_alt_outlined,
                  title: l.me_following_empty,
                  subtitle: l.me_following_empty_sub,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              for (final name in list)
                _UserRow(
                  name: name,
                  trailing: TextButton(
                    onPressed: () async {
                      await ref
                          .read(favoritesRepoProvider)
                          .toggle(FavoriteEntity.user, name);
                      ref.invalidate(myFollowingListProvider);
                    },
                    child: Text(
                      l.common_unfollow,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.inkSub,
                      ),
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

class _FollowersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myFollowersListProvider);
    return RefreshIndicator(
      color: context.tokens.accent,
      backgroundColor: context.tokens.elev1,
      onRefresh: () async => ref.invalidate(myFollowersListProvider),
      child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyState(
                  icon: Icons.people_alt_outlined,
                  title: l.me_followers_empty,
                  subtitle: l.me_followers_empty_sub,
                ),
              ],
            );
          }
          ref.watch(localStoreProvider);
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              for (final name in list)
                _UserRow(
                  name: name,
                  trailing: _FollowButton(name: name),
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

class _FollowButton extends ConsumerWidget {
  final String name;
  const _FollowButton({required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localStoreProvider);
    final isFollowing = LocalStore.isFollowing(name);
    final l = context.l10n;
    return TextButton(
      onPressed: () async {
        await ref
            .read(favoritesRepoProvider)
            .toggle(FavoriteEntity.user, name);
        ref.invalidate(myFollowingListProvider);
      },
      child: Text(
        isFollowing ? l.common_unfollow : l.common_follow,
        style: TextStyle(
          fontSize: 12,
          color: isFollowing ? context.tokens.inkSub : context.tokens.accent,
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String name;
  final Widget? trailing;
  const _UserRow({required this.name, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.tokens.line, width: 1),
        ),
      ),
      child: Row(
        children: [
          Avatar(name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                color: context.tokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
