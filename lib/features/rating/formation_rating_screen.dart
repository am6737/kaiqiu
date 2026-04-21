// formation_rating_screen.dart — 足球野球局阵型图打分
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/pickup.dart';
import '../../providers.dart';
import '../../repositories/goals_repository.dart';
import '../../services/supabase.dart' as svc;
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import 'widgets/pitch_view.dart';
import 'widgets/rate_player_sheet.dart';
import '../../theme/app_tokens.dart';

class FormationRatingScreen extends ConsumerStatefulWidget {
  final String pickupId;
  const FormationRatingScreen({super.key, required this.pickupId});

  @override
  ConsumerState<FormationRatingScreen> createState() =>
      _FormationRatingScreenState();
}

class _FormationRatingScreenState
    extends ConsumerState<FormationRatingScreen> {
  final Map<String, double> _scores = {};
  final Map<String, String> _comments = {};
  bool _submitting = false;

  bool _canRate(PickupSlot s, String? uid) {
    if (!s.filled) return false;
    if (uid != null && s.userId == uid) return false; // 不能给自己打
    return true;
  }

  PickupSlot? _nextUnrated(List<PickupSlot> rateable, PickupSlot current) {
    final idx = rateable.indexWhere((s) => s.id == current.id);
    // 先向后找
    for (int i = 1; i <= rateable.length; i++) {
      final s = rateable[(idx + i) % rateable.length];
      if (s.id == current.id) break;
      if (!_scores.containsKey(s.id)) return s;
    }
    return null;
  }

  Map<String, ({int goals, int assists})> _aggregateStats(
    List<GoalEvent> goals,
  ) {
    final map = <String, ({int goals, int assists})>{};
    void bump(String? id, {bool isGoal = false, bool isAssist = false}) {
      if (id == null) return;
      final cur = map[id] ?? (goals: 0, assists: 0);
      map[id] = (
        goals: cur.goals + (isGoal ? 1 : 0),
        assists: cur.assists + (isAssist ? 1 : 0),
      );
    }

    for (final g in goals) {
      bump(g.scorerId, isGoal: true);
      bump(g.assistId, isAssist: true);
    }
    return map;
  }

  Future<void> _openSheet(
    PickupSlot slot,
    List<PickupSlot> rateable,
    Map<String, ({int goals, int assists})> statsMap,
  ) async {
    final uid = svc.currentUserId;
    if (uid != null && slot.userId == uid) {
      showToast(context, context.l10n.rate_pitch_cannot_self);
      return;
    }
    if (!slot.filled) return;

    final agg = slot.userId != null ? statsMap[slot.userId!] : null;
    final stats = PlayerMatchStats(
      goals: agg?.goals ?? 0,
      assists: agg?.assists ?? 0,
    );

    final unrateCount =
        rateable.where((s) => !_scores.containsKey(s.id)).length;
    final label = unrateCount > 1
        ? context.l10n.rate_pitch_save_next
        : context.l10n.common_save;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatePlayerSheet(
        slot: slot,
        stats: stats,
        initialScore: _scores[slot.id],
        initialComment: _comments[slot.id],
        nextButtonLabel: label,
        onSave: (score, comment) {
          setState(() {
            _scores[slot.id] = score;
            _comments[slot.id] = comment;
          });
          Navigator.of(context).pop();
          final next = _nextUnrated(rateable, slot);
          if (next != null) {
            // 让抽屉动画完成后再开下一条
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openSheet(next, rateable, statsMap);
            });
          }
        },
      ),
    );
  }

  Future<void> _submit(List<PickupSlot> rateable) async {
    if (_scores.isEmpty) return;
    final uid = svc.currentUserId;
    if (uid == null) {
      showToast(context, context.l10n.error_please_login, error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      int written = 0;
      for (final s in rateable) {
        final score = _scores[s.id];
        if (score == null) continue;
        final name = s.displayName ?? s.userId ?? s.position;
        await svc.supabase.from('ratings').upsert({
          'match_id': widget.pickupId,
          'rater_id': uid,
          'ratee_id': s.userId,
          'ratee_name': name,
          'score': score,
          'comment': _comments[s.id]?.trim().isEmpty == true
              ? null
              : _comments[s.id],
          'highlight': null,
        }, onConflict: 'match_id,rater_id,ratee_name');
        written++;
      }
      if (!mounted) return;
      showToast(
        context,
        context.l10n.rate_pitch_submitted_n(written),
        success: true,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showToast(context, context.l10n.rate_submit_failed('$e'), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final slotsAsync = ref.watch(pickupSlotsProvider(widget.pickupId));
    final goalsAsync = ref.watch(matchGoalsProvider(widget.pickupId));
    final uid = svc.currentUserId;

    return Scaffold(
      backgroundColor: context.tokens.bg,
      appBar: AppBar(
        backgroundColor: context.tokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, size: 20, color: context.tokens.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.rate_pitch_title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        shape: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      body: slotsAsync.when(
        loading: () => Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${l.error_load_failed}\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.inkSub),
            ),
          ),
        ),
        data: (slots) {
          final filled = slots.where((s) => s.filled).toList();
          final rateable =
              filled.where((s) => _canRate(s, uid)).toList(growable: false);

          if (rateable.isEmpty) {
            return _EmptyState(onBack: () => context.pop());
          }

          final statsMap = goalsAsync.maybeWhen(
            data: (g) => _aggregateStats(g),
            orElse: () => <String, ({int goals, int assists})>{},
          );
          final rated = _scores.length;
          final total = rateable.length;

          return Column(
            children: [
              _ProgressHeader(rated: rated, total: total, hint: l.rate_pitch_tap_hint),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: PitchView(
                    slots: filled,
                    currentUserId: uid,
                    selectedSlotId: null,
                    ratedScores: _scores,
                    onTap: (s) => _openSheet(s, rateable, statsMap),
                  ),
                ),
              ),
              _SubmitBar(
                rated: rated,
                total: total,
                submitting: _submitting,
                onSubmit: rated > 0 ? () => _submit(rateable) : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int rated;
  final int total;
  final String hint;
  const _ProgressHeader({
    required this.rated,
    required this.total,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final frac = total == 0 ? 0.0 : rated / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Label(hint),
              N(
                context.l10n.rate_pitch_progress(rated, total),
                size: 12,
                weight: FontWeight.w700,
                color: rated == total ? context.tokens.accent : context.tokens.ink,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 3,
              backgroundColor: context.tokens.elev3,
              valueColor: AlwaysStoppedAnimation(context.tokens.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final int rated;
  final int total;
  final bool submitting;
  final VoidCallback? onSubmit;
  const _SubmitBar({
    required this.rated,
    required this.total,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = submitting
        ? l.rate_submitting
        : (rated == total ? l.rate_submit_all : l.rate_pitch_submit_n(rated));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: PrimaryButton(
        label: label,
        variant: BtnVariant.primary,
        size: BtnSize.lg,
        full: true,
        disabled: submitting || onSubmit == null,
        onPressed: onSubmit,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBack;
  const _EmptyState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 28,
                color: context.tokens.inkSub,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.rate_pitch_empty_title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.tokens.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.rate_pitch_empty_sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.tokens.inkSub,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: l.rate_pitch_empty_back,
                variant: BtnVariant.secondary,
                size: BtnSize.md,
                full: true,
                onPressed: onBack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
