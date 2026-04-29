import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/share_helper.dart';
import '../../../utils/toast.dart';
import '../../../widgets/network_avatar.dart';
import '../../../widgets/interaction_btn.dart';

class PostFeedCard extends ConsumerWidget {
  final FeedPost item;
  const PostFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final likedIds = ref.watch(likedPostIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(item.id);

    return GestureDetector(
      onTap: () => context.push('/post/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                NetworkAvatar(item.authorName, url: item.authorAvatarUrl, size: 32),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.authorName,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.ink)),
                      Text(item.displayTime,
                          style: TextStyle(fontSize: 10, color: t.inkMute)),
                    ])),
              ]),
              const SizedBox(height: 8),
              Text(item.body,
                  style: TextStyle(
                      fontSize: 12,
                      color: t.ink.withValues(alpha: 0.8),
                      height: 1.5)),
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                    spacing: 5,
                    children: item.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                  color: t.elev2,
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text('#$tag',
                                  style:
                                      TextStyle(fontSize: 10, color: t.accent)),
                            ))
                        .toList()),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: t.elev2))),
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
              ),
            ]),
      ),
    );
  }

  void _toggleLike(BuildContext context, WidgetRef ref) async {
    if (!isSignedIn) {
      final l = AppL10n.of(context);
      showToast(context, l.like_login_required, info: true);
      return;
    }
    await ref.read(likesRepoProvider).toggle('post', item.id);
    ref.invalidate(likedPostIdsProvider);
    ref.invalidate(discoverFeedProvider);
  }
}
