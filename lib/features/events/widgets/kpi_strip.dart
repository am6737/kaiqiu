import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class KpiStrip extends ConsumerWidget {
  final String eventId;
  final int? prizeCents;
  final int? teamsMax;
  const KpiStrip({super.key, required this.eventId, this.prizeCents, this.teamsMax});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(eventMatchesProvider(eventId));
    final matchesStr = matchesAsync.maybeWhen(
      data: (list) => '${list.where((m) => m.status == MatchStatus.finished).length}/${list.length}',
      orElse: () => '-',
    );
    final l = context.l10n;
    final prizeStr = prizeCents != null
        ? l.create_event_preview_prize_wan(
            (prizeCents! / 1000000).toStringAsFixed(1),
          )
        : '-';
    final teamsRegistered = ref.watch(eventTeamsCountProvider(eventId)).valueOrNull ?? 0;
    final items = [
      (l.event_kpi_teams, teamsMax != null ? '$teamsRegistered/$teamsMax' : '$teamsRegistered'),
      (l.event_kpi_matches, matchesStr),
      (l.event_kpi_prize, prizeStr),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: i == 0 ? null : const EdgeInsets.only(left: 10),
                decoration: i == 0
                    ? null
                    : BoxDecoration(
                        border: Border(
                          left: BorderSide(color: context.tokens.line, width: 1),
                        ),
                      ),
                child: Column(
                  crossAxisAlignment: i == 0
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Label(items[i].$1),
                    const SizedBox(height: 3),
                    N(
                      items[i].$2,
                      size: 16,
                      weight: FontWeight.w700,
                      color: context.tokens.ink,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
