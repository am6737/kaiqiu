import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/feed.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

class EventFeedCard extends StatelessWidget {
  final FeedEvent item;
  const EventFeedCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final progress = item.teamsMax > 0 ? item.teamsRegistered / item.teamsMax : 0.0;
    return GestureDetector(
      onTap: () => context.push('/event/${item.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.elev1, borderRadius: BorderRadius.circular(t.r3)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(l.home_tab_events, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: t.accent)),
            ),
            const SizedBox(width: 6),
            Text(item.displayTime, style: TextStyle(fontSize: 10, color: t.inkMute)),
          ]),
          const SizedBox(height: 8),
          Text(item.eventName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 3),
          Text('${item.teamsRegistered}/${item.teamsMax} ${l.home_event_registered_label} · ${item.startIn}',
              style: TextStyle(fontSize: 11, color: t.inkDim)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: progress, backgroundColor: t.elev2,
                  valueColor: AlwaysStoppedAnimation(t.accent), minHeight: 4),
            )),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(8)),
              child: Text(l.home_event_register_now,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}
