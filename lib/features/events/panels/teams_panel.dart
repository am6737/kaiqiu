import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/toast.dart';
import '../../../widgets/typography.dart';

class TeamsPanel extends ConsumerWidget {
  final String eventId;
  final bool isCreator;
  final String? reviewMode;
  final int? teamsMax;

  const TeamsPanel({
    super.key,
    required this.eventId,
    required this.isCreator,
    this.reviewMode,
    this.teamsMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventTeamsProvider(eventId));
    return async.when(
      data: (teams) => _buildList(context, ref, teams),
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

  Widget _buildList(BuildContext context, WidgetRef ref, List<TeamRow> teams) {
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
            isCreator: isCreator,
            isManual: reviewMode == 'manual',
            onApprove: () => _updateStatus(context, ref, team.id, 'approved'),
            onReject: () => _confirmReject(context, ref, team.id),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    String status,
  ) async {
    try {
      await ref.read(eventsRepoProvider).updateTeamStatus(teamId, status);
      ref.invalidate(eventTeamsProvider(eventId));
      ref.invalidate(eventTeamsCountProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _confirmReject(
    BuildContext context,
    WidgetRef ref,
    String teamId,
  ) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_teams_reject),
        content: Text(l.event_teams_reject_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _updateStatus(context, ref, teamId, 'rejected');
  }
}

class _TeamTile extends StatelessWidget {
  final TeamRow team;
  final bool isCreator;
  final bool isManual;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TeamTile({
    required this.team,
    required this.isCreator,
    required this.isManual,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isRejected = team.status == 'rejected';
    return Opacity(
      opacity: isRejected ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      Text(
                        team.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
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
            if (isCreator && (team.contact != null || team.phone != null)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 42),
                  if (team.contact != null) ...[
                    Icon(Icons.person_outline, size: 13, color: context.tokens.inkDim),
                    const SizedBox(width: 4),
                    Text(
                      team.contact!,
                      style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (team.phone != null) ...[
                    Icon(Icons.phone_outlined, size: 13, color: context.tokens.inkDim),
                    const SizedBox(width: 4),
                    Text(
                      team.phone!,
                      style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                    ),
                  ],
                ],
              ),
            ],
            if (isCreator && isManual && team.status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onReject,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.tokens.danger),
                        borderRadius: BorderRadius.circular(context.tokens.r1),
                      ),
                      child: Text(
                        l.event_teams_reject,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.danger,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.tokens.accent,
                        borderRadius: BorderRadius.circular(context.tokens.r1),
                      ),
                      child: Text(
                        l.event_teams_approve,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.accentInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
