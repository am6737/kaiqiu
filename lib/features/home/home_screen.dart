import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/sport_icon.dart';
import 'tabs/recommend_tab.dart';
import 'tabs/discover_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _TopBar(),
            TabBar(
              controller: _tabCtrl,
              labelColor: t.accent,
              unselectedLabelColor: t.inkMute,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: t.accent,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: t.elev1,
              tabs: [
                Tab(text: l.home_tab_recommend),
                Tab(text: l.home_tab_discover),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  RecommendTab(),
                  DiscoverTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    final notifUnread = ref.watch(notificationsUnreadProvider);
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
