// lib/features/home/tabs/events_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cards/live_match_card.dart';  // LiveMatchCarousel

class EventsTab extends ConsumerWidget {
  const EventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final liveAsync = ref.watch(liveNowProvider);
    final eventsAsync = ref.watch(eventsByStatusProvider);

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(liveNowProvider);
        ref.invalidate(eventsByStatusProvider);
      },
      child: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (grouped) {
          final liveMatches = liveAsync.valueOrNull ?? [];
          final registering = grouped['registering'] ?? [];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Live section
              if (liveMatches.isNotEmpty) ...[
                _SectionHeader(
                  icon: null,
                  label: l.home_events_live,
                  color: t.danger,
                  hasPulse: true,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LiveMatchCarousel(items: liveMatches),
                ),
              ],
              // Registering section
              if (registering.isNotEmpty) ...[
                _SectionHeader(
                  icon: null,
                  label: l.home_events_registering,
                  color: t.warn,
                ),
                ...registering.map((e) => _EventStatusCard(
                      event: e,
                      tokens: t,
                      l10n: l,
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String? icon;
  final String label;
  final Color color;
  final bool hasPulse;

  const _SectionHeader({
    this.icon,
    required this.label,
    required this.color,
    this.hasPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Text(icon!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStatusCard extends StatelessWidget {
  final FeedEvent event;
  final AppTokens tokens;
  final AppL10n l10n;

  const _EventStatusCard({
    required this.event,
    required this.tokens,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final progress = event.teamsMax > 0
        ? event.teamsRegistered / event.teamsMax
        : 0.0;
    final spotsLeft = event.teamsMax - event.teamsRegistered;
    final percentText = '${(progress * 100).toInt()}%';
    final dateText = event.startsAt != null
        ? DateFormat('MM/dd HH:mm').format(event.startsAt!)
        : '';

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.elev1,
          borderRadius: BorderRadius.circular(tokens.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event name
            Text(
              event.eventName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // Start time
            if (dateText.isNotEmpty || event.startIn.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: tokens.inkDim),
                  const SizedBox(width: 4),
                  if (dateText.isNotEmpty) ...[
                    Text(
                      dateText,
                      style: TextStyle(fontSize: 12, color: tokens.inkSub),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.warnSubtle,
                      borderRadius: BorderRadius.circular(tokens.r1),
                    ),
                    child: Text(
                      event.startIn,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tokens.warn,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            // Progress bar with percentage
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: tokens.elev2,
                      valueColor: AlwaysStoppedAnimation(tokens.accent),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  percentText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: tokens.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Teams count and spots left
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 14, color: tokens.inkDim),
                const SizedBox(width: 4),
                Text(
                  '${l10n.home_events_teams} ${event.teamsRegistered}/${event.teamsMax}',
                  style: TextStyle(fontSize: 12, color: tokens.inkSub),
                ),
                const Spacer(),
                if (spotsLeft > 0)
                  Text(
                    '${l10n.home_events_spots_left} $spotsLeft',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.warn,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
