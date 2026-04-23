import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../repositories/favorites_repository.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/interaction_btn.dart';

class ArticleFeedCard extends ConsumerWidget {
  final FeedArticle item;
  const ArticleFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final likedIds = ref.watch(likedArticleIdsProvider).valueOrNull ?? {};
    final isLiked = likedIds.contains(item.id);
    final favIds = ref.watch(favoriteArticleIdsProvider).valueOrNull ?? {};
    final isFav = favIds.contains(item.id);

    return GestureDetector(
      onTap: () => context.push('/article/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.category,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: t.accent)),
                  const SizedBox(height: 3),
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                          height: 1.4)),
                  if (item.summary != null) ...[
                    const SizedBox(height: 3),
                    Text(item.summary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: t.inkDim, height: 1.4)),
                  ],
                  const SizedBox(height: 6),
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
                ])),
            const SizedBox(width: 12),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      t.accent.withValues(alpha: 0.2),
                      t.danger.withValues(alpha: 0.1)
                    ]),
                borderRadius: BorderRadius.circular(t.r2),
              ),
              child: item.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(t.r2),
                      child:
                          Image.network(item.coverUrl!, fit: BoxFit.cover))
                  : const Center(
                      child: Text('📰', style: TextStyle(fontSize: 28))),
            ),
          ]),
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
          ),
        ]),
      ),
    );
  }

  void _toggleFavorite(BuildContext context, WidgetRef ref) async {
    if (!isSignedIn) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.like_login_required)),
      );
      return;
    }
    await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.article, item.id);
    ref.invalidate(favoriteArticleIdsProvider);
  }

  void _toggleLike(BuildContext context, WidgetRef ref) async {
    if (!isSignedIn) {
      final l = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.like_login_required)),
      );
      return;
    }
    await ref.read(likesRepoProvider).toggle('article', item.id);
    ref.invalidate(likedArticleIdsProvider);
    ref.invalidate(discoverFeedProvider);
  }
}
