import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/live_match.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class LiveMatchCard extends StatelessWidget {
  final LiveMatch match;
  const LiveMatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    return GestureDetector(
      onTap: () => context.push('/worldcup/live/${match.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.accent.withValues(alpha: 0.25), t.danger.withValues(alpha: 0.15)],
          ),
          borderRadius: BorderRadius.circular(t.r3),
          border: Border.all(color: t.accent.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          // LIVE badge row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: t.danger.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _PulseDot(color: t.danger),
                const SizedBox(width: 4),
                Text('LIVE · ${match.minute}\'',
                    style: TextStyle(color: t.danger, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Spacer(),
            Text(l.home_viewers_count(match.viewersDisplay),
                style: TextStyle(fontSize: 10, color: t.inkDim)),
          ]),
          const SizedBox(height: 12),
          // Score row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Expanded(child: Text(match.teamA, textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${match.scoreA} : ${match.scoreB}',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                      fontFamily: t.fontMono, fontFamilyFallback: t.monoFallbacks,
                      color: t.ink, letterSpacing: 2)),
            ),
            Expanded(child: Text(match.teamB,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.ink))),
          ]),
        ]),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
    child: Container(width: 6, height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
  );
}
