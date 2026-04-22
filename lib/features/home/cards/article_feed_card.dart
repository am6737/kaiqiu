import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/feed.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class ArticleFeedCard extends StatelessWidget {
  final FeedArticle item;
  const ArticleFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    return GestureDetector(
      onTap: () => context.push('/article/${item.id}'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: t.accent)),
          const SizedBox(height: 3),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink, height: 1.4)),
          if (item.summary != null) ...[
            const SizedBox(height: 3),
            Text(item.summary!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: t.inkDim, height: 1.4)),
          ],
          const SizedBox(height: 6),
          Text('👁 ${item.viewCount} · 💬 ${item.commentCount} · ${l.home_article_read_time(item.readTimeMin)}',
              style: TextStyle(fontSize: 10, color: t.inkMute)),
        ])),
        const SizedBox(width: 12),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [t.accent.withValues(alpha: 0.2), t.danger.withValues(alpha: 0.1)]),
            borderRadius: BorderRadius.circular(t.r2),
          ),
          child: item.coverUrl != null
              ? ClipRRect(borderRadius: BorderRadius.circular(t.r2),
                  child: Image.network(item.coverUrl!, fit: BoxFit.cover))
              : const Center(child: Text('📰', style: TextStyle(fontSize: 28))),
        ),
      ]),
    ),
    );
  }
}
