// match_detail_screen.dart — 单场比赛详情
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../repositories/goals_repository.dart';
import '../../services/local_storage.dart';
import '../../utils/toast.dart';
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
      appBar: AppBar(
        backgroundColor: context.tokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: context.tokens.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.match_detail_title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        shape: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
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
// Body
// ─────────────────────────────────────────────────────────────
class _MatchDetailBody extends ConsumerWidget {
  final Match match;
  final String eventId;
  const _MatchDetailBody({required this.match, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(matchGoalsProvider(match.id));
    final status = match.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(match: match, status: status),
          const SizedBox(height: 8),
          if (match.status == MatchStatus.finished)
            goalsAsync.when(
              loading: () => const _GoalsLoading(),
              error: (e, _) => _GoalsError(error: e),
              data: (goals) => _GoalsSection(goals: goals),
            ),
          const SizedBox(height: 24),
          _BottomCtaArea(match: match, status: status, eventId: eventId),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header: round label + status chip + teams/scores + time
// ─────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final Match match;
  final MatchStatus status;
  const _HeaderCard({required this.match, required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sa = match.scoreA;
    final sb = match.scoreB;
    final aWins = match.status == MatchStatus.finished && sa != null && sb != null && sa > sb;
    final bWins = match.status == MatchStatus.finished && sa != null && sb != null && sb > sa;
    final timeStr = _formatPlayedAt(match.playedAt);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Label(_roundLabel(l, match.round)),
              const Spacer(),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          _TeamRow(
            name: match.teamALabel ?? 'TBD',
            score: sa,
            won: aWins,
            done: match.done,
          ),
          const SizedBox(height: 10),
          _TeamRow(
            name: match.teamBLabel ?? 'TBD',
            score: sb,
            won: bWins,
            done: match.done,
          ),
          if (match.pkScore != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.tokens.warnSubtle,
                  borderRadius: BorderRadius.circular(context.tokens.r1),
                ),
                child: Text(
                  'PK ${match.pkScore}',
                  style: TextStyle(
                    fontFamily: context.tokens.fontMono,
                    fontFamilyFallback: context.tokens.monoFallbacks,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.warn,
                  ),
                ),
              ),
            ),
          ],
          if (timeStr != null) ...[
            const SizedBox(height: 10),
            Text(
              timeStr,
              style: TextStyle(
                fontFamily: context.tokens.fontMono,
                fontFamilyFallback: context.tokens.monoFallbacks,
                fontSize: 11,
                color: context.tokens.inkDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final int? score;
  final bool won;
  final bool done;
  const _TeamRow({
    required this.name,
    required this.score,
    required this.won,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = done ? (won ? context.tokens.ink : context.tokens.inkSub) : context.tokens.ink;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              color: nameColor,
              fontWeight: won ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (done && score != null)
          N(
            '$score',
            size: 22,
            weight: FontWeight.w800,
            color: won ? context.tokens.accent : context.tokens.inkSub,
          )
        else
          Text('-', style: TextStyle(color: context.tokens.inkDim, fontSize: 16)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final MatchStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg, fg, text) = switch (status) {
      MatchStatus.upcoming => (context.tokens.elev3, context.tokens.inkSub, l.match_status_upcoming),
      MatchStatus.live => (context.tokens.accentSubtle, context.tokens.accent, l.match_status_live),
      MatchStatus.finished => (context.tokens.elev3, context.tokens.inkDim, l.match_status_done),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.tokens.r1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Goals timeline
// ─────────────────────────────────────────────────────────────
class _GoalsSection extends StatelessWidget {
  final List<GoalEvent> goals;
  const _GoalsSection({required this.goals});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Label(l.match_goals_section),
          const SizedBox(height: 10),
          if (goals.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Text(
                l.match_goals_empty,
                style: TextStyle(color: context.tokens.inkDim, fontSize: 12),
              ),
            )
          else
            for (final g in goals) _GoalRow(goal: g),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: N(
              goal.minute != null ? "${goal.minute}'" : '-',
              size: 13,
              weight: FontWeight.w700,
              color: context.tokens.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.scorerName ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (goal.assistId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l.match_assist_by(goal.assistId!),
                    style: TextStyle(fontSize: 11, color: context.tokens.inkSub),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (goal.isPenalty) _GoalTag(text: l.match_penalty, color: context.tokens.accent),
          if (goal.isOwnGoal) ...[
            if (goal.isPenalty) const SizedBox(width: 6),
            _GoalTag(text: l.match_own_goal, color: context.tokens.warn),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(context.tokens.r1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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

    if (widget.status == MatchStatus.finished) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PrimaryButton(
          label: l.match_cta_view_ratings,
          full: true,
          size: BtnSize.lg,
          onPressed: () => context.push(
            '/event/${widget.eventId}/match/${widget.match.id}/ratings',
          ),
        ),
      );
    }

    if (widget.status == MatchStatus.upcoming) {
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
    padding: EdgeInsets.symmetric(vertical: 24),
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

String? _formatPlayedAt(DateTime? at) {
  if (at == null) return null;
  final mm = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  final hh = at.hour.toString().padLeft(2, '0');
  final mi = at.minute.toString().padLeft(2, '0');
  return '$mm-$dd $hh:$mi';
}
