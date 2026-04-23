import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class OverviewPanel extends StatelessWidget {
  final Event event;
  const OverviewPanel({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final body = event.sub?.isNotEmpty == true
        ? '${event.sub} — ${event.name}。'
        : '${event.name}。';
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.tokens.elev1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: TextStyle(fontSize: 14, color: context.tokens.ink, height: 1.6),
          ),
          const SizedBox(height: 16),
          Label(context.l10n.event_overview_rules),
          const SizedBox(height: 10),
          for (final r in [
            context.l10n.event_overview_rule_format,
            context.l10n.event_overview_rule_halves,
            context.l10n.event_overview_rule_subs,
            context.l10n.event_overview_rule_cards,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.tokens.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r,
                    style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Label(context.l10n.event_overview_organizer),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.tokens.elev3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.city ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.ink,
                      ),
                    ),
                    Label(context.l10n.event_overview_organizer_label),
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
