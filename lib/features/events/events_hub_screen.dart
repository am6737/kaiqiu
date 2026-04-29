// events_hub_screen.dart — 赛事中心
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/external_match.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/network_cover.dart';
import '../../widgets/photo_halftone.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class EventsHubScreen extends ConsumerStatefulWidget {
  const EventsHubScreen({super.key});

  @override
  ConsumerState<EventsHubScreen> createState() => _EventsHubScreenState();
}

class _EventsHubScreenState extends ConsumerState<EventsHubScreen> {
  String _tab = 'ongoing';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = [
      ('registering', l.events_tab_registering),
      ('ongoing', l.events_tab_ongoing),
      ('completed', l.events_tab_completed),
      ('watch', l.events_tab_watch),
    ];
    final wcMatches = ref.watch(wcMatchesProvider).valueOrNull ?? const [];
    final statusForTab = switch (_tab) {
      'ongoing' => EventStatus.ongoing,
      'registering' => EventStatus.registering,
      'completed' => EventStatus.completed,
      _ => null,
    };

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.tokens.accent,
          backgroundColor: context.tokens.elev1,
          onRefresh: () async {
            ref.invalidate(wcMatchesProvider);
            ref.invalidate(featuredEventsProvider);
            if (statusForTab != null) {
              ref.invalidate(liveEventsProvider(statusForTab));
            }
          },
          child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Text(
                    l.events_title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.tokens.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/create-event'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.tokens.accentSubtle,
                        border: Border.all(color: const Color(0x6600FF85)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 13, color: context.tokens.accent),
                          const SizedBox(width: 5),
                          Text(
                            l.events_create,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Featured carousel (World Cup + hot events)
            const _FeaturedCarousel(),
            // Tabs
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
                    for (final t in tabs)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = t.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tab == t.$1
                                  ? context.tokens.elev3
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _tab == t.$1 ? context.tokens.ink : context.tokens.inkSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_tab == 'watch')
              ..._buildWatchTab(wcMatches)
            else
              ..._buildEventsList(statusForTab!),
          ],
        ),
        ),
      ),
    );
  }

  List<Widget> _buildEventsList(EventStatus status) {
    final async = ref.watch(liveEventsProvider(status));
    return async.when(
      data: (list) {
        if (list.isEmpty) return const [_EmptyEvents()];
        return [
          for (final e in list)
            _LiveEventRow(
              event: e,
              onTap: () => context.push('/event/${e.id}'),
            ),
        ];
      },
      loading: () => [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        ),
      ],
      error: (err, _) => [
        _EventsError(
          error: err,
          onRetry: () => ref.invalidate(liveEventsProvider(status)),
        ),
      ],
    );
  }

  List<Widget> _buildWatchTab(List<ExternalMatch> matches) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Label(context.l10n.events_watch_today),
      ),
      for (final m in matches)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/worldcup/live/wc-${m.teamA}-${m.teamB}'),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r3),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TeamRow(name: m.teamA, flag: m.flagA ?? '', hue: 25),
                ),
                if (m.isLive)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          N('${m.scoreA ?? 0}', size: 18, weight: FontWeight.w700),
                          Text(' - ', style: TextStyle(color: context.tokens.inkDim)),
                          N('${m.scoreB ?? 0}', size: 18, weight: FontWeight.w700),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const LivePill(),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      N(m.time, size: 13, weight: FontWeight.w600),
                      if (m.status != null) Label(m.status!),
                    ],
                  ),
                Expanded(
                  child: _TeamRow(
                    name: m.teamB,
                    flag: m.flagB ?? '',
                    hue: 200,
                    rightAlign: true,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _FeaturedCarousel extends ConsumerStatefulWidget {
  const _FeaturedCarousel();

  @override
  ConsumerState<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends ConsumerState<_FeaturedCarousel> {
  late final PageController _ctrl;
  Timer? _timer;
  int _current = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  void _startAutoScroll(int count) {
    _timer?.cancel();
    _totalPages = count;
    if (count > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        _current = (_current + 1) % _totalPages;
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
    final t = context.tokens;
    final featured = ref.watch(featuredEventsProvider).valueOrNull ?? [];

    final pages = <Widget>[
      _WcBannerPage(onTap: () => context.push('/worldcup')),
      for (final e in featured)
        _EventBannerPage(
          event: e,
          onTap: () => context.push('/event/${e.id}'),
        ),
    ];

    if (pages.length != _totalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoScroll(pages.length);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: pages.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: pages[i],
              ),
            ),
          ),
          if (pages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? t.accent : t.inkMute,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _WcBannerPage extends ConsumerWidget {
  final VoidCallback onTap;
  const _WcBannerPage({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final wcMatches = ref.watch(wcMatchesProvider).valueOrNull ?? const [];
    final liveCount = wcMatches.where((m) => m.isLive).length;
    const titleColor = Color(0xFFFFFFFF);
    const subColor = Color(0xCCFFFFFF);
    const labelColor = Color(0x99FFFFFF);
    const dividerColor = Color(0x33FFFFFF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A2380),
              Color(0xFF7A2A8A),
            ],
          ),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LivePill(),
                const SizedBox(width: 6),
                Label(l.events_pro, color: titleColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l.events_wc_banner_title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.events_wc_banner_sub,
              style: const TextStyle(fontSize: 13, color: subColor),
            ),
            const Spacer(),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(l.events_wc_live_now, color: labelColor),
                    const SizedBox(height: 2),
                    N(
                      '$liveCount',
                      size: 20,
                      weight: FontWeight.w700,
                      color: const Color(0xFF00FF85),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(l.events_wc_predicts, color: labelColor),
                    const SizedBox(height: 2),
                    N('${wcMatches.length}', size: 20, weight: FontWeight.w700, color: titleColor),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventBannerPage extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventBannerPage({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final isReg = event.status == EventStatus.registering;
    final isDone = event.status == EventStatus.completed;
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    final statusLabel = isReg
        ? l.events_tab_registering
        : isDone
            ? l.events_tab_completed
            : l.events_tab_ongoing;
    final prizeLabel = event.prizeCents != null
        ? l.event_prize_wan((event.prizeCents! / 1000000).toStringAsFixed(1))
        : null;
    final subtitle = [
      if (event.sub?.isNotEmpty ?? false) event.sub!,
      if (event.city?.isNotEmpty ?? false) event.city!,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.r3),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkCover(
              url: event.coverUrl,
              fallbackLabel: event.name,
              height: 160,
              hue: hue,
              variant: HalftoneVariant.lines,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isReg
                              ? t.accentSubtle
                              : const Color(0x80000000),
                          border: Border.all(
                            color: isReg ? t.accent : const Color(0x33FFFFFF),
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isReg ? t.accent : Colors.white,
                          ),
                        ),
                      ),
                      if (prizeLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x80000000),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events, size: 10, color: t.warn),
                              const SizedBox(width: 3),
                              Text(
                                prizeLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveEventRow extends ConsumerWidget {
  final Event event;
  final VoidCallback onTap;
  const _LiveEventRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final isReg = event.status == EventStatus.registering;
    final isDone = event.status == EventStatus.completed;
    final liveAsync = ref.watch(liveMatchesForEventProvider(event.id));
    final hasLive = liveAsync.valueOrNull?.isNotEmpty ?? false;
    final teamsMax = event.teamsMax ?? 16;
    final teams = ref.watch(eventTeamsCountProvider(event.id)).valueOrNull ?? 0;
    final progress = teamsMax > 0 ? teams / teamsMax : 0.0;
    final prizeLabel = event.prizeCents != null
        ? l.event_prize_wan((event.prizeCents! / 1000000).toStringAsFixed(1))
        : l.event_prize_pending;
    final deadlineLabel = isDone
        ? l.events_tab_completed
        : event.deadline != null
            ? l.event_deadline_md_suffix(
                '${event.deadline!.month.toString().padLeft(2, '0')}-${event.deadline!.day.toString().padLeft(2, '0')}',
              )
            : '—';
    final subtitle = [
      if (event.sub?.isNotEmpty ?? false) event.sub!,
      if (event.city?.isNotEmpty ?? false) event.city!,
    ].join(' · ');
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(context.tokens.r3),
                topRight: Radius.circular(context.tokens.r3),
              ),
              child: Stack(
                children: [
                  NetworkCover(
                    url: event.coverUrl,
                    fallbackLabel: event.name,
                    height: 110,
                    hue: hue,
                    variant: HalftoneVariant.lines,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: !isReg && !isDone && hasLive
                        ? const LivePill()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isReg
                                  ? context.tokens.accentSubtle
                                  : (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0x80000000)
                                      : const Color(0xCCFFFFFF)),
                              border: Border.all(color: isReg ? context.tokens.accent : context.tokens.line),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Label(
                              isReg
                                  ? context.l10n.events_tab_registering
                                  : isDone
                                      ? context.l10n.events_tab_completed
                                      : context.l10n.events_tab_ongoing,
                              color: isReg ? context.tokens.accent : context.tokens.ink,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0x80000000)
                            : const Color(0xCCFFFFFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 11,
                            color: context.tokens.warn,
                          ),
                          const SizedBox(width: 4),
                          N(
                            prizeLabel,
                            size: 11,
                            weight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle.isEmpty ? '—' : subtitle,
                    style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Label(context.l10n.event_row_teams_label),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              N('$teams', size: 16, weight: FontWeight.w700),
                              N('/$teamsMax', size: 12, color: context.tokens.inkDim),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: context.tokens.elev3,
                              valueColor: AlwaysStoppedAnimation(
                                isReg ? context.tokens.accent : context.tokens.inkSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Label(context.l10n.event_row_status_label),
                          const SizedBox(height: 2),
                          N(
                            deadlineLabel,
                            size: 11,
                            weight: FontWeight.w600,
                            color: isReg ? context.tokens.warn : context.tokens.inkSub,
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
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name, flag;
  final double hue;
  final bool rightAlign;
  const _TeamRow({
    required this.name,
    required this.flag,
    required this.hue,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment: rightAlign
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!rightAlign) _flag(context),
        if (!rightAlign) const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.tokens.ink,
          ),
        ),
        if (rightAlign) const SizedBox(width: 8),
        if (rightAlign) _flag(context),
      ],
    );
    return row;
  }

  Widget _flag(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flagL = isDark ? 0.28 : 0.65;
    return Container(
      width: 28,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, hue, 0.4, flagL).toColor(),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        flag,
        style: TextStyle(
          fontFamily: context.tokens.fontMono,
          fontFamilyFallback: context.tokens.monoFallbacks,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: context.tokens.ink,
        ),
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 30),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 32, color: context.tokens.inkDim),
            const SizedBox(height: 10),
            Text(
              l.empty_no_events,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.tokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            Label(l.empty_no_events_sub),
          ],
        ),
      ),
    );
  }
}

class _EventsError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _EventsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(context.l10n.error_load_failed, color: context.tokens.danger),
            const SizedBox(height: 6),
            Text(
              '$error',
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  context.l10n.common_retry,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
