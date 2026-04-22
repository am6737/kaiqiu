import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/pickup.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class PickupFeedCard extends StatelessWidget {
  final Pickup pickup;
  final double? distanceKm;
  final bool locationAvailable;
  const PickupFeedCard({
    super.key,
    required this.pickup,
    this.distanceKm,
    this.locationAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final needed = pickup.displayNeed;
    return GestureDetector(
      onTap: () => context.push('/pickup/${pickup.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pickup.displayTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
              const SizedBox(height: 3),
              Text(
                [
                  pickup.venue,
                  pickup.displayTime,
                  if (distanceKm != null)
                    distanceKm! < 1
                        ? '${(distanceKm! * 1000).round()}m'
                        : '${distanceKm!.toStringAsFixed(1)}km'
                  else
                    '距离未知',
                ].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 11, color: t.inkDim),
              ),
            ])),
            _urgencyBadge(t, l, needed),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('${pickup.total - needed}/${pickup.total}人',
                style: TextStyle(fontSize: 10, color: t.inkMute))),
            if (needed > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(8)),
                child: Text(l.home_join_cta, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              )
            else
              Text(l.home_full, style: TextStyle(fontSize: 10, color: t.inkMute)),
          ]),
        ]),
      ),
    );
  }

  Widget _urgencyBadge(AppTokens t, AppL10n l, int needed) {
    final Color bg, fg;
    final String text;
    if (needed > 0 && needed <= 2) {
      bg = t.warn.withValues(alpha: 0.15); fg = t.warn; text = l.home_need_n(needed);
    } else if (needed > 2) {
      bg = const Color(0xFF4CAF50).withValues(alpha: 0.15); fg = const Color(0xFF4CAF50); text = l.home_pickup_slots_available;
    } else {
      bg = t.inkMute.withValues(alpha: 0.15); fg = t.inkMute; text = l.home_full;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
