// wc_predict_screen.dart — 世界杯竞猜（PredictionsRepository 主，LocalStore cache 同步）
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class WcPredictScreen extends ConsumerStatefulWidget {
  final String matchId;
  const WcPredictScreen({super.key, required this.matchId});

  @override
  ConsumerState<WcPredictScreen> createState() => _WcPredictScreenState();
}

class _WcPredictScreenState extends ConsumerState<WcPredictScreen> {
  String? _choice;
  int _stake = 50;

  @override
  void initState() {
    super.initState();
    final existing = LocalStore.getPrediction(widget.matchId);
    if (existing != null) {
      final parts = existing.split(':');
      _choice = parts.first;
      if (parts.length > 1) _stake = int.tryParse(parts[1]) ?? _stake;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final r = Random(widget.matchId.hashCode);
    final aPct = 35 + r.nextInt(40); // 35-74
    final dPct = 8 + r.nextInt(18); // 8-25
    final bPct = (100 - aPct - dPct).clamp(5, 70);

    final existing = LocalStore.getPrediction(widget.matchId);
    final submitted = existing != null;

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            PageTitleBar(
              title: l.wc_predict_title,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r3),
                ),
                child: Row(
                  children: [
                    _TeamFlag(code: 'ARG', hue: 200, name: l.wc_team_argentina),
                    const Spacer(),
                    Text(
                      'VS',
                      style: TextStyle(
                        color: context.tokens.inkDim,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    _TeamFlag(code: 'BRA', hue: 140, name: l.wc_team_brazil),
                  ],
                ),
              ),
            ),
            SectionHeader(title: l.wc_predict_pick_title),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: _Option(
                      label: l.wc_predict_home_win,
                      active: _choice == 'A',
                      onTap: () => setState(() => _choice = 'A'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Option(
                      label: l.wc_predict_draw,
                      active: _choice == 'draw',
                      onTap: () => setState(() => _choice = 'draw'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Option(
                      label: l.wc_predict_away_win,
                      active: _choice == 'B',
                      onTap: () => setState(() => _choice = 'B'),
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(title: l.wc_predict_stake),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  for (final s in const [10, 50, 100, 500]) ...[
                    Expanded(
                      child: _StakeBtn(
                        value: s,
                        active: _stake == s,
                        onTap: () => setState(() => _stake = s),
                      ),
                    ),
                    if (s != 500) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            SectionHeader(title: l.wc_predict_distribution),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _Bar(
                          flex: aPct,
                          label: '$aPct%',
                          color: context.tokens.accent,
                          fg: Colors.black,
                        ),
                        const SizedBox(width: 6),
                        _Bar(
                          flex: dPct,
                          label: '$dPct%',
                          color: context.tokens.inkMute,
                          fg: context.tokens.ink,
                        ),
                        const SizedBox(width: 6),
                        _Bar(
                          flex: bPct,
                          label: '$bPct%',
                          color: context.tokens.elev3,
                          fg: context.tokens.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Label(l.wc_predict_home_win),
                        Label(l.wc_predict_draw),
                        Label(l.wc_predict_away_win),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (submitted)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.tokens.accentSubtle,
                    border: Border.all(color: const Color(0x6600FF85)),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: context.tokens.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l.wc_predict_submitted} · ${l.wc_predict_change(_label(context, _choice ?? ''))}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.tokens.ink,
                            fontWeight: FontWeight.w500,
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
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
        decoration: BoxDecoration(
          color: context.tokens.elev1,
          border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: PrimaryButton(
          label: submitted ? l.wc_predict_submitted : l.wc_predict_submit,
          variant: submitted ? BtnVariant.secondary : BtnVariant.primary,
          size: BtnSize.lg,
          full: true,
          onPressed: _choice == null
              ? null
              : () async {
                  await ref
                      .read(predictionsRepoProvider)
                      .submit(
                        matchId: widget.matchId,
                        choice: _choice!,
                        stake: _stake,
                      );
                  ref.invalidate(myPredictionProvider(widget.matchId));
                  ref.invalidate(predictionDistProvider(widget.matchId));
                  if (!context.mounted) return;
                  showToast(context, l.wc_predict_submitted, success: true);
                  setState(() {});
                },
        ),
      ),
    );
  }

  String _label(BuildContext context, String choice) {
    final l = context.l10n;
    return switch (choice) {
      'A' => l.wc_predict_home_win,
      'B' => l.wc_predict_away_win,
      _ => l.wc_predict_draw,
    };
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Option({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : context.tokens.elev2,
          border: Border.all(color: active ? context.tokens.accent : context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? context.tokens.accent : context.tokens.ink,
          ),
        ),
      ),
    );
  }
}

class _StakeBtn extends StatelessWidget {
  final int value;
  final bool active;
  final VoidCallback onTap;
  const _StakeBtn({
    required this.value,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : context.tokens.elev2,
          border: Border.all(color: active ? context.tokens.accent : context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
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
        height: 32,
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

class _TeamFlag extends StatelessWidget {
  final String code, name;
  final double hue;
  const _TeamFlag({required this.code, required this.hue, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HSLColor.fromAHSL(1, hue, 0.4, 0.28).toColor(),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontFamily: context.tokens.fontMono,
              fontFamilyFallback: context.tokens.monoFallbacks,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.tokens.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: context.tokens.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
