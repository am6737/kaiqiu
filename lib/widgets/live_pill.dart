// live_pill.dart — pulsing LIVE pill (neon green bg + blinking dot)
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class LivePill extends StatefulWidget {
  final double size;
  const LivePill({super.key, this.size = 9});

  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: context.tokens.accent,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.3, end: 1).animate(_ctrl),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: context.tokens.accentInk,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontFamily: context.tokens.fontMono,
              fontFamilyFallback: context.tokens.monoFallbacks,
              fontSize: widget.size,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.tokens.accentInk,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status dot — open / almost / full / live.
class StatusDot extends StatelessWidget {
  final String state;
  final double size;
  const StatusDot({super.key, this.state = 'open', this.size = 6});

  @override
  Widget build(BuildContext context) {
    final c = switch (state) {
      'almost' => context.tokens.warn,
      'full' => context.tokens.inkMute,
      _ => context.tokens.accent, // open / live
    };
    final glow = state == 'open' || state == 'live';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: glow
            ? [BoxShadow(color: c, blurRadius: 6, spreadRadius: 0.5)]
            : null,
      ),
    );
  }
}
