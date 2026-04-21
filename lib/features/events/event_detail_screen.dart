// event_detail_screen.dart — 赛事详情 (6 tabs)
//
// Live tabs:  overview (from event row) · bracket / standings (from matches)
//             · ratings (from event_player_ratings view)
// Mock tabs:  scorers (needs goals table, Session D)
//             · chat   (needs chat schema, Session D)
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock.dart' as mock;
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../models/message.dart';
import '../../models/profile.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../repositories/goals_repository.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/network_cover.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  String _tab = 'bracket';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: async.when(
        data: (event) => _buildContent(event),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: T.live)),
        error: (e, _) => _buildError(e),
      ),
    );
  }

  Widget _buildError(Object e) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: T.danger),
            const SizedBox(height: 8),
            Text(
              '${l.error_load_failed}: $e',
              style: const TextStyle(fontSize: 13, color: T.inkSub),
            ),

            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(eventDetailProvider(widget.id)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.common_retry,
                  style: const TextStyle(color: T.ink, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Event event) {
    final l = context.l10n;
    final tabs = [
      ('overview', l.event_tab_overview),
      ('bracket', l.event_tab_bracket),
      ('standings', l.event_tab_standings),
      ('scorers', l.event_tab_scorers),
      ('ratings', l.event_tab_ratings),
      ('chat', l.event_tab_chat),
    ];
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(event: event, onBack: () => context.pop()),
              _KpiStrip(
                eventId: event.id,
                prizeCents: event.prizeCents,
                teamsMax: event.teamsMax,
              ),
              _Tabs(
                current: _tab,
                tabs: tabs,
                onChange: (v) => setState(() => _tab = v),
              ),
              switch (_tab) {
                'overview' => _OverviewPanel(event: event),
                'bracket' => _BracketPanel(eventId: event.id),
                'standings' => _StandingsPanel(eventId: event.id),
                'scorers' => _ScorersPanel(eventId: event.id),
                'ratings' => RatingsPanel(event: event),
                _ => _ChatPanel(eventId: event.id),
              },
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomCta(event: event),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Event event;
  final VoidCallback onBack;
  const _Header({required this.event, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    final l = context.l10n;
    final (dotColor, pillColor, pillText) = switch (event.status) {
      EventStatus.ongoing => (T.live, T.live, l.event_status_ongoing),
      EventStatus.registering => (T.warn, T.warn, l.event_status_registering),
      EventStatus.done => (T.inkDim, T.inkSub, l.event_status_done),
    };
    return Stack(
      children: [
        NetworkCover(
          url: event.coverUrl,
          fallbackLabel: context.l10n.event_overview_main_visual(event.name),
          height: 180,
          hue: hue,
        ),
        Positioned(
          top: 12,
          left: 12,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(0x80000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: T.ink,
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => shareEvent(event),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(0x80000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.ios_share, size: 16, color: T.ink),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xF20A0A0A)],
                stops: [0, 0.8],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Label(pillText, color: pillColor),
                    if (event.sub != null && event.sub!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Label('· ${event.sub!}'),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: T.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiStrip extends ConsumerWidget {
  final String eventId;
  final int? prizeCents;
  final int? teamsMax;
  const _KpiStrip({required this.eventId, this.prizeCents, this.teamsMax});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(eventMatchesProvider(eventId));
    final matchesStr = matchesAsync.maybeWhen(
      data: (list) => '${list.where((m) => m.done).length}/${list.length}',
      orElse: () => '-',
    );
    final l = context.l10n;
    final prizeStr = prizeCents != null
        ? l.create_event_preview_prize_wan(
            (prizeCents! / 1000000).toStringAsFixed(1),
          )
        : '-';
    final items = [
      (l.event_kpi_teams, teamsMax?.toString() ?? '-'),
      (l.event_kpi_matches, matchesStr),
      (l.event_kpi_prize, prizeStr),
      (l.event_kpi_viewers, _deterministicViewers(eventId)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: i == 0 ? null : const EdgeInsets.only(left: 10),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(
                          left: BorderSide(color: context.tokens.line, width: 1),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: i == 0
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Label(items[i].$1),
                    const SizedBox(height: 3),
                    N(
                      items[i].$2,
                      size: 16,
                      weight: FontWeight.w700,
                      color: T.ink,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final String current;
  final List<(String, String)> tabs;
  final ValueChanged<String> onChange;

  const _Tabs({
    required this.current,
    required this.tabs,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            for (final t in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => onChange(t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: current == t.$1 ? T.live : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: current == t.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: current == t.$1 ? T.ink : T.inkSub,
                      ),
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

// ─────────────────────────────────────────────────────────────
// Shared panel helpers
// ─────────────────────────────────────────────────────────────
class _PanelLoading extends StatelessWidget {
  const _PanelLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(36),
    child: Center(child: CircularProgressIndicator(color: T.live)),
  );
}

class _PanelError extends StatelessWidget {
  final Object error;
  const _PanelError(this.error);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(
        '${context.l10n.error_load_failed}: $error',
        style: const TextStyle(fontSize: 12, color: T.inkSub),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Overview
// ─────────────────────────────────────────────────────────────
class _OverviewPanel extends StatelessWidget {
  final Event event;
  const _OverviewPanel({required this.event});

  @override
  Widget build(BuildContext context) {
    final body = event.sub?.isNotEmpty == true
        ? '${event.sub} — ${event.name}。'
        : '${event.name}。';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: const TextStyle(fontSize: 14, color: T.ink, height: 1.6),
          ),
          const SizedBox(height: 16),
          Label(context.l10n.event_overview_rules),
          const SizedBox(height: 10),
          for (final r in [
            context.l10n.event_overview_rule_format,
            context.l10n.event_overview_rule_halves,
            context.l10n.event_overview_rule_subs,
            context.l10n.event_overview_rule_cards,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: T.live,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r,
                    style: const TextStyle(fontSize: 13, color: T.inkSub),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Label(context.l10n.event_overview_organizer),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.tokens.elev3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.city ?? '—',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: T.ink,
                      ),
                    ),
                    Label(context.l10n.event_overview_organizer_label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bracket
// ─────────────────────────────────────────────────────────────
class _BracketPanel extends ConsumerWidget {
  final String eventId;
  const _BracketPanel({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(eventMatchesProvider(eventId))
        .when(
          data: (matches) => _BracketLayout(eventId: eventId, matches: matches),
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e),
        );
  }
}

class _BracketLayout extends StatelessWidget {
  final String eventId;
  final List<Match> matches;
  const _BracketLayout({required this.eventId, required this.matches});

  @override
  Widget build(BuildContext context) {
    final qf = matches.where((m) => m.round == 'qf').toList();
    final sf = matches.where((m) => m.round == 'sf').toList();
    final finals = matches.where((m) => m.round == 'final').toList();
    final finalMatch = finals.isNotEmpty ? finals.first : null;

    if (qf.isEmpty && sf.isEmpty && finalMatch == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Label(context.l10n.event_bracket_waiting)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 500,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(context.l10n.event_bracket_qf),
                    const SizedBox(height: 10),
                    if (qf.isEmpty)
                      const _EmptyCell(text: 'TBD')
                    else
                      for (final m in qf) _MatchCard(eventId: eventId, m: m),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(context.l10n.event_bracket_sf),
                      const SizedBox(height: 36),
                      if (sf.isEmpty)
                        const _EmptyCell(text: 'TBD')
                      else ...[
                        _MatchCard(eventId: eventId, m: sf[0]),
                        if (sf.length > 1) ...[
                          const SizedBox(height: 60),
                          _MatchCard(eventId: eventId, m: sf[1]),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(context.l10n.event_bracket_final),
                      const SizedBox(height: 10),
                      if (finalMatch == null)
                        const _EmptyCell(text: 'TBD')
                      else
                        _MatchCard(
                          eventId: eventId,
                          m: finalMatch,
                          isFinal: true,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  final String text;
  const _EmptyCell({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.tokens.elev2,
      border: Border.all(color: context.tokens.line, style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(T.r2),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: T.fontMono,
        fontFamilyFallback: T.monoFallbacks,
        fontSize: 11,
        color: T.inkDim,
      ),
    ),
  );
}

class _MatchCard extends StatelessWidget {
  final String eventId;
  final Match m;
  final bool isFinal;
  const _MatchCard({
    required this.eventId,
    required this.m,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final sa = m.scoreA;
    final sb = m.scoreB;
    final aWins = m.done && sa != null && sb != null && sa > sb;
    final bWins = m.done && sa != null && sb != null && sb > sa;
    final timeStr = m.playedAt != null
        ? '${m.playedAt!.month.toString().padLeft(2, '0')}-${m.playedAt!.day.toString().padLeft(2, '0')} ${m.playedAt!.hour.toString().padLeft(2, '0')}:${m.playedAt!.minute.toString().padLeft(2, '0')}'
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFinal ? T.liveDim : context.tokens.elev2,
        border: Border.all(
          color: isFinal ? T.live : context.tokens.line,
          width: isFinal ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(T.r2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/event/$eventId/match/${m.id}'),
          child: Padding(
            padding: EdgeInsets.all(isFinal ? 0 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFinal)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: T.live, width: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events, size: 14, color: T.live),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.event_bracket_champion,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: T.live,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(isFinal ? 10 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _teamLine(
                        m.teamALabel ?? 'TBD',
                        sa,
                        won: aWins,
                        showWinnerIcon: isFinal,
                      ),
                      const SizedBox(height: 4),
                      _teamLine(
                        m.teamBLabel ?? 'TBD',
                        sb,
                        won: bWins,
                        showWinnerIcon: isFinal,
                      ),
                      if (m.pkScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'PK ${m.pkScore}',
                                style: const TextStyle(
                                  fontFamily: T.fontMono,
                                  fontFamilyFallback: T.monoFallbacks,
                                  fontSize: 9,
                                  color: T.warn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (timeStr != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            timeStr,
                            style: const TextStyle(
                              fontFamily: T.fontMono,
                              fontFamilyFallback: T.monoFallbacks,
                              fontSize: 10,
                              color: T.inkDim,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamLine(
    String name,
    int? score, {
    required bool won,
    bool showWinnerIcon = false,
  }) {
    final nameColor = m.done ? (won ? T.ink : T.inkSub) : T.inkSub;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (showWinnerIcon && won) ...[
                const Icon(Icons.emoji_events, size: 12, color: T.live),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: nameColor,
                    fontWeight: won ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (m.done && score != null)
          N(
            '$score',
            size: 13,
            weight: FontWeight.w700,
            color: won ? T.live : T.inkSub,
          )
        else
          const Text('-', style: TextStyle(color: T.inkDim, fontSize: 11)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Standings (derived client-side from matches)
// ─────────────────────────────────────────────────────────────
class StandingRow {
  final String team;
  int rank = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0, pts = 0;
  StandingRow({required this.team});
}

List<StandingRow> computeStandings(List<Match> matches) {
  final agg = <String, StandingRow>{};
  StandingRow bump(String k) => agg.putIfAbsent(k, () => StandingRow(team: k));
  for (final m in matches) {
    if (!m.done || m.scoreA == null || m.scoreB == null) continue;
    final a = bump(m.teamALabel ?? 'TBD');
    final b = bump(m.teamBLabel ?? 'TBD');
    a.gf += m.scoreA!;
    a.ga += m.scoreB!;
    b.gf += m.scoreB!;
    b.ga += m.scoreA!;
    if (m.scoreA! > m.scoreB!) {
      a.w++;
      b.l++;
      a.pts += 3;
    } else if (m.scoreA! < m.scoreB!) {
      b.w++;
      a.l++;
      b.pts += 3;
    } else {
      a.d++;
      b.d++;
      a.pts++;
      b.pts++;
    }
  }
  final list = agg.values.toList()
    ..sort((x, y) {
      if (y.pts != x.pts) return y.pts.compareTo(x.pts);
      final xd = x.gf - x.ga, yd = y.gf - y.ga;
      if (yd != xd) return yd.compareTo(xd);
      return y.gf.compareTo(x.gf);
    });
  for (int i = 0; i < list.length; i++) {
    list[i].rank = i + 1;
  }
  return list;
}

class _StandingsPanel extends ConsumerWidget {
  final String eventId;
  const _StandingsPanel({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(eventMatchesProvider(eventId))
        .when(
          data: (matches) {
            final rows = computeStandings(matches);
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Label(context.l10n.event_standings_empty2),
                ),
              );
            }
            return _StandingsTable(rows: rows, matches: matches);
          },
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e),
        );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<StandingRow> rows;
  final List<Match> matches;
  const _StandingsTable({required this.rows, required this.matches});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 24, child: Label(l.event_standings_rank)),
                const SizedBox(width: 10),
                Expanded(child: Label(l.event_standings_team)),
                SizedBox(
                  width: 32,
                  child: Center(child: Label(l.event_standings_wins)),
                ),
                SizedBox(
                  width: 32,
                  child: Center(child: Label(l.event_standings_draws)),
                ),
                SizedBox(
                  width: 32,
                  child: Center(child: Label(l.event_standings_losses)),
                ),
                SizedBox(
                  width: 40,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Label(l.event_standings_points),
                  ),
                ),
              ],
            ),
          ),
          for (final s in rows)
            Material(
              color: s.rank <= 2 ? const Color(0x0800FF85) : Colors.transparent,
              child: InkWell(
                onTap: () =>
                    _showTeamSheet(context, standing: s, allMatches: matches),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: N(
                          '${s.rank}',
                          size: 13,
                          weight: FontWeight.w600,
                          color: s.rank <= 2 ? T.live : T.inkSub,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: HSLColor.fromAHSL(
                                  1,
                                  (s.rank * 50).toDouble() % 360,
                                  0.35,
                                  0.3,
                                ).toColor(),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.team,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: T.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.w}', size: 12, color: T.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.d}', size: 12, color: T.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.l}', size: 12, color: T.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: N(
                            '${s.pts}',
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _showTeamSheet(
  BuildContext context, {
  required StandingRow standing,
  required List<Match> allMatches,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _TeamSheet(standing: standing, allMatches: allMatches),
  );
}

class _TeamSheet extends StatelessWidget {
  final StandingRow standing;
  final List<Match> allMatches;
  const _TeamSheet({required this.standing, required this.allMatches});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final own = standing.team;
    final teamMatches =
        allMatches
            .where((m) => m.teamALabel == own || m.teamBLabel == own)
            .toList()
          ..sort((a, b) {
            final at = a.playedAt, bt = b.playedAt;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
    final gd = standing.gf - standing.ga;
    final hue = (standing.rank * 50).toDouble() % 360;
    final teamColor = HSLColor.fromAHSL(1, hue, 0.35, 0.3).toColor();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: T.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: teamColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        standing.team,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${standing.rank}',
                        style: const TextStyle(
                          fontFamily: T.fontMono,
                          fontFamilyFallback: T.monoFallbacks,
                          fontSize: 12,
                          color: T.inkSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Label(l.team_card_summary),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      value: '${standing.pts}',
                      label: l.event_standings_points,
                      accent: T.live,
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      value: '${standing.w}',
                      label: l.event_standings_wins,
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      value: '${standing.d}',
                      label: l.event_standings_draws,
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      value: '${standing.l}',
                      label: l.event_standings_losses,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      value: '${standing.gf}',
                      label: l.team_card_gf,
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      value: '${standing.ga}',
                      label: l.team_card_ga,
                    ),
                  ),
                  Expanded(
                    child: _StatCell(
                      value: gd > 0 ? '+$gd' : '$gd',
                      label: l.team_card_gd,
                      accent: gd > 0
                          ? T.live
                          : gd < 0
                          ? T.inkSub
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Label('${l.team_card_matches} · ${teamMatches.length}'),
            const SizedBox(height: 8),
            Expanded(
              child: teamMatches.isEmpty
                  ? Center(child: Label(l.event_standings_empty2))
                  : ListView.separated(
                      controller: scroll,
                      padding: EdgeInsets.zero,
                      itemCount: teamMatches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          _TeamMatchRow(match: teamMatches[i], ownTeam: own),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamMatchRow extends StatelessWidget {
  final Match match;
  final String ownTeam;
  const _TeamMatchRow({required this.match, required this.ownTeam});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isHome = match.teamALabel == ownTeam;
    final opponent = (isHome ? match.teamBLabel : match.teamALabel) ?? '—';
    final ownScore = isHome ? match.scoreA : match.scoreB;
    final oppScore = isHome ? match.scoreB : match.scoreA;

    String? resultLabel;
    Color? resultColor;
    if (match.done && ownScore != null && oppScore != null) {
      if (ownScore > oppScore) {
        resultLabel = l.event_standings_wins;
        resultColor = T.live;
      } else if (ownScore < oppScore) {
        resultLabel = l.event_standings_losses;
        resultColor = T.inkSub;
      } else {
        resultLabel = l.event_standings_draws;
        resultColor = T.inkMute;
      }
    }

    final dateStr = match.playedAt != null
        ? '${match.playedAt!.month.toString().padLeft(2, '0')}/'
              '${match.playedAt!.day.toString().padLeft(2, '0')}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(T.r2),
      ),
      child: Row(
        children: [
          if (resultLabel != null) ...[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: resultColor!.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                resultLabel,
                style: TextStyle(
                  fontFamily: T.fontMono,
                  fontFamilyFallback: T.monoFallbacks,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: resultColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              opponent,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: T.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (match.done && ownScore != null && oppScore != null)
            N(
              '$ownScore - $oppScore',
              size: 13,
              weight: FontWeight.w700,
              color: resultColor ?? T.ink,
            )
          else
            const Text('-', style: TextStyle(color: T.inkDim, fontSize: 12)),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(width: 10),
            N(dateStr, size: 11, color: T.inkDim),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scorers — `event_scorers` view (goals 表, S3.1 0011 迁移)
// ─────────────────────────────────────────────────────────────
class _ScorersPanel extends ConsumerWidget {
  final String eventId;
  const _ScorersPanel({required this.eventId});
  static const _medal = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventScorersProvider(eventId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: T.live)),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            context.l10n.error_load_failed,
            style: const TextStyle(color: T.inkSub, fontSize: 12),
          ),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                context.l10n.event_scorers_goals,
                style: const TextStyle(color: T.inkSub, fontSize: 12),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++)
                _ScorerCard(
                  rank: i + 1,
                  row: rows[i],
                  medal: _medal,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScorerCard extends ConsumerWidget {
  final int rank;
  final ScorerRow row;
  final List<Color> medal;
  final VoidCallback? onTap;
  const _ScorerCard({
    required this.rank,
    required this.row,
    required this.medal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(T.r2);
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.tokens.elev2,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.tokens.line),
              borderRadius: radius,
            ),
            child: _buildRow(context, avatarUrl),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String? avatarUrl) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Center(
            child: rank <= 3
                ? Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medal[rank - 1],
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontFamily: T.fontMono,
                        fontFamilyFallback: T.monoFallbacks,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Colors.black,
                      ),
                    ),
                  )
                : N(
                    '$rank',
                    size: 14,
                    weight: FontWeight.w600,
                    color: T.inkSub,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        NetworkAvatar(row.name, url: avatarUrl, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: T.ink,
                ),
              ),
              Label(context.l10n.archive_teammates_matches(row.matches)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            N('${row.goals}', size: 22, weight: FontWeight.w700, color: T.live),
            Label(context.l10n.event_scorers_goals),
          ],
        ),
      ],
    );
  }
}

Future<void> _showScorerSheet(
  BuildContext context, {
  required String eventId,
  required ScorerRow row,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ScorerSheet(eventId: eventId, row: row),
  );
}

class _ScorerSheet extends ConsumerWidget {
  final String eventId;
  final ScorerRow row;
  const _ScorerSheet({required this.eventId, required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ratings = ref.watch(eventPlayerRatingsProvider(eventId));
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final profile = profileAsync.valueOrNull;

    PlayerRatingRow? rating;
    final ratingList = ratings.valueOrNull;
    if (ratingList != null && row.scorerId != null) {
      for (final r in ratingList) {
        if (r.rateeId == row.scorerId) {
          rating = r;
          break;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: T.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NetworkAvatar(row.name, url: profile?.avatarUrl, size: 96),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                        ),
                      ),
                      if (_metaLine(profile).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _metaLine(profile),
                          style: const TextStyle(fontSize: 12, color: T.inkSub),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatCell(
                    value: '${row.goals}',
                    label: l.event_scorers_goals,
                    accent: T.live,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    value: '${row.matches}',
                    label: l.player_card_mp,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    value: rating != null
                        ? rating.avgScore.toStringAsFixed(1)
                        : '—',
                    label: l.player_card_rating,
                    sub: rating != null
                        ? l.event_rating_n_voters_inline(rating.votes)
                        : null,
                  ),
                ),
              ],
            ),
            if (profile != null &&
                (profile.height != null ||
                    (profile.foot != null && profile.foot!.isNotEmpty))) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Row(
                  children: [
                    if (profile.height != null)
                      Expanded(
                        child: _InlineStat(
                          label: l.profile_edit_height,
                          value: '${profile.height}',
                        ),
                      ),
                    if (profile.foot != null && profile.foot!.isNotEmpty)
                      Expanded(
                        child: _InlineStat(
                          label: l.profile_edit_foot,
                          value: _footLabel(l, profile.foot!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _metaLine(Profile? p) {
    if (p == null) return '';
    final parts = <String>[];
    if (p.position != null && p.position!.isNotEmpty) parts.add(p.position!);
    if (p.city != null && p.city!.isNotEmpty) {
      if (p.district != null && p.district!.isNotEmpty) {
        parts.add('${p.city} · ${p.district}');
      } else {
        parts.add(p.city!);
      }
    }
    return parts.join(' · ');
  }

  String _footLabel(AppL10n l, String raw) {
    switch (raw.toLowerCase()) {
      case 'left':
        return l.profile_edit_foot_left;
      case 'right':
        return l.profile_edit_foot_right;
      case 'both':
        return l.profile_edit_foot_both;
      default:
        return raw;
    }
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String? sub;
  final Color? accent;
  const _StatCell({
    required this.value,
    required this.label,
    this.sub,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        N(value, size: 22, weight: FontWeight.w700, color: accent ?? T.ink),
        const SizedBox(height: 4),
        Label(label),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, style: const TextStyle(fontSize: 10, color: T.inkDim)),
        ],
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Label(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: T.ink,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Chat — realtime via Supabase conversations (one per event)
// ─────────────────────────────────────────────────────────────
class _ChatPanel extends ConsumerStatefulWidget {
  final String eventId;
  const _ChatPanel({required this.eventId});

  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  final _inputC = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _inputC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputC.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final convId = await ref.read(
        eventChatConvProvider(widget.eventId).future,
      );
      await ref.read(messagesRepoProvider).send(convId, text);
      _inputC.clear();
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.chat_send_failed, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(eventChatMessagesProvider(widget.eventId));
    return Container(
      padding: const EdgeInsets.all(14),
      color: context.tokens.elev1,
      constraints: const BoxConstraints(minHeight: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            data: (msgs) {
              if (msgs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      l.empty_no_messages,
                      style: const TextStyle(color: T.inkDim, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final m in msgs.reversed) _Msg(msg: m)],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: T.live, strokeWidth: 2),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '${l.error_load_failed}: $e',
                  style: const TextStyle(color: T.inkSub, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _inputC,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(color: T.ink, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l.event_chat_hint,
                      hintStyle: const TextStyle(color: T.inkDim, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: T.live,
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, size: 14, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  final Message msg;
  const _Msg({required this.msg});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final sender = msg.senderId == currentUserId
        ? l.event_chat_sender_you
        : l.event_chat_sender_stranger;
    final hh = msg.createdAt.hour.toString().padLeft(2, '0');
    final mm = msg.createdAt.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(sender, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sender,
                      style: const TextStyle(
                        fontSize: 12,
                        color: T.inkSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Label('$hh:$mm'),
                  ],
                ),
                Text(
                  msg.body ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: T.ink,
                    height: 1.5,
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

// ─────────────────────────────────────────────────────────────
// Bottom CTA: watch live + register team
// ─────────────────────────────────────────────────────────────
class _BottomCta extends ConsumerWidget {
  final Event event;
  const _BottomCta({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final registered = LocalStore.isEventFavorited(event.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              variant: BtnVariant.ghost,
              size: BtnSize.lg,
              full: true,
              onPressed: () => context.push('/worldcup/live/${event.id}'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tv, size: 16, color: T.ink),
                  const SizedBox(width: 6),
                  Text(
                    l.event_cta_watch_live,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: T.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PrimaryButton(
              label: registered ? l.event_cta_registered : l.event_cta_register,
              variant: registered ? BtnVariant.secondary : BtnVariant.primary,
              size: BtnSize.lg,
              full: true,
              onPressed: registered
                  ? null
                  : () => _showRegisterSheet(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRegisterSheet(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final teamC = TextEditingController();
    final contactC = TextEditingController();
    final phoneC = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: T.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.event_register_form_title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: T.ink,
                ),
              ),
              const SizedBox(height: 16),
              _RegField(label: l.event_register_team_name, controller: teamC),
              _RegField(label: l.event_register_contact, controller: contactC),
              _RegField(
                label: l.event_register_phone,
                controller: phoneC,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: l.event_register_submit,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: () async {
                  if (teamC.text.trim().isEmpty) {
                    showToast(ctx, l.error_required_field, error: true);
                    return;
                  }
                  try {
                    await ref
                        .read(messagesRepoProvider)
                        .createConversation(
                          title: 'event:${event.id}:reg:${teamC.text.trim()}',
                          kind: 'team',
                        );
                  } catch (_) {
                    /* ignore: registration in offline / mock mode still persists locally. */
                  }
                  await ref
                      .read(favoritesRepoProvider)
                      .toggle(FavoriteEntity.event, event.id);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    showToast(context, l.event_register_success, success: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _RegField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(color: T.ink, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _deterministicViewers(String eventId) {
  final h = eventId.hashCode.abs();
  final n = 800 + h % 48000;
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ─────────────────────────────────────────────────────────────
// Ratings — leaderboard from event_player_ratings view
// ─────────────────────────────────────────────────────────────
class RatingsPanel extends ConsumerStatefulWidget {
  final Event event;
  const RatingsPanel({super.key, required this.event});

  @override
  ConsumerState<RatingsPanel> createState() => _RatingsPanelState();
}

enum _RatingsView { thisMatch, event }

class _RatingsPanelState extends ConsumerState<RatingsPanel> {
  PlayerRatingRow? _selected;
  _RatingsView _view = _RatingsView.thisMatch;
  Match? _pickedMatch;
  String _teamFilter = 'all'; // 'all' / 'a' / 'b'

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return _PlayerRatingDetail(
        player: _selected!,
        event: widget.event,
        onBack: () => setState(() => _selected = null),
      );
    }

    final matchesAsync = ref.watch(eventMatchesProvider(widget.event.id));
    return matchesAsync.when(
      loading: () => const _PanelLoading(),
      error: (e, _) => _PanelError(e),
      data: (matches) {
        final finished = matches.where((m) => m.done).toList();
        // Default pick: most recent finished match (list is ordered played_at asc)
        final picked =
            _pickedMatch ?? (finished.isNotEmpty ? finished.last : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ViewToggle(
              view: _view,
              hasMatch: picked != null,
              onChange: (v) => setState(() => _view = v),
            ),
            if (_view == _RatingsView.thisMatch)
              picked == null
                  ? _EmptyNote(context.l10n.event_rating_no_matches)
                  : _ThisMatchSection(
                      event: widget.event,
                      match: picked,
                      allMatches: finished,
                      teamFilter: _teamFilter,
                      onPickMatch: (m) => setState(() {
                        _pickedMatch = m;
                        _teamFilter = 'all';
                      }),
                      onFilter: (f) => setState(() => _teamFilter = f),
                      onOpenPlayer: (p) => setState(() => _selected = p),
                    )
            else
              _EventWideSection(
                event: widget.event,
                onOpenPlayer: (p) => setState(() => _selected = p),
              ),
          ],
        );
      },
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final _RatingsView view;
  final bool hasMatch;
  final ValueChanged<_RatingsView> onChange;
  const _ViewToggle({
    required this.view,
    required this.hasMatch,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (_RatingsView.thisMatch, l.event_rating_view_this_match, hasMatch),
      (_RatingsView.event, l.event_rating_view_event, true),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          for (final it in items) ...[
            GestureDetector(
              onTap: it.$3 ? () => onChange(it.$1) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: view == it.$1 ? T.liveDim : Colors.transparent,
                  border: Border.all(color: view == it.$1 ? T.live : context.tokens.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Text(
                  it.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: view == it.$1
                        ? T.live
                        : (it.$3 ? T.inkSub : T.inkDim),
                  ),
                ),
              ),
            ),
            if (it != items.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(child: Label(text)),
  );
}

// ─────────────────────────────────────────────────────────────
// "This match" view — score strip + match picker + team filter
// ─────────────────────────────────────────────────────────────
class _ThisMatchSection extends ConsumerWidget {
  final Event event;
  final Match match;
  final List<Match> allMatches;
  final String teamFilter;
  final ValueChanged<Match> onPickMatch;
  final ValueChanged<String> onFilter;
  final ValueChanged<PlayerRatingRow> onOpenPlayer;

  const _ThisMatchSection({
    required this.event,
    required this.match,
    required this.allMatches,
    required this.teamFilter,
    required this.onPickMatch,
    required this.onFilter,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchPlayerRatingsProvider(match));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allMatches.length > 1)
          _MatchPicker(matches: allMatches, picked: match, onPick: onPickMatch),
        _ScoreStrip(event: event, match: match),
        async.when(
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e),
          data: (rows) {
            final visible = rows.where((r) => r.name != '—').toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TeamFilterRow(
                  match: match,
                  total: visible.length,
                  selected: teamFilter,
                  onChange: onFilter,
                ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Label(context.l10n.event_rating_empty_go_rate),
                    ),
                  )
                else
                  for (int i = 0; i < visible.length; i++)
                    GestureDetector(
                      onTap: () => onOpenPlayer(visible[i]),
                      child: _PlayerRow(
                        p: visible[i],
                        rank: i + 1,
                        showMomentBlock: true,
                      ),
                    ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Label(context.l10n.event_rating_tap_for_detail),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MatchPicker extends StatelessWidget {
  final List<Match> matches;
  final Match picked;
  final ValueChanged<Match> onPick;
  const _MatchPicker({
    required this.matches,
    required this.picked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final m = matches[i];
        final isPicked = m.id == picked.id;
        final a = m.teamALabel ?? '—';
        final b = m.teamBLabel ?? '—';
        final score = '${m.scoreA ?? 0}-${m.scoreB ?? 0}';
        return GestureDetector(
          onTap: () => onPick(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPicked ? T.liveDim : context.tokens.elev2,
              border: Border.all(color: isPicked ? T.live : context.tokens.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Row(
              children: [
                Text(
                  '$a  $score  $b',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPicked ? T.live : T.inkSub,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ScoreStrip extends StatelessWidget {
  final Event event;
  final Match match;
  const _ScoreStrip({required this.event, required this.match});

  @override
  Widget build(BuildContext context) {
    final a = match.teamALabel ?? '—';
    final b = match.teamBLabel ?? '—';
    final sa = match.scoreA ?? 0;
    final sb = match.scoreB ?? 0;
    final winA = sa > sb;
    final winB = sb > sa;
    final date = match.playedAt;
    final dateStr = date == null
        ? ''
        : '${date.year.toString().padLeft(4, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.day.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, 150, 0.25, 0.18).toColor(),
            HSLColor.fromAHSL(1, 150, 0.10, 0.12).toColor(),
          ],
        ),
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(T.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: T.liveDim,
                  border: Border.all(color: T.live.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  event.name,
                  style: const TextStyle(
                    fontFamily: T.fontMono,
                    fontFamilyFallback: T.monoFallbacks,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: T.live,
                  ),
                ),
              ),
              if (match.round != null) ...[
                const SizedBox(width: 6),
                Label('· ${match.round}'),
              ],
              const Spacer(),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontFamily: T.fontMono,
                    fontFamilyFallback: T.monoFallbacks,
                    fontSize: 11,
                    color: T.inkSub,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  a,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: winA ? T.ink : T.inkSub,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              N(
                '$sa',
                size: 26,
                weight: FontWeight.w800,
                color: winA ? T.live : T.ink,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: N(
                  '-',
                  size: 22,
                  weight: FontWeight.w800,
                  color: T.inkSub,
                ),
              ),
              N(
                '$sb',
                size: 26,
                weight: FontWeight.w800,
                color: winB ? T.live : T.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: winB ? T.ink : T.inkSub,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamFilterRow extends StatelessWidget {
  final Match match;
  final int total;
  final String selected;
  final ValueChanged<String> onChange;
  const _TeamFilterRow({
    required this.match,
    required this.total,
    required this.selected,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget chip(String value, String text) {
      final active = value == selected;
      return GestureDetector(
        onTap: () => onChange(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? T.ink : context.tokens.elev2,
            border: Border.all(color: active ? T.ink : context.tokens.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? context.tokens.bg : T.inkSub,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          chip('all', '${l.event_rating_team_all} $total'),
          const SizedBox(width: 8),
          if (match.teamALabel != null) chip('a', match.teamALabel!),
          if (match.teamALabel != null) const SizedBox(width: 8),
          if (match.teamBLabel != null) chip('b', match.teamBLabel!),
          const Spacer(),
          Label(l.event_rating_players_voted(total)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// "Event-wide" view — original leaderboard (now with enhanced rows)
// ─────────────────────────────────────────────────────────────
class _EventWideSection extends ConsumerWidget {
  final Event event;
  final ValueChanged<PlayerRatingRow> onOpenPlayer;
  const _EventWideSection({required this.event, required this.onOpenPlayer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventPlayerRatingsProvider(event.id));
    return async.when(
      loading: () => const _PanelLoading(),
      error: (e, _) => _PanelError(e),
      data: (rows) {
        final visible = rows.where((r) => r.name != '—').toList();
        final totalVotes = visible.fold<int>(0, (s, r) => s + r.votes);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSLColor.fromAHSL(1, 150, 0.25, 0.18).toColor(),
                      HSLColor.fromAHSL(1, 150, 0.10, 0.12).toColor(),
                    ],
                  ),
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(T.r3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: T.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Label(
                          context.l10n.event_rating_players_count(
                            visible.length,
                          ),
                        ),
                        const Spacer(),
                        Label(
                          context.l10n.event_rating_votes_count(totalVotes),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Label(context.l10n.event_rating_empty_go_rate),
                ),
              )
            else
              for (int i = 0; i < visible.length; i++)
                GestureDetector(
                  onTap: () => onOpenPlayer(visible[i]),
                  child: _PlayerRow(p: visible[i], rank: i + 1),
                ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Label(context.l10n.event_rating_tap_for_detail),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerRatingRow p;
  final int rank;
  final bool showMomentBlock;
  const _PlayerRow({
    required this.p,
    required this.rank,
    this.showMomentBlock = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final you = p.rateeId == currentUserId;
    final scoreColor = p.avgScore >= 8
        ? T.live
        : (p.avgScore >= 6 ? T.ink : T.danger);
    final hasMoment = showMomentBlock && (p.topComment?.isNotEmpty ?? false);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: rank == 1 ? T.live : context.tokens.line),
        borderRadius: BorderRadius.circular(T.r3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? T.live
                  : (rank <= 3 ? context.tokens.elev3 : Colors.transparent),
              border: rank == 1 ? null : Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: rank == 1 ? Colors.black : T.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Avatar(p.name, size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: T.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (you) _tinyBadge(l.rate_short_you, T.liveDim, T.live),
                    if (rank == 1)
                      _tinyBadge(l.event_rating_mvp, T.liveDim, T.live),
                    if (p.topHighlight != null && p.topHighlight!.isNotEmpty)
                      _statChip(p.topHighlight!),
                  ],
                ),
                const SizedBox(height: 3),
                Label(
                  [
                    if (p.position != null) p.position!,
                    l.event_rating_n_voters_inline(p.votes),
                  ].join(' · '),
                ),
                if (hasMoment) ...[
                  const SizedBox(height: 8),
                  _MomentQuote(text: p.topComment!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                N(
                  p.avgScore.toStringAsFixed(1),
                  size: 22,
                  weight: FontWeight.w800,
                  color: scoreColor,
                ),
                const SizedBox(height: 2),
                Label(l.event_rating_score_avg),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.chevron_right, size: 12, color: T.inkDim),
          ),
        ],
      ),
    );
  }

  Widget _tinyBadge(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: fg.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: T.fontMono,
        fontFamilyFallback: T.monoFallbacks,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    ),
  );

  Widget _statChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x22FF6D3B),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0x55FF6D3B)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: T.fontMono,
        fontFamilyFallback: T.monoFallbacks,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFFFFB38A),
      ),
    ),
  );
}

class _MomentQuote extends StatelessWidget {
  final String text;
  const _MomentQuote({required this.text});
  @override
  Widget build(BuildContext context) {
    final trimmed = text.length > 28 ? '${text.substring(0, 28)}…' : text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.tokens.elev3,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(T.r2),
      ),
      child: Row(
        children: [
          const Icon(Icons.format_quote, size: 12, color: T.inkSub),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              trimmed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: T.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRatingDetail extends ConsumerWidget {
  final VoidCallback onBack;
  final PlayerRatingRow player;
  final Event event;
  const _PlayerRatingDetail({
    required this.onBack,
    required this.player,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = player;
    // Phase 2: 用真 ratings 聚合。目前 histogram + comments 使用 mock 兜底。
    final dist = mock.ratingDist;
    final maxD = dist.reduce(math.max);
    final comments = mock.topComments;
    final you = p.rateeId == currentUserId;
    final scoreColor = p.avgScore >= 8
        ? T.live
        : (p.avgScore >= 6 ? T.ink : T.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: T.ink,
                ),
              ),
              const SizedBox(width: 8),
              Label(context.l10n.event_rating_player_detail),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HSLColor.fromAHSL(1, 150, 0.25, 0.18).toColor(),
                HSLColor.fromAHSL(1, 150, 0.10, 0.12).toColor(),
              ],
            ),
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(T.r3),
          ),
          child: Row(
            children: [
              Avatar(p.name, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
                          ),
                        ),
                        if (you) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: T.liveDim,
                              border: Border.all(
                                color: const Color(0x6600FF85),
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              context.l10n.rate_short_you,
                              style: const TextStyle(
                                fontFamily: T.fontMono,
                                fontFamilyFallback: T.monoFallbacks,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: T.live,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Label(
                      [
                        if (p.position != null) p.position!,
                        event.name,
                      ].join(' · '),
                    ),
                    const SizedBox(height: 8),
                    Label(context.l10n.event_rating_players_voted(p.votes)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  N(
                    p.avgScore.toStringAsFixed(2),
                    size: 42,
                    weight: FontWeight.w800,
                    color: scoreColor,
                  ),
                  const SizedBox(height: 4),
                  Label(context.l10n.event_rating_score_avg),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(context.l10n.event_rating_distribution),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 70,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < dist.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: FractionallySizedBox(
                                  heightFactor: dist[i] / maxD,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: i >= 8
                                          ? T.live
                                          : i >= 6
                                          ? T.ink
                                          : i >= 4
                                          ? T.inkSub
                                          : T.danger,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(2),
                                        topRight: Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < dist.length; i++)
                          Expanded(
                            child: Center(
                              child: Text(
                                '$i',
                                style: const TextStyle(
                                  fontFamily: T.fontMono,
                                  fontFamilyFallback: T.monoFallbacks,
                                  fontSize: 9,
                                  color: T.inkDim,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Label(context.l10n.event_rating_hot_comments),
                  const Spacer(),
                  Label(context.l10n.event_rating_sort_hot),
                ],
              ),
              const SizedBox(height: 10),
              for (final c in comments)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(T.r2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(c.user, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            c.user,
                            style: const TextStyle(
                              fontSize: 12,
                              color: T.inkSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.score >= 8
                                  ? T.liveDim
                                  : c.score >= 6
                                  ? context.tokens.elev3
                                  : const Color(0x24FF3B6B),
                              border: Border.all(
                                color: c.score >= 8
                                    ? T.live.withValues(alpha: 0.3)
                                    : c.score >= 6
                                    ? context.tokens.line
                                    : T.danger.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${c.score}.0',
                              style: TextStyle(
                                fontFamily: T.fontMono,
                                fontFamilyFallback: T.monoFallbacks,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.score >= 8
                                    ? T.live
                                    : c.score >= 6
                                    ? T.ink
                                    : T.danger,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Label(c.time),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: T.ink,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 12,
                            color: T.inkSub,
                          ),
                          const SizedBox(width: 4),
                          N('${c.likes}', size: 11, color: T.inkSub),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: T.inkSub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.event_rating_reply,
                            style: const TextStyle(
                              fontSize: 11,
                              color: T.inkSub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
