// live_predict_strip.dart — compact prediction bar for the live stream screen.
//
// Shows three-way outcome buttons (home / draw / away) with station-wide
// distribution percentages. Tapping any outcome opens a modal bottom sheet
// to confirm the pick + choose a stake + submit. Once submitted, the strip
// collapses into a summary chip ("你的选择: 主胜 · 50 分 ✓").
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers.dart';
import '../services/local_storage.dart';
import '../theme/tokens.dart';
import '../theme/app_tokens.dart';
import '../utils/toast.dart';
import 'typography.dart';

const _kStakes = [10, 50, 100, 500];

class LivePredictStrip extends ConsumerWidget {
  final String matchId;
  final String homeLabel;
  final String awayLabel;
  const LivePredictStrip({
    super.key,
    required this.matchId,
    required this.homeLabel,
    required this.awayLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localStoreProvider);
    final l = context.l10n;
    final raw = LocalStore.getPrediction(matchId);
    final dist = _fakeDistribution(matchId);

    if (raw == null) {
      return _UnvotedStrip(
        matchId: matchId,
        homeLabel: homeLabel,
        awayLabel: awayLabel,
        dist: dist,
        onTap: (choice) =>
            _openSheet(context, ref, initialChoice: choice, dist: dist),
      );
    }

    final parts = raw.split(':');
    final choice = parts.first;
    final stake = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return _VotedStrip(
      choiceLabel: _labelFor(l, choice, homeLabel, awayLabel),
      stake: stake,
      dist: dist,
      myChoice: choice,
      onTap: () =>
          _openSheet(context, ref, initialChoice: choice, dist: dist),
    );
  }

  void _openSheet(
    BuildContext context,
    WidgetRef ref, {
    required String initialChoice,
    required _FakeDist dist,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PredictSheet(
        matchId: matchId,
        homeLabel: homeLabel,
        awayLabel: awayLabel,
        initialChoice: initialChoice,
        dist: dist,
      ),
    );
  }
}

String _labelFor(AppL10n l, String choice, String home, String away) =>
    switch (choice) {
      'A' => '$home ${l.wc_predict_home_win}',
      'B' => '$away ${l.wc_predict_away_win}',
      _ => l.wc_predict_draw,
    };

/// Deterministic pseudo-random distribution seeded by matchId — matches the
/// look of the standalone predict screen.
class _FakeDist {
  final int a, d, b;
  const _FakeDist(this.a, this.d, this.b);
}

_FakeDist _fakeDistribution(String matchId) {
  final r = Random(matchId.hashCode);
  final aPct = 35 + r.nextInt(40); // 35-74
  final dPct = 8 + r.nextInt(18); // 8-25
  final bPct = (100 - aPct - dPct).clamp(5, 70);
  return _FakeDist(aPct, dPct, bPct);
}

class _UnvotedStrip extends StatelessWidget {
  final String matchId;
  final String homeLabel;
  final String awayLabel;
  final _FakeDist dist;
  final ValueChanged<String> onTap;
  const _UnvotedStrip({
    required this.matchId,
    required this.homeLabel,
    required this.awayLabel,
    required this.dist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: T.elev1,
        border: Border(bottom: BorderSide(color: T.line, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.accentSubtle,
                  border: Border.all(color: context.tokens.accent, width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PREDICT',
                  style: TextStyle(
                    fontFamily: T.fontMono,
                    fontFamilyFallback: T.monoFallbacks,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: context.tokens.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.wc_predict_pick_title,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.inkSub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _OutcomeBtn(
                  label: homeLabel,
                  sub: '${dist.a}%',
                  onTap: () => onTap('A'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _OutcomeBtn(
                  label: l.wc_predict_draw,
                  sub: '${dist.d}%',
                  onTap: () => onTap('draw'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _OutcomeBtn(
                  label: awayLabel,
                  sub: '${dist.b}%',
                  onTap: () => onTap('B'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutcomeBtn extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _OutcomeBtn({
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.tokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            N(sub, size: 10, weight: FontWeight.w600, color: context.tokens.inkDim),
          ],
        ),
      ),
    );
  }
}

class _VotedStrip extends StatelessWidget {
  final String choiceLabel;
  final int stake;
  final _FakeDist dist;
  final String myChoice;
  final VoidCallback onTap;
  const _VotedStrip({
    required this.choiceLabel,
    required this.stake,
    required this.dist,
    required this.myChoice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final myPct = switch (myChoice) {
      'A' => dist.a,
      'B' => dist.b,
      _ => dist.d,
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: T.elev1,
          border: Border(bottom: BorderSide(color: T.line, width: 1)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: context.tokens.accent, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l.wc_predict_you_picked}: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.inkDim,
                      ),
                    ),
                    TextSpan(
                      text: choiceLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.tokens.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (stake > 0)
                      TextSpan(
                        text: ' · $stake',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokens.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: T.elev2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: T.line),
              ),
              child: N(
                '$myPct%',
                size: 11,
                weight: FontWeight.w700,
                color: context.tokens.accent,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: context.tokens.inkDim, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PredictSheet extends ConsumerStatefulWidget {
  final String matchId;
  final String homeLabel;
  final String awayLabel;
  final String initialChoice;
  final _FakeDist dist;
  const _PredictSheet({
    required this.matchId,
    required this.homeLabel,
    required this.awayLabel,
    required this.initialChoice,
    required this.dist,
  });

  @override
  ConsumerState<_PredictSheet> createState() => _PredictSheetState();
}

class _PredictSheetState extends ConsumerState<_PredictSheet> {
  late String _choice = widget.initialChoice;
  int _stake = 50;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = LocalStore.getPrediction(widget.matchId);
    if (existing != null) {
      final parts = existing.split(':');
      if (parts.isNotEmpty) _choice = parts.first;
      if (parts.length > 1) _stake = int.tryParse(parts[1]) ?? _stake;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref
        .read(predictionsRepoProvider)
        .submit(matchId: widget.matchId, choice: _choice, stake: _stake);
    ref.invalidate(myPredictionProvider(widget.matchId));
    ref.invalidate(predictionDistProvider(widget.matchId));
    if (!mounted) return;
    final l = context.l10n;
    showToast(context, l.wc_predict_submitted, success: true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final alreadySubmitted = LocalStore.getPrediction(widget.matchId) != null;
    return Container(
      decoration: const BoxDecoration(
        color: T.elev1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.r4)),
        border: Border(top: BorderSide(color: T.line, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
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
              Text(
                l.wc_predict_title,
                style: TextStyle(
                  color: context.tokens.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${widget.homeLabel} vs ${widget.awayLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.tokens.inkDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.wc_predict_pick_title,
            style: TextStyle(
              fontSize: 12,
              color: context.tokens.inkSub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BigOption(
                  label: widget.homeLabel,
                  sub: l.wc_predict_home_win,
                  active: _choice == 'A',
                  onTap: () => setState(() => _choice = 'A'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigOption(
                  label: l.wc_predict_draw,
                  sub: '',
                  active: _choice == 'draw',
                  onTap: () => setState(() => _choice = 'draw'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigOption(
                  label: widget.awayLabel,
                  sub: l.wc_predict_away_win,
                  active: _choice == 'B',
                  onTap: () => setState(() => _choice = 'B'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.wc_predict_stake,
            style: TextStyle(
              fontSize: 12,
              color: context.tokens.inkSub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final s in _kStakes) ...[
                Expanded(
                  child: _StakeChip(
                    value: s,
                    active: _stake == s,
                    onTap: () => setState(() => _stake = s),
                  ),
                ),
                if (s != _kStakes.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.wc_predict_distribution,
            style: TextStyle(
              fontSize: 12,
              color: context.tokens.inkSub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _DistBars(dist: widget.dist),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _submit,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _submitting ? context.tokens.accentSubtle : context.tokens.accent,
                borderRadius: BorderRadius.circular(T.r3),
              ),
              child: Text(
                _submitting
                    ? '…'
                    : alreadySubmitted
                    ? l.wc_predict_submitted
                    : l.wc_predict_submit,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigOption extends StatelessWidget {
  final String label;
  final String sub;
  final bool active;
  final VoidCallback onTap;
  const _BigOption({
    required this.label,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : T.elev2,
          border: Border.all(color: active ? context.tokens.accent : T.line),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: active ? context.tokens.accent : context.tokens.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? context.tokens.accent : context.tokens.inkDim,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StakeChip extends StatelessWidget {
  final int value;
  final bool active;
  final VoidCallback onTap;
  const _StakeChip({
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : T.elev2,
          border: Border.all(color: active ? context.tokens.accent : T.line),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: N(
          '$value',
          size: 13,
          weight: FontWeight.w700,
          color: active ? context.tokens.accent : context.tokens.ink,
        ),
      ),
    );
  }
}

class _DistBars extends StatelessWidget {
  final _FakeDist dist;
  const _DistBars({required this.dist});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.elev2,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Bar(flex: dist.a, label: '${dist.a}%', color: context.tokens.accent, fg: Colors.black),
              const SizedBox(width: 6),
              _Bar(
                flex: dist.d,
                label: '${dist.d}%',
                color: context.tokens.inkMute,
                fg: context.tokens.ink,
              ),
              const SizedBox(width: 6),
              _Bar(
                flex: dist.b,
                label: '${dist.b}%',
                color: T.elev3,
                fg: context.tokens.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int flex;
  final String label;
  final Color color;
  final Color fg;
  const _Bar({
    required this.flex,
    required this.label,
    required this.color,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: N(label, size: 11, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}
