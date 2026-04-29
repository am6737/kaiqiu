import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/typography.dart';

class TeamsPanel extends ConsumerWidget {
  final String eventId;
  final int? teamsMax;

  const TeamsPanel({
    super.key,
    required this.eventId,
    this.teamsMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventTeamsProvider(eventId));
    final myTeamId = ref.watch(userTeamIdProvider(eventId)).valueOrNull;
    return async.when(
      data: (teams) => _buildList(context, ref, teams, myTeamId),
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.tokens.accent)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<TeamRow> teams, String? myTeamId) {
    final l = context.l10n;
    final approved = teams.where((t) => t.status != 'rejected').length;
    final max = teamsMax ?? 0;

    if (teams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.groups_outlined, size: 40, color: context.tokens.inkDim),
              const SizedBox(height: 8),
              Text(
                l.event_teams_empty,
                style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<TeamRow>.from(teams)
      ..sort((a, b) {
        if (a.id == myTeamId) return -1;
        if (b.id == myTeamId) return 1;
        const order = {'pending': 0, 'approved': 1, 'rejected': 2};
        final cmp = (order[a.status] ?? 1).compareTo(order[b.status] ?? 1);
        if (cmp != 0) return cmp;
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.event_teams_summary(approved, max)),
          const SizedBox(height: 12),
          for (final team in sorted) _TeamTile(
            team: team,
            eventId: eventId,
            isMine: team.id == myTeamId,
          ),
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  final TeamRow team;
  final String eventId;
  final bool isMine;

  const _TeamTile({
    required this.team,
    required this.eventId,
    this.isMine = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isRejected = team.status == 'rejected';
    return GestureDetector(
      onTap: () => context.push('/event/$eventId/team/${team.id}'),
      child: Opacity(
        opacity: isRejected ? 0.5 : 1.0,
        child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(
            color: isMine ? context.tokens.accent : context.tokens.line,
          ),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: context.tokens.elev3,
              backgroundImage: team.captainAvatar != null
                  ? NetworkImage(team.captainAvatar!)
                  : null,
              child: team.captainAvatar == null
                  ? Text(
                      team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.inkSub,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          team.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: context.tokens.accentSubtle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l.event_teams_my_team,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (team.captainName != null)
                    Text(
                      team.captainName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.inkSub,
                      ),
                    ),
                ],
              ),
            ),
            _StatusBadge(status: team.status),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, bg, fg) = switch (status) {
      'approved' => (l.event_teams_approved, context.tokens.accentSubtle, context.tokens.accent),
      'rejected' => (l.event_teams_rejected, context.tokens.elev3, context.tokens.inkDim),
      _ => (l.event_teams_pending, context.tokens.warnSubtle, context.tokens.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.tokens.r1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
