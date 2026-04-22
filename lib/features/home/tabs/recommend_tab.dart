// lib/features/home/tabs/recommend_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feed.dart';
import '../../../models/pickup.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../cards/live_match_card.dart';
import '../cards/pickup_feed_card.dart';
import '../cards/activity_feed_card.dart';
import '../cards/event_feed_card.dart';
import '../cards/article_feed_card.dart';
import '../cards/post_feed_card.dart';

class RecommendTab extends ConsumerWidget {
  const RecommendTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final feedAsync = ref.watch(recommendFeedProvider);
    final liveAsync = ref.watch(liveNowProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(recommendFeedProvider);
        ref.invalidate(liveNowProvider);
      },
      child: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final liveMatches = liveAsync.valueOrNull ?? [];
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: liveMatches.length + items.length,
            itemBuilder: (ctx, i) {
              if (i < liveMatches.length) {
                return LiveMatchCard(match: liveMatches[i]);
              }
              final item = items[i - liveMatches.length];
              return _buildCard(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(FeedItem item) {
    return switch (item) {
      FeedResult r => PostFeedCard(
          item: FeedPost(
            id: r.id,
            createdAt: r.createdAt,
            authorName: r.eventName,
            body: '${r.teamA} ${r.scoreA} : ${r.scoreB} ${r.teamB}',
            tags: [],
            likes: 0,
            comments: 0,
            shares: 0,
          ),
        ),
      FeedPost p => PostFeedCard(item: p),
      FeedEvent e => EventFeedCard(item: e),
      FeedPickup p => PickupFeedCard(
          pickup: _pickupFromFeed(p),
        ),
      FeedArticle a => ArticleFeedCard(item: a),
      FeedActivity a => ActivityFeedCard(item: a),
    };
  }

  Pickup _pickupFromFeed(FeedPickup fp) {
    return Pickup.fromMap({
      'id': fp.id,
      'venue': fp.venue,
      'start_at': fp.startAt.toIso8601String(),
      'time_label': fp.timeLabel,
      'total': fp.total,
      'need': fp.need,
      'level': fp.level,
      'fee_cents': fp.feeCents,
      'status': fp.status,
      'created_at': fp.createdAt.toIso8601String(),
    });
  }
}
