// home_screen.dart — 首页 Feed, 1:1 with React prototype (screens-home.jsx).
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/demo_images.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/feed.dart';
import '../../models/live_match.dart';
import '../../models/pickup.dart' as live;
import '../../providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/chip_pill.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final feedsAsync = ref.watch(feedsProvider);
    final liveNowAsync = ref.watch(liveNowProvider);
    final livePickups = ref.watch(livePickupsProvider);

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: context.tokens.accent,
              backgroundColor: context.tokens.elev1,
              onRefresh: () async {
                ref.invalidate(feedsProvider);
                ref.invalidate(liveNowProvider);
                ref.invalidate(livePickupsProvider);
                ref.invalidate(latestUnratedMatchProvider);
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  const _TopBar(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: Row(
                      children: [
                        Label(l.home_live_now),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.go('/events'),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Label(l.home_view_all),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...liveNowAsync.when(
                    data: (items) => items.isEmpty
                        ? [Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Label(l.home_no_live),
                          )]
                        : [_LiveStrip(items: items)],
                    loading: () => [const SizedBox(height: 96)],
                    error: (_, __) => [const SizedBox.shrink()],
                  ),
                  const _RateCtaBanner(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        Label(l.home_local_feed),
                        const Spacer(),
                        ChipPill(label: l.home_feed_all, active: true),
                        const SizedBox(width: 6),
                        ChipPill(label: l.home_feed_pickup),
                        const SizedBox(width: 6),
                        ChipPill(label: l.home_feed_result),
                      ],
                    ),
                  ),
                  // Live pickup cards (from Supabase)
                  ...livePickups.when(
                    data: (list) => list
                        .map(
                          (p) => _LivePickupCard(
                            p: p,
                            onTap: () => context.push('/pickup/${p.id}'),
                          ),
                        )
                        .toList(),
                    loading: () => [const _PickupLoading()],
                    error: (e, _) => [
                      _PickupError(
                        error: e,
                        onRetry: () => ref.invalidate(livePickupsProvider),
                      ),
                    ],
                  ),
                  // Feed items (results / posts / event teasers)
                  ...feedsAsync.when(
                    data: (items) =>
                        items.map((item) => _feedCard(context, item)).toList(),
                    loading: () => [const _PickupLoading()],
                    error: (_, __) => [const SizedBox.shrink()],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Label(l.home_bottom_of_feed)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedCard(BuildContext ctx, FeedItem item) {
    return switch (item) {
      FeedResult r => _ResultCard(item: r),
      FeedPost p => _PostCard(item: p),
      FeedEvent e => _EventTeaserCard(
        item: e,
        onTap: () => ctx.push('/event/${e.id}'),
      ),
    };
  }
}

// ─────────────────────────────────────────────────────────────
// Top bar: city + sport + search + bell
// ─────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(cityProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/city-picker'),
            child: Row(
              children: [
                Text(
                  city,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: context.tokens.inkSub,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _SportPicker(),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/search'),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.search, color: context.tokens.ink, size: 20),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => context.push('/inbox'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.inbox_outlined, color: context.tokens.ink, size: 20),
                ),
                Positioned(right: 4, top: 4, child: _InboxUnreadDot()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxUnreadDot extends ConsumerWidget {
  const _InboxUnreadDot();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMsgUnread = ref.watch(messagesUnreadProvider);
    final notifUnread = ref.watch(notificationsUnreadProvider).valueOrNull ?? 0;
    if (!hasMsgUnread && notifUnread == 0) return const SizedBox.shrink();
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: context.tokens.warn,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SportPicker extends ConsumerWidget {
  const _SportPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = ref.watch(sportProvider);
    final l = context.l10n;
    final labels = {
      'football': l.sport_football,
      'basketball': l.sport_basketball,
      'badminton': l.sport_badminton,
      'pingpong': l.sport_pingpong,
      'cycling': l.sport_cycling,
    };
    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      color: context.tokens.elev2,
      initialValue: sport,
      onSelected: (v) => ref.read(sportProvider.notifier).state = v,
      itemBuilder: (_) => [
        for (final e in labels.entries)
          PopupMenuItem(
            value: e.key,
            height: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SportIcon(
                  _parseSport(e.key),
                  size: 14,
                  color: e.key == sport ? context.tokens.accent : context.tokens.inkSub,
                ),
                const SizedBox(width: 8),
                Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: e.key == sport ? context.tokens.accent : context.tokens.ink,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.tokens.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SportIcon(_parseSport(sport), size: 13, color: context.tokens.accent),
            const SizedBox(width: 5),
            Text(
              labels[sport] ?? l.sport_football,
              style: TextStyle(fontSize: 12, color: context.tokens.ink),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 11, color: context.tokens.inkDim),
          ],
        ),
      ),
    );
  }

  Sport _parseSport(String s) => switch (s) {
    'basketball' => Sport.basketball,
    'badminton' => Sport.badminton,
    'pingpong' => Sport.pingpong,
    'cycling' => Sport.cycling,
    _ => Sport.football,
  };
}

// ─────────────────────────────────────────────────────────────
// Live carousel (auto-paging with poster backgrounds)
// ─────────────────────────────────────────────────────────────
class _LiveStrip extends StatefulWidget {
  final List<LiveMatch> items;
  const _LiveStrip({required this.items});

  @override
  State<_LiveStrip> createState() => _LiveStripState();
}

class _LiveStripState extends State<_LiveStrip> {
  late final PageController _ctrl;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: 0.88);
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        _current = (_current + 1) % widget.items.length;
        _ctrl.animateToPage(
          _current,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final posterUrl = m.posterUrl ?? DemoImages.pickCoverFor(m.id);
              final aWins = m.scoreA > m.scoreB;
              final bWins = m.scoreB > m.scoreA;
              return GestureDetector(
                onTap: () => context.push('/worldcup/live/${m.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.tokens.r3),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 160),
                          errorWidget: (_, _, _) => Container(
                            color: context.tokens.elev2,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x33000000),
                                Color(0xCC000000),
                              ],
                              stops: [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const LivePill(),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${m.viewersDisplay} 观看 · ${m.minute}',
                                    style: TextStyle(
                                      fontFamily: context.tokens.fontMono,
                                      fontFamilyFallback: context.tokens.monoFallbacks,
                                      fontSize: 11,
                                      color: Colors.white70,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.teamA,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          m.teamB,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      N(
                                        '${m.scoreA}',
                                        size: 24,
                                        weight: FontWeight.w700,
                                        color: aWins ? context.tokens.accent : Colors.white,
                                      ),
                                      const SizedBox(height: 2),
                                      N(
                                        '${m.scoreB}',
                                        size: 24,
                                        weight: FontWeight.w700,
                                        color: bWins ? context.tokens.accent : Colors.white,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? context.tokens.accent
                        : context.tokens.inkMute,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Rating CTA banner
// ─────────────────────────────────────────────────────────────
class _RateCtaBanner extends ConsumerWidget {
  const _RateCtaBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchId = ref.watch(latestUnratedMatchProvider).valueOrNull;
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final ratingStr = profile != null && profile.rating > 0
        ? profile.rating.toStringAsFixed(1)
        : '—';
    if (matchId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: GestureDetector(
        onTap: () => GoRouter.of(context).push('/rate/$matchId'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [context.tokens.accentSubtle, context.tokens.warnSubtle],
            ),
            border: Border.all(color: context.tokens.accent.withAlpha(0x66)),
            borderRadius: BorderRadius.circular(context.tokens.r3),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.accent.withAlpha(0x99)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: N(
                  ratingStr,
                  size: 16,
                  weight: FontWeight.w800,
                  color: context.tokens.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.home_rate_banner_title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Label(context.l10n.home_rate_banner_sub),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: context.tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Feed cards: Pickup / Result / Post / EventTeaser
// ─────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final FeedResult item;
  const _ResultCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final aWins = item.scoreA > item.scoreB;
    final bWins = item.scoreB > item.scoreA;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flagL = isDark ? 0.28 : 0.65;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 12,
                  color: context.tokens.inkSub,
                ),
                const SizedBox(width: 6),
                Label(item.eventName),
                const Spacer(),
                Label(item.displayTime),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.teamA,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: HSLColor.fromAHSL(1, 25, 0.4, flagL).toColor(),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: context.tokens.line),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                N(
                  '${item.scoreA}',
                  size: 34,
                  weight: FontWeight.w700,
                  color: aWins ? context.tokens.accent : context.tokens.inkSub,
                ),
                const SizedBox(width: 8),
                Text(
                  '-',
                  style: TextStyle(
                    color: context.tokens.inkDim,
                    fontFamily: context.tokens.fontMono,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                N(
                  '${item.scoreB}',
                  size: 34,
                  weight: FontWeight.w700,
                  color: bWins ? context.tokens.accent : context.tokens.inkSub,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.teamB,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: HSLColor.fromAHSL(1, 200, 0.4, flagL).toColor(),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: context.tokens.line),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.tokens.elev1,
              border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.my_location, size: 12, color: context.tokens.inkDim),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.scorers.join(' · '),
                    style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final FeedPost item;
  const _PostCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(item.authorName, size: 28),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.authorName,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Label(item.displayTime),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.body,
            style: TextStyle(fontSize: 14, color: context.tokens.ink, height: 1.55),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final t in item.tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.tokens.elev3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '#$t',
                    style: TextStyle(
                      fontFamily: context.tokens.fontMono,
                      fontFamilyFallback: context.tokens.monoFallbacks,
                      fontSize: 10,
                      color: context.tokens.inkSub,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _InteractStat(icon: Icons.favorite_border, count: item.likes),
              const SizedBox(width: 16),
              _InteractStat(icon: Icons.chat_bubble_outline, count: item.comments),
              const SizedBox(width: 16),
              _InteractStat(icon: Icons.share_outlined, count: item.shares),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractStat extends StatelessWidget {
  final IconData icon;
  final int count;
  const _InteractStat({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.tokens.inkSub),
        const SizedBox(width: 5),
        N('$count', size: 12, color: context.tokens.inkSub),
      ],
    );
  }
}

class _EventTeaserCard extends StatelessWidget {
  final FeedEvent item;
  final VoidCallback onTap;
  const _EventTeaserCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = item.teamsRegistered / item.teamsMax;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, size: 14, color: context.tokens.accent),
                const SizedBox(width: 6),
                Label(context.l10n.home_event_teaser, color: context.tokens.accent),
                const Spacer(),
                Label(item.displayTime),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.eventName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.tokens.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(context.l10n.home_event_registered_label),
                    const SizedBox(height: 2),
                    N(
                      '${item.teamsRegistered}/${item.teamsMax}',
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: context.tokens.line,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(context.l10n.home_event_kickoff),
                    const SizedBox(height: 2),
                    N(
                      item.startIn,
                      size: 14,
                      weight: FontWeight.w600,
                      color: context.tokens.warn,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: context.tokens.elev3,
                valueColor: AlwaysStoppedAnimation(context.tokens.accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.home_event_register_now,
              style: TextStyle(
                fontSize: 13,
                color: context.tokens.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Live pickup card — same visual as _PickupCard but reads from Supabase.
// ─────────────────────────────────────────────────────────────
class _LivePickupCard extends StatelessWidget {
  final live.Pickup p;
  final VoidCallback onTap;
  const _LivePickupCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final needed = p.displayNeed;
    final l = context.l10n;
    final filled = p.total - needed;
    final stateKey = switch (p.status) {
      live.PickupStatus.full => 'full',
      live.PickupStatus.almost => 'almost',
      _ => 'open',
    };
    final labels = {
      'open': l.home_status_open,
      'almost': l.home_status_almost,
      'full': l.home_status_full,
    };
    final stateColor = stateKey == 'open'
        ? context.tokens.accent
        : stateKey == 'almost'
        ? context.tokens.warn
        : context.tokens.inkDim;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(p.displayHost, size: 24),
                const SizedBox(width: 8),
                Text(
                  p.displayHost,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                Label(l.home_host_pickup),
                const Spacer(),
                StatusDot(state: stateKey),
                const SizedBox(width: 4),
                Label(labels[stateKey]!, color: stateColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              p.venue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.tokens.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: context.tokens.inkSub),
                const SizedBox(width: 4),
                N(p.displayTime, size: 12, color: context.tokens.inkSub),
                const SizedBox(width: 10),
                Icon(Icons.currency_yen, size: 12, color: context.tokens.inkSub),
                N(p.feeYuan.toStringAsFixed(0), size: 12, color: context.tokens.inkSub),
                const SizedBox(width: 10),
                if (p.level != null) Label(p.level!),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: context.tokens.line),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: (filled.clamp(0, 4) > 0)
                      ? (22 + (filled.clamp(0, 4) - 1) * 16).toDouble()
                      : 0,
                  height: 22,
                  child: Stack(
                    children: [
                      for (int i = 0; i < filled.clamp(0, 4); i++)
                        Positioned(
                          left: i * 16.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: context.tokens.elev2, width: 2),
                            ),
                            child: Avatar(['A', 'B', 'C', 'D'][i], size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                N('$filled', size: 12, weight: FontWeight.w600, color: context.tokens.ink),
                N('/${p.total}', size: 12, color: context.tokens.inkDim),
                const SizedBox(width: 6),
                if (needed > 0)
                  N(l.home_need_n(needed), size: 12, color: context.tokens.accent)
                else
                  N(l.home_full, size: 12, color: context.tokens.inkDim),
                const Spacer(),
                Text(
                  needed > 0 ? l.home_join_cta : l.home_status_full,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: needed > 0 ? context.tokens.accent : context.tokens.inkDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupLoading extends StatelessWidget {
  const _PickupLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2),
        ),
      ),
    );
  }
}

class _PickupError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _PickupError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: context.tokens.warn),
              const SizedBox(width: 6),
              Label(context.l10n.home_pickups_load_failed, color: context.tokens.warn),
            ],
          ),
          const SizedBox(height: 6),
          Text('$error', style: TextStyle(fontSize: 11, color: context.tokens.inkDim)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Text(
                context.l10n.common_retry,
                style: TextStyle(fontSize: 12, color: context.tokens.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
