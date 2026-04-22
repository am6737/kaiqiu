// lib/features/home/tabs/discover_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../cards/activity_feed_card.dart';
import '../cards/article_feed_card.dart';
import '../cards/post_feed_card.dart';

class DiscoverTab extends ConsumerWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final feedAsync = ref.watch(discoverFeedProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(discoverFeedProvider);
      },
      child: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: items.length,
          itemBuilder: (ctx, i) => _buildCard(items[i]),
        ),
      ),
    );
  }

  Widget _buildCard(FeedItem item) {
    return switch (item) {
      FeedActivity a => ActivityFeedCard(item: a),
      FeedArticle a => ArticleFeedCard(item: a),
      FeedPost p => PostFeedCard(item: p),
      _ => const SizedBox.shrink(),
    };
  }
}
