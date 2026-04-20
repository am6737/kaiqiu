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
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/photo_halftone.dart';
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
  static const _tabs = [
    ('overview', '概览'),
    ('bracket', '赛程'),
    ('standings', '积分榜'),
    ('scorers', '射手榜'),
    ('ratings', '评分榜'),
    ('chat', '讨论'),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: T.bg,
      body: async.when(
        data: (event) => _buildContent(event),
        loading: () => const Center(
          child: CircularProgressIndicator(color: T.live),
        ),
        error: (e, _) => _buildError(e),
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: T.danger),
            const SizedBox(height: 8),
            Text('加载失败: $e',
                style: const TextStyle(fontSize: 13, color: T.inkSub)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(eventDetailProvider(widget.id)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: T.elev3,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('重试',
                    style: TextStyle(color: T.ink, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Event event) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(event: event, onBack: () => context.pop()),
              _KpiStrip(eventId: event.id, prizeCents: event.prizeCents,
                  teamsMax: event.teamsMax),
              _Tabs(
                current: _tab,
                tabs: _tabs,
                onChange: (v) => setState(() => _tab = v),
              ),
              switch (_tab) {
                'overview' => _OverviewPanel(event: event),
                'bracket' => _BracketPanel(eventId: event.id),
                'standings' => _StandingsPanel(eventId: event.id),
                'scorers' => const _ScorersPanel(),
                'ratings' => RatingsPanel(event: event),
                _ => const _ChatPanel(),
              },
            ],
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            decoration: const BoxDecoration(
              color: T.elev1,
              border: Border(top: BorderSide(color: T.line, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    variant: BtnVariant.ghost,
                    size: BtnSize.lg,
                    full: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.tv, size: 16, color: T.ink),
                        SizedBox(width: 6),
                        Text('观看直播',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: T.ink)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  // TODO: teams registration — Session D
                  child: PrimaryButton(
                    label: '报名参赛',
                    variant: BtnVariant.primary,
                    size: BtnSize.lg,
                    full: true,
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

class _Header extends StatelessWidget {
  final Event event;
  final VoidCallback onBack;
  const _Header({required this.event, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final hue =
        (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    final (dotColor, pillColor, pillText) = switch (event.status) {
      EventStatus.ongoing => (T.live, T.live, '正在进行'),
      EventStatus.registering => (T.warn, T.warn, '报名中'),
      EventStatus.done => (T.inkDim, T.inkSub, '已结束'),
    };
    return Stack(
      children: [
        PhotoHalftone(
          label: '${event.name} · 主视觉',
          height: 180,
          hue: hue,
        ),
        Positioned(
          top: 12, left: 12,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x80000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: T.ink),
            ),
          ),
        ),
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
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
                      width: 8, height: 8,
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
                Text(event.name,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: T.ink,
                        letterSpacing: -0.4)),
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
      data: (list) =>
          '${list.where((m) => m.done).length}/${list.length}',
      orElse: () => '-',
    );
    final prizeStr = prizeCents != null
        ? '${(prizeCents! / 1000000).toStringAsFixed(1)}万'
        : '-';
    final items = [
      ('队伍', teamsMax?.toString() ?? '-'),
      ('场次', matchesStr),
      ('奖金', prizeStr),
      ('观众', '3.2K'),  // TODO: needs viewing telemetry
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.line, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: i == 0 ? null : const EdgeInsets.only(left: 10),
                decoration: i == 0
                    ? null
                    : const BoxDecoration(
                        border: Border(
                            left: BorderSide(color: T.line, width: 1))),
                child: Column(
                  crossAxisAlignment: i == 0
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Label(items[i].$1),
                    const SizedBox(height: 3),
                    N(items[i].$2,
                        size: 16, weight: FontWeight.w700, color: T.ink),
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

  const _Tabs({required this.current, required this.tabs, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.line, width: 1)),
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
                        fontWeight:
                            current == t.$1 ? FontWeight.w700 : FontWeight.w500,
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
          child: Text('加载失败: $error',
              style: const TextStyle(fontSize: 12, color: T.inkSub)),
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
          const Label('规则'),
          const SizedBox(height: 10),
          for (final r in const [
            '11人制 · 标准场地',
            '2 × 45min + 半场休息',
            '5人换人名额，换下可回',
            '红黄牌累积停赛',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 4,
                    decoration: const BoxDecoration(
                        color: T.live, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(r, style: const TextStyle(fontSize: 13, color: T.inkSub)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Label('组织方'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: T.elev2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Row(
              children: [
                Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: T.elev3,
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.city ?? '—',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: T.ink)),
                    Label('赛事组织方'),
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
    return ref.watch(eventMatchesProvider(eventId)).when(
          data: (matches) => _BracketLayout(matches: matches),
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e),
        );
  }
}

class _BracketLayout extends StatelessWidget {
  final List<Match> matches;
  const _BracketLayout({required this.matches});

  @override
  Widget build(BuildContext context) {
    final qf = matches.where((m) => m.round == 'qf').toList();
    final sf = matches.where((m) => m.round == 'sf').toList();
    final finals = matches.where((m) => m.round == 'final').toList();
    final finalMatch = finals.isNotEmpty ? finals.first : null;

    if (qf.isEmpty && sf.isEmpty && finalMatch == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Label('暂无赛程，等待组委会发布')),
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
                    const Label('1/4 决赛'),
                    const SizedBox(height: 10),
                    if (qf.isEmpty)
                      const _EmptyCell(text: 'TBD')
                    else
                      for (final m in qf) _MatchCard(m: m),
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
                      const Label('半决赛'),
                      const SizedBox(height: 36),
                      if (sf.isEmpty)
                        const _EmptyCell(text: 'TBD')
                      else ...[
                        _MatchCard(m: sf[0]),
                        if (sf.length > 1) ...[
                          const SizedBox(height: 60),
                          _MatchCard(m: sf[1]),
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
                      const Label('决赛'),
                      const SizedBox(height: 10),
                      if (finalMatch == null)
                        const _EmptyCell(text: 'TBD')
                      else
                        _MatchCard(m: finalMatch),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: T.liveDim,
                          border: Border.all(color: T.live),
                          borderRadius: BorderRadius.circular(T.r2),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.emoji_events, size: 18, color: T.live),
                            SizedBox(height: 4),
                            Text('冠军',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: T.live)),
                          ],
                        ),
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
          color: T.elev2,
          border: Border.all(color: T.line, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: Text(text,
            style: const TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 11,
                color: T.inkDim)),
      );
}

class _MatchCard extends StatelessWidget {
  final Match m;
  const _MatchCard({required this.m});

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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: T.elev2,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _teamLine(m.teamALabel ?? 'TBD', sa, won: aWins),
          const SizedBox(height: 4),
          _teamLine(m.teamBLabel ?? 'TBD', sb, won: bWins),
          if (m.pkScore != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('PK ${m.pkScore}',
                      style: const TextStyle(
                          fontFamily: T.fontMono,
                          fontFamilyFallback: T.monoFallbacks,
                          fontSize: 9,
                          color: T.warn)),
                ],
              ),
            ),
          if (timeStr != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(timeStr,
                  style: const TextStyle(
                      fontFamily: T.fontMono,
                      fontFamilyFallback: T.monoFallbacks,
                      fontSize: 10,
                      color: T.inkDim)),
            ),
        ],
      ),
    );
  }

  Widget _teamLine(String name, int? score, {required bool won}) {
    final nameColor = m.done ? (won ? T.ink : T.inkSub) : T.inkSub;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: nameColor,
                  fontWeight: won ? FontWeight.w700 : FontWeight.w400)),
        ),
        if (m.done && score != null)
          N('$score',
              size: 13,
              weight: FontWeight.w700,
              color: won ? T.live : T.inkSub)
        else
          const Text('-',
              style: TextStyle(color: T.inkDim, fontSize: 11)),
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
  StandingRow bump(String k) =>
      agg.putIfAbsent(k, () => StandingRow(team: k));
  for (final m in matches) {
    if (!m.done || m.scoreA == null || m.scoreB == null) continue;
    final a = bump(m.teamALabel ?? 'TBD');
    final b = bump(m.teamBLabel ?? 'TBD');
    a.gf += m.scoreA!;
    a.ga += m.scoreB!;
    b.gf += m.scoreB!;
    b.ga += m.scoreA!;
    if (m.scoreA! > m.scoreB!) {
      a.w++; b.l++; a.pts += 3;
    } else if (m.scoreA! < m.scoreB!) {
      b.w++; a.l++; b.pts += 3;
    } else {
      a.d++; b.d++;
      a.pts++; b.pts++;
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
    return ref.watch(eventMatchesProvider(eventId)).when(
          data: (matches) {
            final rows = computeStandings(matches);
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Label('暂无比赛结果')),
              );
            }
            return _StandingsTable(rows: rows);
          },
          loading: () => const _PanelLoading(),
          error: (e, _) => _PanelError(e),
        );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<StandingRow> rows;
  const _StandingsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 24, child: Label('#')),
                SizedBox(width: 10),
                Expanded(child: Label('队伍')),
                SizedBox(width: 32, child: Center(child: Label('胜'))),
                SizedBox(width: 32, child: Center(child: Label('平'))),
                SizedBox(width: 32, child: Center(child: Label('负'))),
                SizedBox(
                    width: 40,
                    child: Align(
                        alignment: Alignment.centerRight, child: Label('积分'))),
              ],
            ),
          ),
          for (final s in rows)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: s.rank <= 2 ? const Color(0x0800FF85) : null,
                border: const Border(
                    top: BorderSide(color: T.line, width: 1)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: N('${s.rank}',
                        size: 13,
                        weight: FontWeight.w600,
                        color: s.rank <= 2 ? T.live : T.inkSub),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: HSLColor.fromAHSL(
                                    1, (s.rank * 50).toDouble() % 360,
                                    0.35, 0.3)
                                .toColor(),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s.team,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: T.ink,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                      width: 32,
                      child:
                          Center(child: N('${s.w}', size: 12, color: T.inkSub))),
                  SizedBox(
                      width: 32,
                      child:
                          Center(child: N('${s.d}', size: 12, color: T.inkSub))),
                  SizedBox(
                      width: 32,
                      child:
                          Center(child: N('${s.l}', size: 12, color: T.inkSub))),
                  SizedBox(
                      width: 40,
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: N('${s.pts}',
                              size: 14, weight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scorers — mock (需要 goals 表，Session D 再接)
// ─────────────────────────────────────────────────────────────
class _ScorersPanel extends ConsumerWidget {
  const _ScorersPanel();
  static const _medal = [Color(0xFFFFD700), Color(0xFFC0C0C0), Color(0xFFCD7F32)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: 需要 goals 表；见 IMPLEMENTATION_PLAN.md
    final rows = ref.watch(scorersProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: T.elev2,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: i < 3
                          ? Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _medal[i],
                                shape: BoxShape.circle,
                              ),
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      fontFamily: T.fontMono,
                                      fontFamilyFallback: T.monoFallbacks,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: Colors.black)),
                            )
                          : N('${rows[i].rank}',
                              size: 14, weight: FontWeight.w600, color: T.inkSub),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Avatar(rows[i].name, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: T.ink)),
                        Label('${rows[i].team} · ${rows[i].matches} 场'),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      N('${rows[i].goals}',
                          size: 22, weight: FontWeight.w700, color: T.live),
                      const Label('进球'),
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
// Chat — static (Session D 再接 realtime 弹幕)
// ─────────────────────────────────────────────────────────────
class _ChatPanel extends StatelessWidget {
  const _ChatPanel();
  // TODO: Session D — realtime event chat schema
  static const _msgs = [
    ('Kevin', '狼队今天状态拉满', '20:14'),
    ('阿泽', '开场那个长传太骚了', '20:15'),
    ('林帅', 'FC 黑马今天门将是板凳 怎么回事', '20:16'),
    ('江北', '老王要进球王了', '20:17'),
    ('路人甲', '现场来了几百号人挺热闹', '20:18'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      color: T.elev1,
      constraints: const BoxConstraints(minHeight: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in _msgs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Avatar(m.$1, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(m.$1,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: T.inkSub,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 6),
                            Label(m.$3),
                          ],
                        ),
                        Text(m.$2,
                            style: const TextStyle(
                                fontSize: 13, color: T.ink, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: T.elev2,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text('发条弹幕…',
                      style: TextStyle(fontSize: 13, color: T.inkDim)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: T.live,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, size: 14, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

class _RatingsPanelState extends ConsumerState<RatingsPanel> {
  PlayerRatingRow? _selected;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventPlayerRatingsProvider(widget.event.id));
    if (_selected != null) {
      return _PlayerRatingDetail(
        player: _selected!,
        event: widget.event,
        onBack: () => setState(() => _selected = null),
      );
    }
    return async.when(
      data: (rows) => _buildList(rows),
      loading: () => const _PanelLoading(),
      error: (e, _) => _PanelError(e),
    );
  }

  Widget _buildList(List<PlayerRatingRow> rows) {
    final totalVotes = rows.fold<int>(0, (s, r) => s + r.votes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('本赛事评分榜'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSLColor.fromAHSL(1, 150, 0.25, 0.18).toColor(),
                      HSLColor.fromAHSL(1, 150, 0.10, 0.12).toColor(),
                    ],
                  ),
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.event.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: T.ink)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Label('${rows.length} 位球员被评分'),
                        const Spacer(),
                        Label('${_fmt(totalVotes)} 人次'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Label('还没有评分 · 去评赛后场次')),
          )
        else
          for (int i = 0; i < rows.length; i++)
            GestureDetector(
              onTap: () => setState(() => _selected = rows[i]),
              child: _PlayerRow(p: rows[i], rank: i + 1),
            ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Label('· 点击球员查看评分详情 ·')),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerRatingRow p;
  final int rank;
  const _PlayerRow({required this.p, required this.rank});

  @override
  Widget build(BuildContext context) {
    final you = p.rateeId == currentUserId;
    final scoreColor =
        p.avgScore >= 8 ? T.live : (p.avgScore >= 6 ? T.ink : T.danger);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.elev2,
        border: Border.all(color: rank == 1 ? T.live : T.line),
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
                  : (rank <= 3 ? T.elev3 : Colors.transparent),
              border: rank == 1 ? null : Border.all(color: T.line),
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
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 14,
                            color: T.ink,
                            fontWeight: FontWeight.w600)),
                    if (you) _tinyBadge('你', T.liveDim, T.live),
                  ],
                ),
                const SizedBox(height: 3),
                Label([
                  if (p.position != null) p.position!,
                  '${p.votes}人评',
                ].join(' · ')),
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
                N(p.avgScore.toStringAsFixed(1),
                    size: 22, weight: FontWeight.w800, color: scoreColor),
                const SizedBox(height: 2),
                const Label('均分'),
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
    final scoreColor =
        p.avgScore >= 8 ? T.live : (p.avgScore >= 6 ? T.ink : T.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 18, color: T.ink),
              ),
              const SizedBox(width: 8),
              const Label('球员评分详情'),
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
            border: Border.all(color: T.line),
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
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: T.ink)),
                        if (you) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: T.liveDim,
                              border: Border.all(
                                  color: const Color(0x6600FF85)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text('你',
                                style: TextStyle(
                                    fontFamily: T.fontMono,
                                    fontFamilyFallback: T.monoFallbacks,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: T.live)),
                          ),
                        ],
                      ],
                    ),
                    Label([
                      if (p.position != null) p.position!,
                      event.name,
                    ].join(' · ')),
                    const SizedBox(height: 8),
                    Label('${p.votes} 人参与评分'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  N(p.avgScore.toStringAsFixed(2),
                      size: 42, weight: FontWeight.w800, color: scoreColor),
                  const SizedBox(height: 4),
                  const Label('均分'),
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
              const Label('评分分布 · 样例'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: T.elev2,
                  border: Border.all(color: T.line),
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
                                    horizontal: 1.5),
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
                                      borderRadius:
                                          const BorderRadius.only(
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
                              child: Text('$i',
                                  style: const TextStyle(
                                      fontFamily: T.fontMono,
                                      fontFamilyFallback: T.monoFallbacks,
                                      fontSize: 9,
                                      color: T.inkDim)),
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
                children: const [
                  Label('热门评论 · 样例'),
                  Spacer(),
                  Label('按热度排序'),
                ],
              ),
              const SizedBox(height: 10),
              for (final c in comments)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: T.elev2,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(T.r2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(c.user, size: 22),
                          const SizedBox(width: 8),
                          Text(c.user,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: T.inkSub,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.score >= 8
                                  ? T.liveDim
                                  : c.score >= 6 ? T.elev3 : const Color(0x24FF3B6B),
                              border: Border.all(
                                color: c.score >= 8
                                    ? T.live.withValues(alpha: 0.3)
                                    : c.score >= 6
                                        ? T.line
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
                                    : c.score >= 6 ? T.ink : T.danger,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Label(c.time),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(c.text,
                          style: const TextStyle(
                              fontSize: 13, color: T.ink, height: 1.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.favorite_border,
                              size: 12, color: T.inkSub),
                          const SizedBox(width: 4),
                          N('${c.likes}', size: 11, color: T.inkSub),
                          const SizedBox(width: 14),
                          const Icon(Icons.chat_bubble_outline,
                              size: 12, color: T.inkSub),
                          const SizedBox(width: 4),
                          const Text('回复',
                              style:
                                  TextStyle(fontSize: 11, color: T.inkSub)),
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
