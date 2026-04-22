// lib/features/home/tabs/events_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/feed.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cards/live_match_card.dart';

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
                ...liveMatches.map((m) => LiveMatchCard(match: m)),
                const SizedBox(height: 8),
              ],
              // Registering section
              if (registering.isNotEmpty) ...[
                _SectionHeader(
                  icon: '🔥',
                  label: l.home_events_registering,
                  color: t.warn,
                ),
                ...registering.map((e) => _EventStatusCard(
                      event: e,
                      tokens: t,
                      trailing: GestureDetector(
                        onTap: () => context.push('/event/${e.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: t.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l.home_events_register,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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
  final Widget? trailing;

  const _EventStatusCard({
    required this.event,
    required this.tokens,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final progress = event.teamsMax > 0
        ? event.teamsRegistered / event.teamsMax
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.elev1,
        borderRadius: BorderRadius.circular(tokens.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.teamsRegistered}/${event.teamsMax} · ${event.startIn}',
                      style: TextStyle(fontSize: 11, color: tokens.inkDim),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: tokens.elev2,
              valueColor: AlwaysStoppedAnimation(tokens.accent),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
