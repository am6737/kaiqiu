// match_detail_screen.dart — 单场比赛详情（Tab 结构）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../repositories/goals_repository.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../utils/toast.dart';
import '../../models/rating.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class MatchDetailScreen extends ConsumerWidget {
  final String eventId;
  final String matchId;
  const MatchDetailScreen({
    super.key,
    required this.eventId,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final matchesAsync = ref.watch(eventMatchesProvider(eventId));

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: matchesAsync.when(
        loading: () => const _Loading(),
        error: (e, _) => _Error(error: e),
        data: (matches) {
          final match = _firstWhereOrNull(matches, (m) => m.id == matchId);
          if (match == null) {
            return Center(
              child: Text(
                l.match_not_found,
                style: TextStyle(color: context.tokens.inkSub, fontSize: 13),
              ),
            );
          }
          return _MatchDetailBody(match: match, eventId: eventId);
        },
      ),
    );
  }
}

E? _firstWhereOrNull<E>(Iterable<E> xs, bool Function(E) test) {
  for (final x in xs) {
    if (test(x)) return x;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// Body with Tabs
// ─────────────────────────────────────────────────────────────
class _MatchDetailBody extends ConsumerStatefulWidget {
  final Match match;
  final String eventId;
  const _MatchDetailBody({required this.match, required this.eventId});

  @override
  ConsumerState<_MatchDetailBody> createState() => _MatchDetailBodyState();
}

class _MatchDetailBodyState extends ConsumerState<_MatchDetailBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabC;

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Column(
      children: [
        _ScoreHero(match: widget.match, status: widget.match.status),
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: t.elev1,
            border: Border(bottom: BorderSide(color: t.line, width: 1)),
          ),
          child: TabBar(
            controller: _tabC,
            labelColor: t.accent,
            unselectedLabelColor: t.inkDim,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            indicatorColor: t.accent,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            dividerHeight: 0,
            tabs: [
              Tab(text: l.match_tab_overview),
              Tab(text: l.match_tab_stats),
              Tab(text: l.match_tab_ratings),
              Tab(text: l.match_tab_discussion),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabC,
            children: [
              _OverviewTab(
                match: widget.match,
                eventId: widget.eventId,
              ),
              _StatsTab(
                match: widget.match,
                eventId: widget.eventId,
              ),
              _RatingsTab(
                match: widget.match,
                eventId: widget.eventId,
              ),
              _DiscussionTab(
                match: widget.match,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Score Hero — dark themed scoreboard header
// ─────────────────────────────────────────────────────────────
class _ScoreHero extends StatelessWidget {
  final Match match;
  final MatchStatus status;
  const _ScoreHero({required this.match, required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final sa = match.scoreA;
    final sb = match.scoreB;
    final done = match.done;
    final aWins = done && sa != null && sb != null && sa > sb;
    final bWins = done && sa != null && sb != null && sb > sa;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xCCFFFFFF)),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _roundLabel(l, match.round),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: Color(0x80FFFFFF),
                        ),
                      ),
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _TeamColumn(
                      name: match.teamALabel ?? 'TBD',
                      won: aWins,
                      done: done,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        if (done && sa != null && sb != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$sa',
                                style: TextStyle(
                                  fontFamily: t.fontMono,
                                  fontFamilyFallback: t.monoFallbacks,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: aWins ? t.accent : const Color(0xFFFFFFFF),
                                  height: 1.0,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  ':',
                                  style: TextStyle(
                                    fontFamily: t.fontMono,
                                    fontFamilyFallback: t.monoFallbacks,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w300,
                                    color: const Color(0x66FFFFFF),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              Text(
                                '$sb',
                                style: TextStyle(
                                  fontFamily: t.fontMono,
                                  fontFamilyFallback: t.monoFallbacks,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: bWins ? t.accent : const Color(0xFFFFFFFF),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'VS',
                            style: TextStyle(
                              fontFamily: t.fontMono,
                              fontFamilyFallback: t.monoFallbacks,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0x4DFFFFFF),
                              height: 1.0,
                            ),
                          ),
                        if (match.pkScore != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: t.warn.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.warn.withValues(alpha: 0.3), width: 0.5),
                            ),
                            child: Text(
                              'PK ${match.pkScore}',
                              style: TextStyle(
                                fontFamily: t.fontMono,
                                fontFamilyFallback: t.monoFallbacks,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: t.warn,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: _TeamColumn(
                      name: match.teamBLabel ?? 'TBD',
                      won: bWins,
                      done: done,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (match.playedAt != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 13, color: Color(0x80FFFFFF)),
                    const SizedBox(width: 5),
                    Text(
                      _formatDatetime(context, match.playedAt!),
                      style: TextStyle(
                        fontFamily: t.fontMono,
                        fontFamilyFallback: t.monoFallbacks,
                        fontSize: 11,
                        color: const Color(0x99FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String name;
  final bool won;
  final bool done;
  final bool alignEnd;
  const _TeamColumn({
    required this.name,
    required this.won,
    required this.done,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final initial = name.isNotEmpty ? name.characters.first : '?';
    final dimmed = done && !won;

    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: won ? t.accent.withValues(alpha: 0.15) : const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: won ? t.accent.withValues(alpha: 0.3) : const Color(0x14FFFFFF),
              width: 1,
            ),
          ),
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: won ? t.accent : (dimmed ? const Color(0x66FFFFFF) : const Color(0xCCFFFFFF)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: won ? FontWeight.w700 : FontWeight.w500,
            color: dimmed ? const Color(0x66FFFFFF) : const Color(0xE6FFFFFF),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MatchStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final (bg, fg, text) = switch (status) {
      MatchStatus.upcoming => (const Color(0x29FFFFFF), const Color(0x99FFFFFF), l.match_status_upcoming),
      MatchStatus.live => (t.accent.withValues(alpha: 0.2), t.accent, l.match_status_live),
      MatchStatus.finished => (const Color(0x1AFFFFFF), const Color(0x66FFFFFF), l.match_status_done),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: status == MatchStatus.live
            ? Border.all(color: t.accent.withValues(alpha: 0.4), width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == MatchStatus.live) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TAB 1: Overview — Goals + CTA
// ═════════════════════════════════════════════════════════════
class _OverviewTab extends ConsumerWidget {
  final Match match;
  final String eventId;
  const _OverviewTab({required this.match, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(matchGoalsProvider(match.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (match.status == MatchStatus.finished)
            goalsAsync.when(
              loading: () => const _GoalsLoading(),
              error: (e, _) => _GoalsError(error: e),
              data: (goals) => _GoalsTimeline(goals: goals),
            ),
          const SizedBox(height: 24),
          _BottomCtaArea(match: match, status: match.status, eventId: eventId),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Goals Timeline
// ─────────────────────────────────────────────────────────────
class _GoalsTimeline extends StatelessWidget {
  final List<GoalEvent> goals;
  const _GoalsTimeline({required this.goals});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_soccer, size: 16, color: t.accent),
              const SizedBox(width: 8),
              Text(
                l.match_goals_section,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
              ),
              if (goals.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${goals.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.accent),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (goals.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.elev2,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(t.r2),
              ),
              child: Column(
                children: [
                  Icon(Icons.sports_soccer, size: 28, color: t.inkMute),
                  const SizedBox(height: 8),
                  Text(l.match_goals_empty, style: TextStyle(color: t.inkDim, fontSize: 12)),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: t.elev1,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(t.r2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < goals.length; i++) ...[
                    if (i > 0) Divider(height: 1, thickness: 1, color: t.line),
                    _GoalRow(goal: goals[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalEvent goal;
  const _GoalRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.accentSubtle,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              goal.minute != null ? "${goal.minute}'" : '-',
              style: TextStyle(
                fontFamily: t.fontMono,
                fontFamilyFallback: t.monoFallbacks,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.sports_soccer, size: 16, color: t.inkDim),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.scorerName ?? '—',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                if (goal.assistId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.match_assist_by(goal.assistId!),
                    style: TextStyle(fontSize: 11, color: t.inkDim),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (goal.isPenalty) _GoalTag(text: l.match_penalty, color: t.accent),
          if (goal.isOwnGoal) ...[
            if (goal.isPenalty) const SizedBox(width: 6),
            _GoalTag(text: l.match_own_goal, color: t.warn),
          ],
        ],
      ),
    );
  }
}

class _GoalTag extends StatelessWidget {
  final String text;
  final Color color;
  const _GoalTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TAB 2: Stats — Match statistics comparison
// ═════════════════════════════════════════════════════════════
class _StatsTab extends ConsumerWidget {
  final Match match;
  final String eventId;
  const _StatsTab({required this.match, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;

    if (match.status != MatchStatus.finished) {
      return _EmptyTab(
        icon: Icons.bar_chart_rounded,
        text: l.match_stats_no_data,
      );
    }

    final goalsAsync = ref.watch(matchGoalsProvider(match.id));

    return goalsAsync.when(
      loading: () => const _GoalsLoading(),
      error: (e, _) => _GoalsError(error: e),
      data: (goals) => _StatsContent(
        match: match,
        goals: goals,
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final Match match;
  final List<GoalEvent> goals;
  const _StatsContent({required this.match, required this.goals});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    final sa = match.scoreA ?? 0;
    final sb = match.scoreB ?? 0;
    final penA = goals.where((g) => g.isPenalty && !g.isOwnGoal).length;
    final penB = 0; // goals don't have side info, so we show total
    final ogA = goals.where((g) => g.isOwnGoal).length;
    final firstHalf = goals.where((g) => g.minute != null && g.minute! <= 45).length;
    final secondHalf = goals.where((g) => g.minute != null && g.minute! > 45).length;

    final teamA = match.teamALabel ?? 'A';
    final teamB = match.teamBLabel ?? 'B';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        children: [
          // Team header
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    teamA,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Center(
                    child: Label(l.match_tab_stats),
                  ),
                ),
                Expanded(
                  child: Text(
                    teamB,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          _StatBar(label: l.match_stats_goals, valueA: sa, valueB: sb),
          if (penA > 0 || penB > 0)
            _StatBar(label: l.match_stats_penalty_goals, valueA: penA, valueB: penB),
          if (ogA > 0)
            _StatBar(label: l.match_stats_own_goals, valueA: ogA, valueB: 0),
          if (firstHalf > 0 || secondHalf > 0) ...[
            _StatBar(label: l.match_stats_first_half, valueA: firstHalf, valueB: 0, isTotal: true),
            _StatBar(label: l.match_stats_second_half, valueA: secondHalf, valueB: 0, isTotal: true),
          ],
          const SizedBox(height: 24),
          // Goal timeline chart
          if (goals.isNotEmpty) _GoalTimelineChart(goals: goals),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final int valueA;
  final int valueB;
  final bool isTotal;
  const _StatBar({
    required this.label,
    required this.valueA,
    required this.valueB,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = valueA + valueB;
    final ratioA = total > 0 ? valueA / total : 0.5;
    final ratioB = total > 0 ? valueB / total : 0.5;
    final aLeads = valueA > valueB;
    final bLeads = valueB > valueA;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Values + label
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  isTotal ? '$total' : '$valueA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: t.fontMono,
                    fontFamilyFallback: t.monoFallbacks,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: (!isTotal && aLeads) ? t.accent : t.ink,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: t.inkSub, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  isTotal ? '' : '$valueB',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: t.fontMono,
                    fontFamilyFallback: t.monoFallbacks,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: bLeads ? t.accent : t.ink,
                  ),
                ),
              ),
            ],
          ),
          if (!isTotal) ...[
            const SizedBox(height: 6),
            // Comparison bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: t.elev2,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Flexible(
                    flex: (ratioA * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: BoxDecoration(
                        color: aLeads ? t.accent : t.inkDim.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    flex: (ratioB * 100).round().clamp(1, 99),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bLeads ? t.accent : t.inkDim.withValues(alpha: 0.4),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalTimelineChart extends StatelessWidget {
  final List<GoalEvent> goals;
  const _GoalTimelineChart({required this.goals});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final periods = ['0-15', '16-30', '31-45', '46-60', '61-75', '76-90'];
    final counts = List.filled(6, 0);
    for (final g in goals) {
      if (g.minute == null) continue;
      final m = g.minute!;
      final idx = ((m - 1) / 15).floor().clamp(0, 5);
      counts[idx]++;
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline, size: 16, color: t.accent),
            const SizedBox(width: 8),
            Text(
              '${l.match_stats_goals} · Timeline',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.elev2,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(t.r2),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < 6; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (counts[i] > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '${counts[i]}',
                                    style: TextStyle(
                                      fontFamily: t.fontMono,
                                      fontFamilyFallback: t.monoFallbacks,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: t.accent,
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: counts[i] / maxCount,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: counts[i] > 0 ? t.accent.withValues(alpha: 0.7) : t.line,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 6; i++)
                    Expanded(
                      child: Center(
                        child: Text(
                          periods[i],
                          style: TextStyle(
                            fontFamily: t.fontMono,
                            fontFamilyFallback: t.monoFallbacks,
                            fontSize: 9,
                            color: t.inkDim,
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
    );
  }
}

// ═════════════════════════════════════════════════════════════
// TAB 3: Ratings — player cards with avatar, stats, stars
// ═════════════════════════════════════════════════════════════
final _playerRatingsForMatchProvider =
    FutureProvider.family.autoDispose<List<Rating>, ({String matchId, String rateeId})>(
  (ref, args) => ref.read(ratingsRepoProvider).forPlayerInMatch(
    matchId: args.matchId,
    rateeId: args.rateeId,
  ),
);

class _RatingsTab extends ConsumerStatefulWidget {
  final Match match;
  final String eventId;
  const _RatingsTab({required this.match, required this.eventId});

  @override
  ConsumerState<_RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends ConsumerState<_RatingsTab> {
  PlayerRatingRow? _selectedPlayer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    if (widget.match.status != MatchStatus.finished) {
      return _EmptyTab(
        icon: Icons.star_outline_rounded,
        text: l.match_stats_no_data,
      );
    }

    if (_selectedPlayer != null) {
      return _PlayerDetail(
        player: _selectedPlayer!,
        match: widget.match,
        onBack: () => setState(() => _selectedPlayer = null),
      );
    }

    final async = ref.watch(matchPlayerRatingsProvider(widget.match));

    return async.when(
      loading: () => const _GoalsLoading(),
      error: (e, _) => _GoalsError(error: e),
      data: (rows) {
        final visible = rows.where((r) => r.name != '—').toList();

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Label(l.event_rating_empty_go_rate)),
                    )
                  else
                    for (int i = 0; i < visible.length; i++)
                      _PlayerCard(
                        p: visible[i],
                        rank: i + 1,
                        onTap: () => setState(() => _selectedPlayer = visible[i]),
                      ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: t.bg,
                  border: Border(top: BorderSide(color: t.line, width: 1)),
                ),
                child: PrimaryButton(
                  label: l.match_ratings_go_rate,
                  full: true,
                  size: BtnSize.lg,
                  onPressed: () => context.push('/rate/${widget.match.id}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Player card with large avatar ──────────────────────────
class _PlayerCard extends ConsumerWidget {
  final PlayerRatingRow p;
  final int rank;
  final VoidCallback onTap;
  const _PlayerCard({required this.p, required this.rank, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final profile = ref.watch(profileByIdProvider(p.rateeId)).valueOrNull;
    final avatarUrl = profile?.avatarUrl;
    final rated = p.votes > 0;
    final scoreColor = p.avgScore >= 8
        ? t.accent
        : (p.avgScore >= 6 ? t.ink : t.danger);
    final stars = p.avgScore / 2.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: rated && rank == 1 ? t.accent : t.line),
          borderRadius: BorderRadius.circular(t.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LargeAvatar(url: avatarUrl, name: p.name, rank: rated ? rank : 0),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: rated ? t.ink : t.inkSub,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rated && rank == 1) ...[
                            const SizedBox(width: 8),
                            _Badge(text: l.event_rating_mvp, color: t.accent, bg: t.accentSubtle),
                          ],
                          if (p.rateeId == currentUserId) ...[
                            const SizedBox(width: 6),
                            _Badge(text: l.rate_short_you, color: t.accent, bg: t.accentSubtle),
                          ],
                        ],
                      ),
                      if (p.position != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          p.position!,
                          style: TextStyle(fontSize: 12, color: t.inkSub),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (p.goals > 0)
                            _StatPill(
                              icon: Icons.sports_soccer,
                              value: '${p.goals}',
                              label: l.match_rating_goals_short,
                              color: t.accent,
                            ),
                          if (p.goals > 0 && p.assists > 0) const SizedBox(width: 8),
                          if (p.assists > 0)
                            _StatPill(
                              icon: Icons.handshake_outlined,
                              value: '${p.assists}',
                              label: l.match_rating_assists_short,
                              color: t.warn,
                            ),
                          if (p.topHighlight != null && p.topHighlight!.isNotEmpty) ...[
                            if (p.goals > 0 || p.assists > 0) const SizedBox(width: 8),
                            _Badge(
                              text: p.topHighlight!,
                              color: const Color(0xFFFF6D3B),
                              bg: const Color(0x22FF6D3B),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (rated)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      N(
                        p.avgScore.toStringAsFixed(1),
                        size: 28,
                        weight: FontWeight.w800,
                        color: scoreColor,
                      ),
                      const SizedBox(height: 2),
                      _StarRow(stars: stars, size: 12),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.elev3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.match_rating_not_rated,
                      style: TextStyle(fontSize: 11, color: t.inkDim, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            if (p.topComment != null && p.topComment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: t.elev3,
                  borderRadius: BorderRadius.circular(t.r2),
                  border: Border.all(color: t.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.format_quote, size: 14, color: t.inkDim),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.topComment!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: t.inkSub, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 14, color: t.inkDim),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Label(l.match_rating_n_voted(p.votes)),
                  const Spacer(),
                  Text(
                    l.event_rating_player_detail,
                    style: TextStyle(fontSize: 11, color: t.accent, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 10, color: t.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final int rank;
  const _LargeAvatar({required this.url, required this.name, required this.rank});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(
              1,
              (name.codeUnitAt(0) * 37) % 360.0,
              0.3,
              Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.85,
            ).toColor(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rank == 1 ? t.accent : t.line,
              width: rank == 1 ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null && url!.isNotEmpty
              ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback(t))
              : _fallback(t),
        ),
        if (rank <= 3)
          Positioned(
            top: -6,
            left: -6,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1
                    ? t.accent
                    : rank == 2
                        ? const Color(0xFFC0C0C0)
                        : const Color(0xFFCD7F32),
                shape: BoxShape.circle,
                border: Border.all(color: t.elev2, width: 2),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallback(AppTokens t) => Center(
    child: Text(
      name.isNotEmpty ? name.characters.first : '?',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: t.inkSub),
    ),
  );
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: t.fontMono,
              fontFamilyFallback: t.monoFallbacks,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const _Badge({required this.text, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: t.fontMono,
          fontFamilyFallback: t.monoFallbacks,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double stars;
  final double size;
  const _StarRow({required this.stars, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = (stars - i).clamp(0.0, 1.0);
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 1 : 0),
          child: Icon(
            fill >= 0.75
                ? Icons.star_rounded
                : fill >= 0.25
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: fill > 0 ? const Color(0xFFFFB800) : t.inkMute,
          ),
        );
      }),
    );
  }
}

// ─── Player detail: score distribution + reviews ────────────
class _PlayerDetail extends ConsumerWidget {
  final PlayerRatingRow player;
  final Match match;
  final VoidCallback onBack;
  const _PlayerDetail({required this.player, required this.match, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = context.tokens;
    final profile = ref.watch(profileByIdProvider(player.rateeId)).valueOrNull;
    final avatarUrl = profile?.avatarUrl;
    final rated = player.votes > 0;
    final scoreColor = player.avgScore >= 8
        ? t.accent
        : (player.avgScore >= 6 ? t.ink : t.danger);
    final stars = player.avgScore / 2.0;

    final ratingsAsync = ref.watch(
      _playerRatingsForMatchProvider((matchId: match.id, rateeId: player.rateeId)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
                  onPressed: onBack,
                ),
                Text(
                  l.event_rating_player_detail,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(t.r3),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _LargeAvatar(url: avatarUrl, name: player.name, rank: 0),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (player.position != null) player.position!,
                              if (player.goals > 0) '${player.goals} ${l.match_rating_goals_short}',
                              if (player.assists > 0) '${player.assists} ${l.match_rating_assists_short}',
                            ].join(' · '),
                            style: TextStyle(fontSize: 12, color: t.inkSub),
                          ),
                        ],
                      ),
                    ),
                    if (rated)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          N(
                            player.avgScore.toStringAsFixed(1),
                            size: 40,
                            weight: FontWeight.w800,
                            color: scoreColor,
                          ),
                          const SizedBox(height: 4),
                          _StarRow(stars: stars, size: 14),
                          const SizedBox(height: 4),
                          Label(l.match_rating_n_voted(player.votes)),
                        ],
                      )
                    else
                      Text(
                        l.match_rating_not_rated,
                        style: TextStyle(fontSize: 13, color: t.inkDim, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Score distribution
          ratingsAsync.when(
            loading: () => const _GoalsLoading(),
            error: (e, _) => _GoalsError(error: e),
            data: (ratings) => _PlayerScoreDist(ratings: ratings),
          ),

          // Reviews list
          ratingsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (ratings) => _ReviewsList(ratings: ratings),
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreDist extends StatelessWidget {
  final List<Rating> ratings;
  const _PlayerScoreDist({required this.ratings});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    // Build 5-star distribution (10-scale → 5-star: score/2 rounded)
    final dist = List<int>.filled(6, 0); // index 0=unused, 1-5 stars
    for (final r in ratings) {
      final starBucket = (r.score / 2.0).round().clamp(1, 5);
      dist[starBucket]++;
    }
    final maxCount = dist.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: t.accent),
              const SizedBox(width: 8),
              Text(
                l.match_rating_score_dist,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.elev2,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(t.r2),
            ),
            child: Column(
              children: [
                for (int star = 5; star >= 1; star--)
                  Padding(
                    padding: EdgeInsets.only(bottom: star > 1 ? 8 : 0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '$star',
                            style: TextStyle(
                              fontFamily: t.fontMono,
                              fontFamilyFallback: t.monoFallbacks,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: t.inkSub,
                            ),
                          ),
                        ),
                        Icon(Icons.star_rounded, size: 14, color: const Color(0xFFFFB800)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: t.elev3,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: maxCount > 0 ? dist[star] / maxCount : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: star >= 4
                                      ? t.accent
                                      : star == 3
                                          ? t.warn
                                          : t.danger,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${dist[star]}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: t.fontMono,
                              fontFamilyFallback: t.monoFallbacks,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.inkDim,
                            ),
                          ),
                        ),
                      ],
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

class _ReviewsList extends StatelessWidget {
  final List<Rating> ratings;
  const _ReviewsList({required this.ratings});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: t.accent),
              const SizedBox(width: 8),
              Text(
                l.match_rating_all_reviews,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: t.accentSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${ratings.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ratings.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.elev2,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(t.r2),
              ),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 28, color: t.inkMute),
                  const SizedBox(height: 8),
                  Text(l.match_rating_no_reviews, style: TextStyle(color: t.inkDim, fontSize: 12)),
                ],
              ),
            )
          else
            for (final r in ratings)
              _ReviewCard(rating: r),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final Rating rating;
  const _ReviewCard({required this.rating});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final profile = ref.watch(profileByIdProvider(rating.raterId)).valueOrNull;
    final raterName = profile?.name ?? '匿名';
    final stars = rating.score / 2.0;
    final scoreColor = rating.score >= 8
        ? t.accent
        : (rating.score >= 6 ? t.ink : t.danger);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elev2,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rater info + score
          Row(
            children: [
              Avatar(raterName, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raterName,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.ink),
                    ),
                    const SizedBox(height: 2),
                    _StarRow(stars: stars, size: 11),
                  ],
                ),
              ),
              N(
                rating.score.toStringAsFixed(1),
                size: 18,
                weight: FontWeight.w800,
                color: scoreColor,
              ),
            ],
          ),
          // Comment text
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comment!,
              style: TextStyle(fontSize: 13, color: t.ink, height: 1.5),
            ),
          ],
          // Time
          const SizedBox(height: 6),
          Text(
            _relativeTime(rating.createdAt),
            style: TextStyle(fontSize: 10, color: t.inkDim),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${dt.month}-${dt.day}';
}

// ═════════════════════════════════════════════════════════════
// TAB 4: Discussion — placeholder for match chat
// ═════════════════════════════════════════════════════════════
class _DiscussionTab extends StatelessWidget {
  final Match match;
  const _DiscussionTab({required this.match});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _EmptyTab(
      icon: Icons.forum_outlined,
      text: l.match_discussion_not_open,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom CTA: rate (if done) / remind toggle (if upcoming)
// ─────────────────────────────────────────────────────────────
class _BottomCtaArea extends ConsumerStatefulWidget {
  final Match match;
  final MatchStatus status;
  final String eventId;
  const _BottomCtaArea({
    required this.match,
    required this.status,
    required this.eventId,
  });

  @override
  ConsumerState<_BottomCtaArea> createState() => _BottomCtaAreaState();
}

class _BottomCtaAreaState extends ConsumerState<_BottomCtaArea> {
  bool _starting = false;

  Future<void> _startMatch() async {
    setState(() => _starting = true);
    try {
      await ref.read(eventsRepoProvider).startMatch(widget.match.id);
      if (!mounted) return;
      context.push('/event/${widget.eventId}/match/${widget.match.id}/live');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _toggleReminder() async {
    final repo = ref.read(remindersRepoProvider);
    final matchId = widget.match.id;
    final playedAt = widget.match.playedAt;
    try {
      if (LocalStore.hasReminder(matchId)) {
        await repo.cancel(matchId);
      } else {
        final remindAt = playedAt != null
            ? playedAt.subtract(const Duration(hours: 1))
            : DateTime.now().add(const Duration(hours: 1));
        await repo.schedule(matchId: matchId, remindAt: remindAt);
      }
      if (!mounted) return;
      setState(() {});
      showToast(
        context,
        LocalStore.hasReminder(matchId)
            ? context.l10n.match_cta_reminded
            : context.l10n.match_cta_remind,
        success: LocalStore.hasReminder(matchId),
      );
    } catch (e) {
      if (!mounted) return;
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final isOrganizer = eventAsync.valueOrNull?.creatorId != null &&
        eventAsync.valueOrNull?.creatorId == supabase.auth.currentUser?.id;

    if (widget.status == MatchStatus.finished) {
      return const SizedBox.shrink();
    }

    if (widget.status == MatchStatus.upcoming) {
      if (isOrganizer) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PrimaryButton(
            label: l.live_room_start,
            full: true,
            size: BtnSize.lg,
            disabled: _starting,
            onPressed: _startMatch,
          ),
        );
      }
      final set = LocalStore.hasReminder(widget.match.id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PrimaryButton(
          label: set ? l.match_cta_reminded : l.match_cta_remind,
          full: true,
          size: BtnSize.lg,
          variant: set ? BtnVariant.secondary : BtnVariant.primary,
          onPressed: _toggleReminder,
        ),
      );
    }

    if (widget.status == MatchStatus.live) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PrimaryButton(
          label: l.live_room_join,
          full: true,
          size: BtnSize.lg,
          onPressed: () => context.push(
            '/event/${widget.eventId}/match/${widget.match.id}/live',
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────
// Shared empty tab
// ─────────────────────────────────────────────────────────────
class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyTab({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.elev2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.line),
            ),
            child: Icon(icon, size: 26, color: t.inkDim),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(fontSize: 13, color: t.inkDim),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Loading / error states
// ─────────────────────────────────────────────────────────────
class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2),
    ),
  );
}

class _Error extends StatelessWidget {
  final Object error;
  const _Error({required this.error});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        '$error',
        style: TextStyle(color: context.tokens.inkDim, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _GoalsLoading extends StatelessWidget {
  const _GoalsLoading();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(color: context.tokens.inkDim, strokeWidth: 2),
      ),
    ),
  );
}

class _GoalsError extends StatelessWidget {
  final Object error;
  const _GoalsError({required this.error});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      '$error',
      style: TextStyle(color: context.tokens.inkDim, fontSize: 11),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────
String _roundLabel(AppL10n l, String? round) => switch (round) {
  'qf' => l.event_bracket_qf,
  'sf' => l.event_bracket_sf,
  'final' => l.event_bracket_final,
  _ => l.match_detail_title,
};

String _formatDatetime(BuildContext context, DateTime at) {
  final locale = Localizations.localeOf(context).languageCode;
  final isCn = locale == 'zh';
  final dateFmt = isCn ? DateFormat('M月d日') : DateFormat('MMM d');
  final timeFmt = DateFormat('HH:mm');
  return '${dateFmt.format(at)}  ${timeFmt.format(at)}';
}
