// event_detail_screen.dart — 赛事详情 (5 tabs)
//
// Live tabs:  overview (from event row) · bracket / standings (from matches)
//             · scorers (from goals table)
// Mock tabs:  chat   (needs chat schema, Session D)
//
// 球员评分已移至比赛详情子页：/event/:eventId/match/:matchId/ratings
// 文件 match_ratings_screen.dart。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/demo_images.dart';
import '../../data/demo_team_assets.dart';
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
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/network_cover.dart';
import '../../widgets/primary_button.dart';
import '../../services/storage.dart';
import '../../widgets/rich_input.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/team_badge.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

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
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
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
            Icon(Icons.error_outline, size: 32, color: context.tokens.danger),
            const SizedBox(height: 8),
            Text(
              '${l.error_load_failed}: $e',
              style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
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
                  style: TextStyle(color: context.tokens.ink, fontSize: 12),
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
      ('chat', l.event_tab_chat),
    ];
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Cover 240 + KpiStrip ~62 + Tabs ~47 = ~349 above; reserve 110 for CTA.
        final panelMinHeight = (constraints.maxHeight - 349 - 110)
            .clamp(0.0, double.infinity);
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: _tab == 'chat' ? 166 : 110),
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
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: panelMinHeight),
                    child: switch (_tab) {
                      'overview' => _OverviewPanel(event: event),
                      'bracket' => _BracketPanel(eventId: event.id),
                      'standings' => _StandingsPanel(eventId: event.id),
                      'scorers' => _ScorersPanel(eventId: event.id),
                      _ => _ChatPanel(eventId: event.id),
                    },
                  ),
                ],
              ),
            ),
            if (_tab == 'chat')
              Positioned(
                bottom: 96,
                left: 0,
                right: 0,
                child: _ChatInput(eventId: event.id),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomCta(event: event),
            ),
          ],
        );
      },
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
      EventStatus.ongoing => (context.tokens.accent, context.tokens.accent, l.event_status_ongoing),
      EventStatus.registering => (context.tokens.warn, context.tokens.warn, l.event_status_registering),
      EventStatus.completed => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
      _ => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
    };
    return Stack(
      children: [
        NetworkCover(
          url: (event.coverUrl?.isNotEmpty ?? false)
              ? event.coverUrl
              : DemoImages.pickCoverFor(event.id),
          fallbackLabel: context.l10n.event_overview_main_visual(event.name),
          height: 240,
          hue: hue,
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 1.0],
                colors: [
                  Color(0x33000000),
                  Color(0x66000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => shareEvent(event),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.ios_share,
                  size: 16,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
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
                    Label('· ${event.sub!}', color: const Color(0xCCFFFFFF)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
            ],
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
      data: (list) => '${list.where((m) => m.status == MatchStatus.finished).length}/${list.length}',
      orElse: () => '-',
    );
    final l = context.l10n;
    final prizeStr = prizeCents != null
        ? l.create_event_preview_prize_wan(
            (prizeCents! / 1000000).toStringAsFixed(1),
          )
        : '-';
    final teamsRegistered = ref.watch(eventTeamsCountProvider(eventId)).valueOrNull ?? 0;
    final items = [
      (l.event_kpi_teams, teamsMax != null ? '$teamsRegistered/$teamsMax' : '$teamsRegistered'),
      (l.event_kpi_matches, matchesStr),
      (l.event_kpi_prize, prizeStr),
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
                      color: context.tokens.ink,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (final t in tabs)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChange(t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: current == t.$1 ? context.tokens.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: current == t.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: current == t.$1 ? context.tokens.ink : context.tokens.inkSub,
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(36),
    child: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
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
        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.tokens.elev1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: TextStyle(fontSize: 14, color: context.tokens.ink, height: 1.6),
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
                      color: context.tokens.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r,
                    style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
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
              borderRadius: BorderRadius.circular(context.tokens.r2),
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.ink,
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
      borderRadius: BorderRadius.circular(context.tokens.r2),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: 11,
        color: context.tokens.inkDim,
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
    final aWins = m.status == MatchStatus.finished && sa != null && sb != null && sa > sb;
    final bWins = m.status == MatchStatus.finished && sa != null && sb != null && sb > sa;
    final timeStr = m.playedAt != null
        ? '${m.playedAt!.month.toString().padLeft(2, '0')}-${m.playedAt!.day.toString().padLeft(2, '0')} ${m.playedAt!.hour.toString().padLeft(2, '0')}:${m.playedAt!.minute.toString().padLeft(2, '0')}'
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFinal ? context.tokens.accentSubtle : context.tokens.elev2,
        border: Border.all(
          color: isFinal ? context.tokens.accent : context.tokens.line,
          width: isFinal ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (m.status == MatchStatus.live) {
              context.push('/event/$eventId/match/${m.id}/live');
            } else {
              context.push('/event/$eventId/match/${m.id}');
            }
          },
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
                        bottom: BorderSide(color: context.tokens.accent, width: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, size: 14, color: context.tokens.accent),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.event_bracket_champion,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.accent,
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
                      if (m.status == MatchStatus.live)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      if (m.status == MatchStatus.live) const SizedBox(height: 4),
                      _teamLine(
                        context,
                        m.teamALabel ?? 'TBD',
                        sa,
                        won: aWins,
                        showWinnerIcon: isFinal,
                      ),
                      const SizedBox(height: 4),
                      _teamLine(
                        context,
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
                                style: TextStyle(
                                  fontFamily: context.tokens.fontMono,
                                  fontFamilyFallback: context.tokens.monoFallbacks,
                                  fontSize: 9,
                                  color: context.tokens.warn,
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
                            style: TextStyle(
                              fontFamily: context.tokens.fontMono,
                              fontFamilyFallback: context.tokens.monoFallbacks,
                              fontSize: 10,
                              color: context.tokens.inkDim,
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
    BuildContext context,
    String name,
    int? score, {
    required bool won,
    bool showWinnerIcon = false,
  }) {
    final nameColor = m.status == MatchStatus.finished ? (won ? context.tokens.ink : context.tokens.inkSub) : context.tokens.inkSub;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (showWinnerIcon && won) ...[
                Icon(Icons.emoji_events, size: 12, color: context.tokens.accent),
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
        if (m.status == MatchStatus.finished && score != null)
          N(
            '$score',
            size: 13,
            weight: FontWeight.w700,
            color: won ? context.tokens.accent : context.tokens.inkSub,
          )
        else
          Text('-', style: TextStyle(color: context.tokens.inkDim, fontSize: 11)),
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
    if (m.status != MatchStatus.finished || m.scoreA == null || m.scoreB == null) continue;
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
          if (rows.length >= 2)
            _StandingsHero(top: rows[0], runner: rows[1], allMatches: matches),
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
                    vertical: 14,
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
                          color: s.rank <= 2 ? context.tokens.accent : context.tokens.inkSub,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            TeamBadge(
                              name: s.team,
                              logoUrl: DemoTeamAssets.forTeamName(s.team).logoUrl,
                              size: 44,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.team,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.tokens.ink,
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
                          child: N('${s.w}', size: 12, color: context.tokens.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.d}', size: 12, color: context.tokens.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.l}', size: 12, color: context.tokens.inkSub),
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
                  color: context.tokens.inkMute,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${standing.rank}',
                        style: TextStyle(
                          fontFamily: context.tokens.fontMono,
                          fontFamilyFallback: context.tokens.monoFallbacks,
                          fontSize: 12,
                          color: context.tokens.inkSub,
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
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      value: '${standing.pts}',
                      label: l.event_standings_points,
                      accent: context.tokens.accent,
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
                borderRadius: BorderRadius.circular(context.tokens.r2),
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
                          ? context.tokens.accent
                          : gd < 0
                          ? context.tokens.inkSub
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
    if (match.status == MatchStatus.finished && ownScore != null && oppScore != null) {
      if (ownScore > oppScore) {
        resultLabel = l.event_standings_wins;
        resultColor = context.tokens.accent;
      } else if (ownScore < oppScore) {
        resultLabel = l.event_standings_losses;
        resultColor = context.tokens.inkSub;
      } else {
        resultLabel = l.event_standings_draws;
        resultColor = context.tokens.inkMute;
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
        borderRadius: BorderRadius.circular(context.tokens.r2),
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
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
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
              style: TextStyle(
                fontSize: 13,
                color: context.tokens.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (match.status == MatchStatus.finished && ownScore != null && oppScore != null)
            N(
              '$ownScore - $oppScore',
              size: 13,
              weight: FontWeight.w700,
              color: resultColor ?? context.tokens.ink,
            )
          else
            Text('-', style: TextStyle(color: context.tokens.inkDim, fontSize: 12)),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(width: 10),
            N(dateStr, size: 11, color: context.tokens.inkDim),
          ],
        ],
      ),
    );
  }
}

class _StandingsHero extends StatelessWidget {
  final StandingRow top;
  final StandingRow runner;
  final List<Match> allMatches;

  const _StandingsHero({
    required this.top,
    required this.runner,
    required this.allMatches,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final diff = top.pts - runner.pts;
    final accent = context.tokens.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: accent.withAlpha(0x66)),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Label(l.event_standings_leaders_label),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _StandingsHeroSide(
                  standing: top,
                  subLabel: l.event_standings_leader_top,
                  subLabelColor: accent,
                  allMatches: allMatches,
                ),
              ),
              SizedBox(
                width: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        N(
                          '${top.pts}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: accent,
                        ),
                        Text(
                          ' - ',
                          style: TextStyle(
                            color: context.tokens.inkDim,
                            fontSize: 18,
                          ),
                        ),
                        N(
                          '${runner.pts}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: context.tokens.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Label(l.event_standings_points_diff(diff)),
                  ],
                ),
              ),
              Expanded(
                child: _StandingsHeroSide(
                  standing: runner,
                  subLabel: l.event_standings_leader_runner,
                  subLabelColor: context.tokens.inkSub,
                  allMatches: allMatches,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandingsHeroSide extends StatelessWidget {
  final StandingRow standing;
  final String subLabel;
  final Color subLabelColor;
  final List<Match> allMatches;

  const _StandingsHeroSide({
    required this.standing,
    required this.subLabel,
    required this.subLabelColor,
    required this.allMatches,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.r2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _showTeamSheet(
          context,
          standing: standing,
          allMatches: allMatches,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamBadge(
                name: standing.team,
                logoUrl: DemoTeamAssets.forTeamName(standing.team).logoUrl,
                size: 72,
              ),
              const SizedBox(height: 6),
              Text(
                standing.team,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Label(subLabel, color: subLabelColor),
            ],
          ),
        ),
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
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            context.l10n.error_load_failed,
            style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
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
                style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              _GoldenBootHero(
                row: rows[0],
                onTap: () =>
                    _showScorerSheet(context, eventId: eventId, row: rows[0]),
              ),
              if (rows.length >= 2)
                _MedalCard(
                  rank: 2,
                  row: rows[1],
                  kind: _MedalKind.silver,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[1]),
                ),
              if (rows.length >= 3)
                _MedalCard(
                  rank: 3,
                  row: rows[2],
                  kind: _MedalKind.bronze,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[2]),
                ),
              for (int i = 3; i < rows.length; i++)
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

class _GoldenBootHero extends ConsumerWidget {
  final ScorerRow row;
  final VoidCallback? onTap;

  const _GoldenBootHero({required this.row, this.onTap});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final radius = BorderRadius.circular(context.tokens.r3);
    final perMatch = row.matches > 0
        ? (row.goals / row.matches).toStringAsFixed(2)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0x14FFD700),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x66FFD700)),
              borderRadius: radius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatar(
                    row.name,
                    url: avatarUrl,
                    size: 96,
                    square: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(
                        l.event_scorers_golden_boot,
                        color: context.tokens.accent,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (perMatch != null)
                        Label(l.event_scorers_per_match(perMatch))
                      else
                        Label(l.archive_teammates_matches(row.matches)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    N(
                      '${row.goals}',
                      size: 32,
                      weight: FontWeight.w800,
                      color: context.tokens.accent,
                    ),
                    Label(l.event_scorers_goals),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _MedalKind { silver, bronze }

class _MedalCard extends ConsumerWidget {
  final ScorerRow row;
  final int rank;
  final _MedalKind kind;
  final VoidCallback? onTap;

  const _MedalCard({
    required this.row,
    required this.rank,
    required this.kind,
    this.onTap,
  });

  Color get _medalColor => kind == _MedalKind.silver
      ? const Color(0xFFC0C0C0)
      : const Color(0xFFCD7F32);

  Color get _medalBorder => kind == _MedalKind.silver
      ? const Color(0x66C0C0C0)
      : const Color(0x66CD7F32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final radius = BorderRadius.circular(context.tokens.r2);
    final perMatch = row.matches > 0
        ? (row.goals / row.matches).toStringAsFixed(2)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.tokens.elev2,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _medalBorder),
              borderRadius: radius,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _medalColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontFamily: context.tokens.fontMono,
                      fontFamilyFallback: context.tokens.monoFallbacks,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _medalColor, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatar(
                    row.name,
                    url: avatarUrl,
                    size: 72,
                    square: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (perMatch != null)
                        Label(l.event_scorers_per_match(perMatch))
                      else
                        Label(l.archive_teammates_matches(row.matches)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    N(
                      '${row.goals}',
                      size: 24,
                      weight: FontWeight.w700,
                      color: context.tokens.accent,
                    ),
                    Label(l.event_scorers_goals),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    final radius = BorderRadius.circular(context.tokens.r2);
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
                      style: TextStyle(
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
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
                    color: context.tokens.inkSub,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        NetworkAvatar(row.name, url: avatarUrl, size: 48, square: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.ink,
                ),
              ),
              Label(context.l10n.archive_teammates_matches(row.matches)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            N('${row.goals}', size: 22, weight: FontWeight.w700, color: context.tokens.accent),
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
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NetworkAvatar(row.name, url: profile?.avatarUrl, size: 96, square: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      if (_metaLine(profile).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _metaLine(profile),
                          style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
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
                    accent: context.tokens.accent,
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
                  borderRadius: BorderRadius.circular(context.tokens.r2),
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
        N(value, size: 22, weight: FontWeight.w700, color: accent ?? context.tokens.ink),
        const SizedBox(height: 4),
        Label(label),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, style: TextStyle(fontSize: 10, color: context.tokens.inkDim)),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.tokens.ink,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Chat — realtime via Supabase conversations (one per event)
// ─────────────────────────────────────────────────────────────
class _ChatPanel extends ConsumerWidget {
  final String eventId;
  const _ChatPanel({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(eventChatMessagesProvider(eventId));
    return Container(
      padding: const EdgeInsets.all(14),
      color: context.tokens.elev1,
      child: async.when(
        data: (msgs) {
          if (msgs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  l.empty_no_messages,
                  style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final m in msgs.reversed) _Msg(msg: m)],
          );
        },
        loading: () => Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              '${l.error_load_failed}: $e',
              style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends ConsumerStatefulWidget {
  final String eventId;
  const _ChatInput({required this.eventId});

  @override
  ConsumerState<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<_ChatInput> {
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

  Future<void> _pickAndSendImage() async {
    final convId = await ref.read(
      eventChatConvProvider(widget.eventId).future,
    );
    final url = await StorageService().pickCropCompressAndUpload(
      bucket: 'chat-images',
      pathPrefix: convId,
      square: false,
    );
    if (url == null || !mounted) return;
    try {
      await ref.read(messagesRepoProvider).send(convId, url, kind: 'image');
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.chat_send_failed, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichInput(
      controller: _inputC,
      onSend: _send,
      sending: _sending,
      showAttachments: true,
      onPickImage: _pickAndSendImage,
      hintText: context.l10n.event_chat_hint,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.inkSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Label('$hh:$mm'),
                  ],
                ),
                if (msg.kind == 'image' && msg.body != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180, maxHeight: 220),
                        child: CachedNetworkImage(
                          imageUrl: msg.body!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            width: 140,
                            height: 100,
                            color: context.tokens.elev3,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: context.tokens.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 140,
                            height: 60,
                            color: context.tokens.elev3,
                            child: Icon(Icons.broken_image, color: context.tokens.inkDim),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    msg.body ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.ink,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (event.creatorId == currentUserId) ...[
            if (event.status == EventStatus.registering)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrimaryButton(
                  label: l.event_close_registration,
                  full: true,
                  size: BtnSize.lg,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.event_close_registration),
                        content: Text(l.event_close_registration_confirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.scheduling);
                    ref.invalidate(eventDetailProvider(event.id));
                  },
                ),
              ),
            if (event.status == EventStatus.scheduling)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrimaryButton(
                  label: l.schedule_generate,
                  full: true,
                  size: BtnSize.lg,
                  onPressed: () => context.push('/event/${event.id}/schedule'),
                ),
              ),
          ],
          Row(
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
                      Icon(Icons.tv, size: 16, color: context.tokens.ink),
                      const SizedBox(width: 6),
                      Text(
                        l.event_cta_watch_live,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
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
                    color: context.tokens.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.event_register_form_title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.ink,
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
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(color: context.tokens.ink, fontSize: 14),
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

