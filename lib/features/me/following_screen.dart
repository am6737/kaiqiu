import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/user_card_sheet.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: l.profile_following,
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: l.profile_followers,
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0 ? _FollowingTab() : _FollowersTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              for (final userId in list)
                _FollowingUserRow(userId: userId),
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

class _FollowingUserRow extends ConsumerWidget {
  final String userId;
  const _FollowingUserRow({required this.userId});

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
          ref.invalidate(isFollowingProvider(userId));
        },
        child: Text(
          l.common_unfollow,
          style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
        ),
      ),
      onTap: () => showUserCardSheet(context, ref, userId: userId),
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
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              for (final follower in list)
                _FollowerRow(
                  userId: follower.id,
                  name: follower.name,
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

class _FollowerRow extends ConsumerWidget {
  final String userId;
  final String name;
  const _FollowerRow({required this.userId, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final following =
        ref.watch(isFollowingProvider(userId)).valueOrNull ?? false;
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
          if (following) {
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
              .toggle(FavoriteEntity.user, userId);
          ref.invalidate(isFollowingProvider(userId));
          ref.invalidate(myFollowingListProvider);
        },
        child: Text(
          following ? l.common_unfollow : l.common_follow,
          style: TextStyle(
            fontSize: 12,
            color: following ? context.tokens.inkSub : context.tokens.accent,
          ),
        ),
      ),
      onTap: () => showUserCardSheet(context, ref, userId: userId),
    );
  }
}
