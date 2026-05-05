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
import '../../models/comment.dart';
import '../../models/rating.dart';
import '../../widgets/avatar.dart';
import '../../widgets/interaction_btn.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/rich_input.dart';
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
// TAB 3: Ratings — compact team-grouped layout (Hupu-inspired)
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
  int _filter = 0; // 0 = all, 1 = team A, 2 = team B

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

    final async = ref.watch(matchPlayerRatingsProvider(widget.match));

    return async.when(
      loading: () => const _GoalsLoading(),
      error: (e, _) => _GoalsError(error: e),
      data: (rows) {
        final visible = rows.where((r) => r.name != '—').toList();

        final teamA = visible.where((r) => r.side == MatchSide.a).toList();
        final teamB = visible.where((r) => r.side == MatchSide.b).toList();

        String? mvpId;
        if (visible.any((r) => r.votes > 0)) {
          final rated = visible.where((r) => r.votes > 0).toList();
          rated.sort((a, b) => b.avgScore.compareTo(a.avgScore));
          mvpId = rated.first.rateeId;
        }

        final filtered = _filter == 1
            ? teamA
            : _filter == 2
                ? teamB
                : visible;

        final sorted = [...filtered]..sort((a, b) {
          if (a.votes > 0 && b.votes == 0) return -1;
          if (a.votes == 0 && b.votes > 0) return 1;
          if (a.votes > 0 && b.votes > 0) return b.avgScore.compareTo(a.avgScore);
          return 0;
        });

        final ratedInView = sorted.where((p) => p.votes > 0).toList();
        final viewAvg = ratedInView.isNotEmpty
            ? ratedInView.fold<double>(0, (s, p) => s + p.avgScore) / ratedInView.length
            : 0.0;

        final tabLabels = [
          l.event_rating_team_all,
          widget.match.teamALabel ?? 'Team A',
          widget.match.teamBLabel ?? 'Team B',
        ];

        return Column(
              children: [
                // ── Sub-tab filter row ──
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _filter = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _filter == i ? t.accent : t.elev2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _filter == i ? t.accent : t.line,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tabLabels[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _filter == i ? t.accentInk : t.inkSub,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (ratedInView.isNotEmpty) ...[
                        Text(l.event_rating_score_avg, style: TextStyle(fontSize: 11, color: t.inkDim)),
                        const SizedBox(width: 6),
                        _ScoreBadge(score: viewAvg, mini: true),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: t.line),
                // ── Player list ──
                Expanded(
                  child: sorted.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Label(l.event_rating_empty_go_rate),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: sorted.length,
                          itemBuilder: (_, i) => _PlayerRow(
                            player: sorted[i],
                            rank: sorted[i].votes > 0 ? i + 1 : 0,
                            isMvp: sorted[i].rateeId == mvpId,
                            match: widget.match,
                          ),
                        ),
                ),
              ],
            );
      },
    );
  }
}

// ─── Compact player row ─────────────────────────────────────
class _PlayerRow extends ConsumerWidget {
  final PlayerRatingRow player;
  final int rank;
  final bool isMvp;
  final Match match;
  const _PlayerRow({
    required this.player,
    required this.rank,
    required this.isMvp,
    required this.match,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    final profile = ref.watch(profileByIdProvider(player.rateeId)).valueOrNull;
    final avatarUrl = profile?.avatarUrl;
    final rated = player.votes > 0;
    final isMe = player.rateeId == currentUserId;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPlayerDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMvp ? t.accentSubtle : null,
          border: Border(bottom: BorderSide(color: t.line, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: rated && rank <= 3
                      ? _RankBadge(rank: rank)
                      : Text(
                          rated ? '$rank' : '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: t.fontMono,
                            fontFamilyFallback: t.monoFallbacks,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.inkDim,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                _CompactAvatar(url: avatarUrl, name: player.name),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isMvp ? FontWeight.w700 : FontWeight.w500,
                                color: t.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: t.accentSubtle,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                l.rate_short_you,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t.accent),
                              ),
                            ),
                          ],
                          if (isMvp) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: t.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                l.event_rating_mvp,
                                style: TextStyle(
                                  fontFamily: t.fontMono,
                                  fontFamilyFallback: t.monoFallbacks,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: t.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (player.position != null)
                            Text(player.position!, style: TextStyle(fontSize: 11, color: t.inkDim)),
                          if (player.goals > 0) ...[
                            if (player.position != null) _Dot(color: t.inkDim),
                            Icon(Icons.sports_soccer, size: 10, color: t.inkSub),
                            const SizedBox(width: 2),
                            Text('${player.goals}',
                                style: TextStyle(fontSize: 11, color: t.inkSub, fontWeight: FontWeight.w600)),
                          ],
                          if (player.assists > 0) ...[
                            _Dot(color: t.inkDim),
                            Icon(Icons.handshake_outlined, size: 10, color: t.inkSub),
                            const SizedBox(width: 2),
                            Text('${player.assists}',
                                style: TextStyle(fontSize: 11, color: t.inkSub, fontWeight: FontWeight.w600)),
                          ],
                          if (rated) ...[
                            const Spacer(),
                            Text(
                              l.match_rating_n_voted(player.votes),
                              style: TextStyle(fontSize: 10, color: t.inkDim),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                rated
                    ? _ScoreBadge(score: player.avgScore)
                    : Container(
                        width: 40,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.elev3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('-', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.inkDim)),
                      ),
              ],
            ),
            // Hot comment preview
            if (player.topComment != null && player.topComment!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 98, top: 6),
                child: Row(
                  children: [
                    Icon(Icons.format_quote_rounded, size: 12, color: t.inkMute),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        player.topComment!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: t.inkSub, fontStyle: FontStyle.italic),
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

  void _showPlayerDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PlayerDetailPage(player: player, match: match),
      ),
    );
  }
}

// ─── Score color badge ──────────────────────────────────────
class _ScoreBadge extends StatelessWidget {
  final double score;
  final bool mini;
  const _ScoreBadge({required this.score, this.mini = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, fg) = _colors(score, t);

    return Container(
      width: mini ? 34 : 40,
      height: mini ? 22 : 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(mini ? 4 : 6),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          fontFamily: t.fontMono,
          fontFamilyFallback: t.monoFallbacks,
          fontSize: mini ? 11 : 14,
          fontWeight: FontWeight.w800,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }

  static (Color, Color) _colors(double s, AppTokens t) {
    if (s >= 8.0) return (t.accent.withValues(alpha: 0.15), t.accent);
    if (s >= 6.0) return (t.warn.withValues(alpha: 0.12), t.warn);
    return (t.danger.withValues(alpha: 0.12), t.danger);
  }
}

// ─── Dot separator ──────────────────────────────────────────
class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text('·', style: TextStyle(color: color, fontSize: 11)),
  );
}

// ─── Player avatar (56px) ───────────────────────────────────
class _CompactAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _CompactAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hue = name.isNotEmpty ? (name.codeUnitAt(0) * 37) % 360.0 : 0.0;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(
          1, hue, 0.3,
          Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.85,
        ).toColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fb(t))
          : _fb(t),
    );
  }

  Widget _fb(AppTokens t) => Center(
    child: Text(
      name.isNotEmpty ? name.characters.first : '?',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: t.inkSub),
    ),
  );
}

// ─── Rank badge (gold / silver / bronze) ────────────────────
class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = rank == 1 ? t.accent : rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          fontFamily: t.fontMono,
          fontFamilyFallback: t.monoFallbacks,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: c,
        ),
      ),
    );
  }
}

// ─── Player detail full page ────────────────────────────────
class _PlayerDetailPage extends ConsumerStatefulWidget {
  final PlayerRatingRow player;
  final Match match;
  const _PlayerDetailPage({required this.player, required this.match});

  @override
  ConsumerState<_PlayerDetailPage> createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends ConsumerState<_PlayerDetailPage> {
  double _score = 7.0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _ratingOpen = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = currentUserId;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(ratingsRepoProvider).submit(
        matchId: widget.match.id,
        raterId: uid,
        rateeId: widget.player.rateeId,
        score: _score,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
      ref.invalidate(_playerRatingsForMatchProvider(
        (matchId: widget.match.id, rateeId: widget.player.rateeId),
      ));
      ref.invalidate(matchPlayerRatingsProvider);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
        _ratingOpen = false;
      });
      showToast(context, '评分成功');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(context, '评分失败: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final player = widget.player;
    final match = widget.match;
    final profile = ref.watch(profileByIdProvider(player.rateeId)).valueOrNull;
    final avatarUrl = profile?.avatarUrl;
    final rated = player.votes > 0;
    final isMe = currentUserId == player.rateeId;
    final canRate = !isMe && match.status == MatchStatus.finished;

    final ratingsAsync = ref.watch(
      _playerRatingsForMatchProvider((matchId: match.id, rateeId: player.rateeId)),
    );

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(player.name),
        backgroundColor: t.bg,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _DetailHeader(player: player, avatarUrl: avatarUrl, rated: rated),
          const SizedBox(height: 20),
          ratingsAsync.when(
            loading: () => const _GoalsLoading(),
            error: (e, _) => const SizedBox.shrink(),
            data: (ratings) => _ScoreDistChart(ratings: ratings),
          ),
          const SizedBox(height: 16),
          ratingsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (ratings) => _ReviewsList(ratings: ratings, matchId: match.id),
          ),
        ],
      ),
      bottomNavigationBar: canRate
          ? _RateBottomBar(
              score: _score,
              commentCtrl: _commentCtrl,
              submitting: _submitting,
              submitted: _submitted,
              ratingOpen: _ratingOpen,
              onToggle: () => setState(() => _ratingOpen = !_ratingOpen),
              onScoreChanged: (v) => setState(() => _score = v),
              onSubmit: _submit,
            )
          : null,
    );
  }
}

// ─── Bottom bar with expandable rating panel ───────────────
class _RateBottomBar extends StatelessWidget {
  final double score;
  final TextEditingController commentCtrl;
  final bool submitting;
  final bool submitted;
  final bool ratingOpen;
  final VoidCallback onToggle;
  final ValueChanged<double> onScoreChanged;
  final VoidCallback onSubmit;

  const _RateBottomBar({
    required this.score,
    required this.commentCtrl,
    required this.submitting,
    required this.submitted,
    required this.ratingOpen,
    required this.onToggle,
    required this.onScoreChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.of(context).padding.bottom;

    final Color scoreColor;
    final String scoreLabel;
    if (score >= 8) {
      scoreColor = t.accent;
      scoreLabel = '神级表现';
    } else if (score >= 6) {
      scoreColor = t.ink;
      scoreLabel = '表现不错';
    } else if (score >= 4) {
      scoreColor = t.warn;
      scoreLabel = '一般般';
    } else {
      scoreColor = t.danger;
      scoreLabel = '有待提高';
    }

    return Container(
      decoration: BoxDecoration(
        color: t.elev1,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ratingOpen && !submitted) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            fontFamily: t.fontMono,
                            fontFamilyFallback: t.monoFallbacks,
                            color: scoreColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(scoreLabel, style: TextStyle(fontSize: 13, color: scoreColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: scoreColor,
                        inactiveTrackColor: t.elev3,
                        thumbColor: scoreColor,
                        overlayColor: scoreColor.withValues(alpha: 0.12),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: score,
                        min: 0,
                        max: 10,
                        divisions: 20,
                        onChanged: onScoreChanged,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0', style: TextStyle(fontSize: 10, color: t.inkDim, fontFamily: t.fontMono, fontFamilyFallback: t.monoFallbacks)),
                        Text('10', style: TextStyle(fontSize: 10, color: t.inkDim, fontFamily: t.fontMono, fontFamilyFallback: t.monoFallbacks)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 3,
                      minLines: 1,
                      style: TextStyle(fontSize: 14, color: t.ink),
                      decoration: InputDecoration(
                        hintText: '说点什么...',
                        hintStyle: TextStyle(color: t.inkMute),
                        filled: true,
                        fillColor: t.elev2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.r2), borderSide: BorderSide(color: t.line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.r2), borderSide: BorderSide(color: t.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.r2), borderSide: BorderSide(color: t.accent, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottom > 0 ? 4 : 12),
              child: submitted
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: t.accent),
                        const SizedBox(width: 6),
                        Text('评分已提交', style: TextStyle(fontSize: 14, color: t.accent, fontWeight: FontWeight.w600)),
                      ],
                    )
                  : ratingOpen
                      ? Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                label: '取消',
                                variant: BtnVariant.secondary,
                                full: true,
                                onPressed: onToggle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                label: submitting ? '提交中...' : '提交评分',
                                full: true,
                                disabled: submitting,
                                onPressed: onSubmit,
                              ),
                            ),
                          ],
                        )
                      : PrimaryButton(
                          label: '我来评一下',
                          full: true,
                          size: BtnSize.lg,
                          onPressed: onToggle,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail header inside the sheet ─────────────────────────
class _DetailHeader extends StatelessWidget {
  final PlayerRatingRow player;
  final String? avatarUrl;
  final bool rated;
  const _DetailHeader({required this.player, required this.avatarUrl, required this.rated});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final hue = player.name.isNotEmpty ? (player.name.codeUnitAt(0) * 37) % 360.0 : 0.0;

    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(
              1, hue, 0.3,
              Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.85,
            ).toColor(),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.line, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(avatarUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFb(player.name, t))
              : _avatarFb(player.name, t),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: t.ink)),
              const SizedBox(height: 3),
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
        if (rated) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ScoreBadge(score: player.avgScore),
              const SizedBox(height: 4),
              Text(l.match_rating_n_voted(player.votes), style: TextStyle(fontSize: 10, color: t.inkDim)),
            ],
          ),
        ] else
          Text(l.match_rating_not_rated, style: TextStyle(fontSize: 12, color: t.inkDim)),
      ],
    );
  }

  static Widget _avatarFb(String name, AppTokens t) => Center(
    child: Text(
      name.isNotEmpty ? name.characters.first : '?',
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: t.inkSub),
    ),
  );
}

// ─── Horizontal score distribution (0-10 scale) ─────────────
class _ScoreDistChart extends StatelessWidget {
  final List<Rating> ratings;
  const _ScoreDistChart({required this.ratings});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;

    final labels = ['0-2', '2-4', '4-6', '6-8', '8-10'];
    final counts = List<int>.filled(5, 0);
    for (final r in ratings) {
      final idx = (r.score / 2.0).floor().clamp(0, 4);
      counts[idx]++;
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.match_rating_score_dist, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
        const SizedBox(height: 10),
        for (int i = 4; i >= 0; i--)
          Padding(
            padding: EdgeInsets.only(bottom: i > 0 ? 6 : 0),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: t.fontMono,
                      fontFamilyFallback: t.monoFallbacks,
                      fontSize: 10,
                      color: t.inkDim,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(color: t.elev2, borderRadius: BorderRadius.circular(4)),
                    clipBehavior: Clip.antiAlias,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxCount > 0 ? counts[i] / maxCount : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _barColor(i, t),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  child: Text(
                    '${counts[i]}',
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
    );
  }

  static Color _barColor(int bucket, AppTokens t) {
    if (bucket >= 4) return t.accent;
    if (bucket >= 3) return t.accent.withValues(alpha: 0.6);
    if (bucket >= 2) return t.warn;
    return t.danger;
  }
}

// ─── Reviews list ───────────────────────────────────────────
class _ReviewsList extends StatelessWidget {
  final List<Rating> ratings;
  final String matchId;
  const _ReviewsList({required this.ratings, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    final avg = ratings.isEmpty
        ? 0.0
        : ratings.map((r) => r.score).reduce((a, b) => a + b) / ratings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l.match_rating_all_reviews, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.ink)),
            const SizedBox(width: 6),
            Text('${ratings.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.inkDim)),
            const Spacer(),
            if (ratings.isNotEmpty) ...[
              Text('均分', style: TextStyle(fontSize: 11, color: t.inkDim)),
              const SizedBox(width: 6),
              _ScoreBadge(score: avg, mini: true),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (ratings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text(l.match_rating_no_reviews, style: TextStyle(color: t.inkDim, fontSize: 12))),
          )
        else
          for (final r in ratings) _ReviewRow(rating: r, matchId: matchId),
      ],
    );
  }
}

class _ReviewRow extends ConsumerWidget {
  final Rating rating;
  final String matchId;
  const _ReviewRow({required this.rating, required this.matchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final profile = ref.watch(profileByIdProvider(rating.raterId)).valueOrNull;
    final raterName = profile?.name ?? '匿名';
    final likedIds = ref.watch(likedRatingIdsProvider(matchId)).valueOrNull ?? {};
    final isLiked = likedIds.contains(rating.id);
    final isMe = rating.raterId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(raterName, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(raterName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isMe ? t.accent : t.ink)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: t.accentSubtle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('我', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: t.accent)),
                      ),
                    ],
                    const Spacer(),
                    _ScoreBadge(score: rating.score, mini: true),
                  ],
                ),
                if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(rating.comment!, style: TextStyle(fontSize: 13, color: t.ink, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_relativeTime(rating.createdAt), style: TextStyle(fontSize: 10, color: t.inkDim)),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await ref.read(ratingsRepoProvider).toggleLike(rating.id);
                        ref.invalidate(likedRatingIdsProvider(matchId));
                        ref.invalidate(_playerRatingsForMatchProvider(
                          (matchId: rating.matchId, rateeId: rating.rateeId),
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: isLiked ? t.danger : t.inkDim,
                            ),
                            if (rating.likes > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '${rating.likes}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isLiked ? t.danger : t.inkDim,
                                ),
                              ),
                            ],
                          ],
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
// TAB 4: Discussion — match comments
// ═════════════════════════════════════════════════════════════
class _DiscussionTab extends ConsumerStatefulWidget {
  final Match match;
  const _DiscussionTab({required this.match});

  @override
  ConsumerState<_DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends ConsumerState<_DiscussionTab> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      showToast(context, l.comment_empty_toast, info: true);
      return;
    }
    if (!isSignedIn) {
      showToast(context, l.comment_login_required, info: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(commentsRepoProvider).add(
            targetType: 'match',
            targetId: widget.match.id,
            body: text,
          );
      _ctrl.clear();
      ref.invalidate(commentsProvider((type: 'match', id: widget.match.id)));
    } catch (_) {
      if (mounted) {
        showToast(context, l.comment_send_failed, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleLike(Comment c) async {
    if (!isSignedIn) return;
    await ref.read(likesRepoProvider).toggle('match_comment', c.id);
    ref.invalidate(commentsProvider((type: 'match', id: widget.match.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final commentsAsync = ref.watch(
      commentsProvider((type: 'match', id: widget.match.id)),
    );

    return Column(
      children: [
        Expanded(
          child: commentsAsync.when(
            data: (list) => list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forum_outlined,
                            size: 48, color: t.inkMute),
                        const SizedBox(height: 12),
                        Text(l.match_no_comments,
                            style:
                                TextStyle(fontSize: 13, color: t.inkDim)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _MatchCommentTile(
                      comment: list[i],
                      onLike: () => _toggleLike(list[i]),
                    ),
                  ),
            loading: () => Center(
              child: CircularProgressIndicator(color: t.accent),
            ),
            error: (_, __) => Center(
              child: Text(l.error_load_failed,
                  style: TextStyle(fontSize: 13, color: t.inkSub)),
            ),
          ),
        ),
        RichInput(
          controller: _ctrl,
          onSend: _send,
          sending: _sending,
          hintText: l.comment_hint,
        ),
      ],
    );
  }
}

class _MatchCommentTile extends StatelessWidget {
  final Comment comment;
  final VoidCallback onLike;
  const _MatchCommentTile({required this.comment, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: comment.authorId != null
              ? () => context.push('/user/${comment.authorId}')
              : null,
          child: Avatar(comment.authorName, size: 34),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(comment.authorName,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.ink)),
                  ),
                  Text(comment.displayTime,
                      style: TextStyle(fontSize: 10, color: t.inkMute)),
                ],
              ),
              const SizedBox(height: 4),
              Text(comment.body,
                  style: TextStyle(
                      fontSize: 14, color: t.ink, height: 1.5)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onLike,
                child: InteractionBtn(
                  icon: Icons.favorite_border,
                  label: comment.likes > 0 ? '${comment.likes}' : '',
                  color: t.inkMute,
                ),
              ),
            ],
          ),
        ),
      ],
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
    final match = widget.match;
    if (match.teamAId == null && match.teamALabel == null ||
        match.teamBId == null && match.teamBLabel == null) {
      showToast(context, context.l10n.match_start_needs_teams, error: true);
      return;
    }
    setState(() => _starting = true);
    try {
      await ref.read(eventsRepoProvider).startMatch(match.id);
      if (!mounted) return;
      ref.invalidate(eventMatchesProvider(widget.eventId));
      context.push('/event/${widget.eventId}/match/${match.id}/control');
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
      if (isOrganizer) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PrimaryButton(
            label: l.match_control_title,
            full: true,
            size: BtnSize.lg,
            onPressed: () => context.push(
              '/event/${widget.eventId}/match/${widget.match.id}/control',
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PrimaryButton(
          label: l.event_cta_watch_live,
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
