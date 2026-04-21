// post_match_rating_screen.dart — 虎扑式赛后评分
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock.dart' as mock;
import '../../l10n/l10n_extension.dart';
import '../../services/supabase.dart' as svc;
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class PostMatchRatingScreen extends ConsumerStatefulWidget {
  final String matchId;
  const PostMatchRatingScreen({super.key, required this.matchId});

  @override
  ConsumerState<PostMatchRatingScreen> createState() =>
      _PostMatchRatingScreenState();
}

class _PostMatchRatingScreenState extends ConsumerState<PostMatchRatingScreen> {
  int _idx = 0;
  final Map<String, double> _ratings = {};
  final Map<String, String> _comments = {};
  bool _done = false;
  bool _submitting = false;

  late final List<mock.RatingPlayer> _players = [
    ...mock.yourTeam,
    ...mock.oppTeam,
  ];

  /// Submit all non-null ratings to Supabase. Returns count written.
  Future<int> _submitAll() async {
    final uid = svc.currentUserId;
    if (uid == null) throw StateError('Not signed in');
    int written = 0;
    for (final p in _players) {
      final score = _ratings[p.name];
      if (score == null) continue;
      await svc.supabase.from('ratings').upsert({
        'match_id': widget.matchId,
        'rater_id': uid,
        'ratee_id': null,
        'ratee_name': p.name,
        'score': score,
        'comment': _comments[p.name],
        'highlight': p.highlight,
      }, onConflict: 'match_id,rater_id,ratee_name');
      written++;
    }
    return written;
  }

  Future<void> _commit(int nextIdx) async {
    if (nextIdx < _players.length) {
      setState(() => _idx = nextIdx);
      return;
    }
    // End of list — submit everything then show done page.
    setState(() => _submitting = true);
    try {
      await _submitAll();
      if (!mounted) return;
      setState(() {
        _done = true;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(context, context.l10n.rate_submit_failed('$e'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _DonePage(count: _ratings.length);

    final p = _players[_idx];
    final cur = _ratings[p.name] ?? (p.you ? 0.0 : p.avgScore);
    final info = mock.ratingMatchInfo;

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.close, size: 20, color: context.tokens.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Label(context.l10n.rate_panel_title),
                        const SizedBox(height: 2),
                        Text(
                          info.event,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.tokens.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      N('${_idx + 1}', size: 13, weight: FontWeight.w700),
                      N('/${_players.length}', size: 13, color: context.tokens.inkDim),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Progress segments
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                for (int i = 0; i < _players.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: i < _idx
                            ? context.tokens.accent
                            : i == _idx
                            ? context.tokens.ink
                            : context.tokens.elev3,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match summary
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(context.tokens.r3),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            info.teamA,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.tokens.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        N(
                          '${info.scoreA}',
                          size: 20,
                          weight: FontWeight.w700,
                          color: context.tokens.accent,
                        ),
                        Text(' - ', style: TextStyle(color: context.tokens.inkDim)),
                        N(
                          '${info.scoreB}',
                          size: 20,
                          weight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            info.teamB,
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
                  // Player card + slider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(context.tokens.r3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TODO(dm-initiation): 当 RatingPlayer 增加 userId 字段后，追加
                        //   onLongPress: () => showUserCardSheet(context, ref, userId: p.userId!);
                        // 现阶段 RatingPlayer 仅存 name（mock 数据），无法驱动 profile 查询。
                        Row(
                          children: [
                            Avatar(p.name, size: 50),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: context.tokens.ink,
                                        ),
                                      ),
                                      if (p.you) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.tokens.accentSubtle,
                                            border: Border.all(
                                              color: const Color(0x6600FF85),
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          child: Text(
                                            context.l10n.rate_short_you,
                                            style: TextStyle(
                                              fontFamily: context.tokens.fontMono,
                                              fontFamilyFallback:
                                                  context.tokens.monoFallbacks,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: context.tokens.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Label('${p.team ?? info.teamA} · ${p.pos}'),
                                ],
                              ),
                            ),
                            if (p.highlight != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: context.tokens.warnSubtle,
                                  border: Border.all(
                                    color: const Color(0x66FF6B35),
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Label(p.highlight!, color: context.tokens.warn),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _RatingSlider(
                          value: cur,
                          onChanged: (v) {
                            setState(() => _ratings[p.name] = v);
                          },
                        ),
                        const SizedBox(height: 18),
                        Label(context.l10n.rate_say_optional),
                        const SizedBox(height: 6),
                        TextField(
                          key: ValueKey('comment-${p.name}'),
                          minLines: 3,
                          maxLines: 4,
                          onChanged: (v) => _comments[p.name] = v,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.tokens.ink,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: p.you
                                ? context.l10n.rate_self_hint
                                : context.l10n.rate_other_hint,
                            hintStyle: TextStyle(color: context.tokens.inkDim),
                            filled: true,
                            fillColor: context.tokens.elev3,
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: context.tokens.line),
                              borderRadius: BorderRadius.circular(context.tokens.r2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: context.tokens.line),
                              borderRadius: BorderRadius.circular(context.tokens.r2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Crowd avg (non-self only)
                  if (!p.you) ...[
                    const SizedBox(height: 10),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.tokens.elev1,
                        border: Border.all(color: context.tokens.line),
                        borderRadius: BorderRadius.circular(context.tokens.r2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.military_tech_outlined,
                            size: 14,
                            color: context.tokens.inkSub,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Label(context.l10n.rate_voters_avg(p.votes)),
                          ),
                          N(
                            p.avgScore.toStringAsFixed(1),
                            size: 15,
                            weight: FontWeight.w700,
                            color: p.avgScore >= 8 ? context.tokens.accent : context.tokens.ink,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _BottomNav(
        idx: _idx,
        total: _players.length,
        canSubmit: _ratings[p.name] != null,
        submitting: _submitting,
        onBack: _idx > 0 && !_submitting ? () => _commit(_idx - 1) : null,
        onSkip: _submitting ? null : () => _commit(_idx + 1),
        onNext: _submitting ? null : () => _commit(_idx + 1),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int idx, total;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final VoidCallback? onNext;

  const _BottomNav({
    required this.idx,
    required this.total,
    required this.canSubmit,
    required this.submitting,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            PrimaryButton(
              label: context.l10n.rate_prev,
              variant: BtnVariant.secondary,
              size: BtnSize.lg,
              onPressed: onBack,
            ),
            const SizedBox(width: 10),
          ],
          PrimaryButton(
            label: context.l10n.rate_skip,
            variant: BtnVariant.ghost,
            size: BtnSize.lg,
            disabled: submitting,
            onPressed: onSkip,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PrimaryButton(
              label: submitting
                  ? context.l10n.rate_submitting
                  : (idx == total - 1
                        ? context.l10n.rate_submit_score
                        : context.l10n.rate_next),
              variant: BtnVariant.primary,
              size: BtnSize.lg,
              disabled: !canSubmit || submitting,
              onPressed: onNext,
              full: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Custom rating slider (0-10, step 0.5)
// ─────────────────────────────────────────────────────────────
class _RatingSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _RatingSlider({required this.value, required this.onChanged});

  Color _colorFor(BuildContext context, double v) {
    if (v >= 8) return context.tokens.accent;
    if (v >= 6) return context.tokens.ink;
    if (v >= 4) return context.tokens.warn;
    return context.tokens.danger;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, value);

    return Column(
      children: [
        // Big number
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            N(
              value.toStringAsFixed(1),
              size: 60,
              weight: FontWeight.w800,
              color: color,
            ),
            const SizedBox(width: 4),
            N('/10', size: 18, color: context.tokens.inkDim),
          ],
        ),
        const SizedBox(height: 14),
        // Track
        LayoutBuilder(
          builder: (_, c) {
            return GestureDetector(
              onPanDown: (d) => _update(d.localPosition.dx, c.maxWidth),
              onPanUpdate: (d) => _update(d.localPosition.dx, c.maxWidth),
              child: SizedBox(
                height: 46,
                child: Stack(
                  children: [
                    // Background track
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.tokens.elev2,
                          border: Border.all(color: context.tokens.line),
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                    ),
                    // Fill
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: (value / 10) * c.maxWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0x4DFF3B6B),
                              Color(0x4DFF6B35),
                              Color(0x1F00FF85),
                              Color(0x1F00FF85),
                            ],
                            stops: [0, 0.4, 0.75, 1],
                          ),
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                    ),
                    // Ticks
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (int n = 0; n <= 10; n++)
                              Text(
                                '$n',
                                style: TextStyle(
                                  fontFamily: context.tokens.fontMono,
                                  fontFamilyFallback: context.tokens.monoFallbacks,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: n <= value ? context.tokens.ink : context.tokens.inkDim,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Thumb
                    Positioned(
                      left: (value / 10) * c.maxWidth - 14,
                      top: 9,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: context.tokens.fontMono,
                            fontFamilyFallback: context.tokens.monoFallbacks,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (context) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Label(context.l10n.rate_level_bad, color: context.tokens.danger),
              Label(context.l10n.rate_level_meh),
              Label(context.l10n.rate_level_good, color: context.tokens.warn),
              Label(context.l10n.rate_level_god, color: context.tokens.accent),
            ],
          ),
        ),
      ],
    );
  }

  void _update(double x, double width) {
    final frac = (x / width).clamp(0.0, 1.0);
    final v = (frac * 20).round() / 2;
    onChanged(v);
  }
}

class _DonePage extends StatelessWidget {
  final int count;
  const _DonePage({required this.count});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.tokens.accentSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.tokens.accent, width: 2),
                  ),
                  child: Icon(Icons.check, size: 32, color: context.tokens.accent),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.rate_done_header,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.tokens.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    context.l10n.rate_done_thanks_body(count),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.tokens.inkSub,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  child: PrimaryButton(
                    label: context.l10n.rate_done_view_leaderboard,
                    variant: BtnVariant.primary,
                    size: BtnSize.lg,
                    full: true,
                    onPressed: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
