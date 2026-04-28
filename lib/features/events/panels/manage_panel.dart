import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../utils/toast.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';
import '../widgets/bottom_cta.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ManagePanel — top-level organizer panel
// ─────────────────────────────────────────────────────────────────────────────

class ManagePanel extends ConsumerWidget {
  final Event event;
  const ManagePanel({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(event: event),
          const SizedBox(height: 16),
          _ReviewSection(event: event),
          const SizedBox(height: 16),
          _SettingsSection(event: event),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusCard — current status + next-step action
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends ConsumerWidget {
  final Event event;
  const _StatusCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.manage_status_title),
          const SizedBox(height: 12),
          _buildStatusContent(context, ref, l),
        ],
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context, WidgetRef ref, AppL10n l) {
    switch (event.status) {
      case EventStatus.registering:
        return _buildActionRow(
          context,
          statusText: _statusLabel(context, event.status),
          button: PrimaryButton(
            label: l.event_close_registration,
            variant: BtnVariant.secondary,
            size: BtnSize.sm,
            onPressed: () => _closeRegistration(context, ref),
          ),
        );
      case EventStatus.scheduling:
        return _buildActionRow(
          context,
          statusText: _statusLabel(context, event.status),
          button: PrimaryButton(
            label: l.schedule_generate,
            variant: BtnVariant.primary,
            size: BtnSize.sm,
            onPressed: () => context.push('/event/${event.id}/schedule'),
          ),
        );
      case EventStatus.ongoing:
        return _buildActionRow(
          context,
          statusText: _statusLabel(context, event.status),
          button: PrimaryButton(
            label: l.event_complete,
            variant: BtnVariant.warn,
            size: BtnSize.sm,
            onPressed: () => _completeEvent(context, ref),
          ),
        );
      case EventStatus.completed:
        return _buildTerminalState(
          context,
          icon: Icons.check_circle_outline,
          label: l.manage_status_completed_label,
          color: context.tokens.accent,
        );
      case EventStatus.cancelled:
        return _buildTerminalState(
          context,
          icon: Icons.cancel_outlined,
          label: l.manage_status_cancelled_label,
          color: context.tokens.inkDim,
        );
      case EventStatus.draft:
        return _buildActionRow(
          context,
          statusText: _statusLabel(context, event.status),
          button: null,
        );
    }
  }

  Widget _buildActionRow(
    BuildContext context, {
    required String statusText,
    required Widget? button,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.tokens.ink,
            ),
          ),
        ),
        ?button,
      ],
    );
  }

  Widget _buildTerminalState(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _statusLabel(BuildContext context, EventStatus status) {
    final l = context.l10n;
    return switch (status) {
      EventStatus.draft => l.event_status_draft,
      EventStatus.registering => l.event_status_registering,
      EventStatus.scheduling => l.event_status_scheduling,
      EventStatus.ongoing => l.event_status_ongoing,
      EventStatus.completed => l.manage_status_completed_label,
      EventStatus.cancelled => l.manage_status_cancelled_label,
    };
  }

  Future<void> _closeRegistration(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_close_registration),
        content: Text(l.event_close_registration_confirm),
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
    try {
      await ref
          .read(eventsRepoProvider)
          .updateEventStatus(event.id, EventStatus.scheduling);
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(myHostedEventsProvider);
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _completeEvent(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_complete),
        content: Text(l.event_complete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.common_confirm,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(eventsRepoProvider)
          .updateEventStatus(event.id, EventStatus.completed);
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(myHostedEventsProvider);
      if (context.mounted) showToast(context, l.event_complete_success, success: true);
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReviewSection — pending team + individual review
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewSection extends ConsumerWidget {
  final Event event;
  const _ReviewSection({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final teamsAsync = ref.watch(eventTeamsProvider(event.id));

    return teamsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 13)),
      ),
      data: (teams) {
        final pending = teams.where((t) => t.status == 'pending').toList();
        final approved = teams.where((t) => t.status == 'approved').length;
        final rejected = teams.where((t) => t.status == 'rejected').length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.elev2,
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(context.tokens.r2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(l.manage_review_title),
              const SizedBox(height: 8),
              Text(
                l.manage_review_stats(pending.length, approved, rejected),
                style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
              ),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final team in pending)
                  _PendingTeamTile(team: team, eventId: event.id),
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  l.event_teams_empty,
                  style: TextStyle(fontSize: 13, color: context.tokens.inkDim),
                ),
              ],
              if (event.registrationMode == 'team_and_individual') ...[
                const SizedBox(height: 16),
                _IndividualReviewList(eventId: event.id, approvedTeams: teams.where((t) => t.status == 'approved').toList()),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PendingTeamTile — approve / reject a team
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTeamTile extends ConsumerWidget {
  final TeamRow team;
  final String eventId;
  const _PendingTeamTile({required this.team, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + info row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: context.tokens.elev3,
                backgroundImage: team.captainAvatar != null
                    ? NetworkImage(team.captainAvatar!)
                    : null,
                child: team.captainAvatar == null
                    ? Text(
                        team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 14,
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
                        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Contact info
          if (team.contact != null || team.phone != null) ...[
            const SizedBox(height: 6),
            Text(
              [if (team.contact != null) team.contact!, if (team.phone != null) team.phone!].join(' · '),
              style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
            ),
          ],
          const SizedBox(height: 10),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _approve(context, ref),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.tokens.accent,
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Text(
                      l.event_teams_approve,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.accentInk,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _reject(context, ref),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: context.tokens.danger),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Text(
                      l.event_teams_reject,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.danger,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(eventsRepoProvider).updateTeamStatus(team.id, 'approved');
      ref.invalidate(eventTeamsProvider(eventId));
      ref.invalidate(eventTeamsCountProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
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
            child: Text(
              l.common_confirm,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(eventsRepoProvider).updateTeamStatus(team.id, 'rejected');
      ref.invalidate(eventTeamsProvider(eventId));
      ref.invalidate(eventTeamsCountProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IndividualReviewList — review individual registrations
// ─────────────────────────────────────────────────────────────────────────────

class _IndividualReviewList extends ConsumerWidget {
  final String eventId;
  final List<TeamRow> approvedTeams;
  const _IndividualReviewList({required this.eventId, required this.approvedTeams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(individualRegistrationsProvider(eventId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(l.individual_registrations_title),
        const SizedBox(height: 8),
        async.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: context.tokens.accent),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 13)),
          data: (regs) {
            final pending = regs.where((r) => r.status == 'pending').toList();
            if (pending.isEmpty) {
              return Text(
                l.individual_registrations_empty,
                style: TextStyle(fontSize: 13, color: context.tokens.inkDim),
              );
            }
            return Column(
              children: [
                for (final reg in pending)
                  _IndividualTile(reg: reg, eventId: eventId, approvedTeams: approvedTeams),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _IndividualTile — single individual registration row
// ─────────────────────────────────────────────────────────────────────────────

class _IndividualTile extends ConsumerWidget {
  final IndividualRegistration reg;
  final String eventId;
  final List<TeamRow> approvedTeams;
  const _IndividualTile({required this.reg, required this.eventId, required this.approvedTeams});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final posLabel = _positionLabel(l, reg.position);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
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
                child: Text(
                  reg.name.isNotEmpty ? reg.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.inkSub,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reg.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.ink,
                      ),
                    ),
                    if (posLabel != null)
                      Text(
                        posLabel,
                        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (reg.phone != null) ...[
            const SizedBox(height: 4),
            Text(reg.phone!, style: TextStyle(fontSize: 11, color: context.tokens.inkDim)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _assignToTeam(context, ref),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.tokens.accent,
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Text(
                      l.individual_assign_to_team,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.accentInk,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _reject(context, ref),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: context.tokens.danger),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Text(
                      l.individual_reject,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.danger,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _positionLabel(dynamic l, String? position) {
    if (position == null) return null;
    return switch (position) {
      'forward' => l.position_forward,
      'midfielder' => l.position_midfielder,
      'defender' => l.position_defender,
      'goalkeeper' => l.position_goalkeeper,
      _ => position,
    };
  }

  Future<void> _assignToTeam(BuildContext context, WidgetRef ref) async {
    if (approvedTeams.isEmpty) {
      showToast(context, context.l10n.event_teams_empty, error: true);
      return;
    }
    final selectedTeam = await showModalBottomSheet<TeamRow>(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.individual_assign_to_team,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.tokens.ink,
              ),
            ),
            const SizedBox(height: 12),
            for (final team in approvedTeams)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, team),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: context.tokens.elev3,
                        backgroundImage: team.captainAvatar != null
                            ? NetworkImage(team.captainAvatar!)
                            : null,
                        child: team.captainAvatar == null
                            ? Text(
                                team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 11, color: context.tokens.inkSub),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          team.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: context.tokens.inkMute),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (selectedTeam == null || !context.mounted) return;
    try {
      await ref.read(eventsRepoProvider).assignIndividualToTeam(
        reg.id,
        selectedTeam.id,
        reg.userId,
      );
      ref.invalidate(individualRegistrationsProvider(eventId));
      ref.invalidate(eventTeamsProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
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
            child: Text(
              l.common_confirm,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(eventsRepoProvider).rejectIndividualRegistration(reg.id);
      ref.invalidate(individualRegistrationsProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsSection — event management action links
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSection extends ConsumerWidget {
  final Event event;
  const _SettingsSection({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canCancel = event.status == EventStatus.draft ||
        event.status == EventStatus.registering ||
        event.status == EventStatus.scheduling;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.manage_settings_title),
          const SizedBox(height: 12),
          _SettingRow(
            icon: Icons.edit_outlined,
            label: l.event_edit,
            onTap: () => context.push('/event/${event.id}/edit'),
          ),
          _SettingRow(
            icon: Icons.group_add_outlined,
            label: l.manage_register_on_behalf,
            onTap: () => BottomCta(event: event).showRegisterSheet(context, ref),
          ),
          _SettingRow(
            icon: Icons.cancel_outlined,
            label: l.event_cancel,
            color: canCancel ? context.tokens.danger : context.tokens.inkMute,
            onTap: canCancel ? () => _cancelEvent(context, ref) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _cancelEvent(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_cancel),
        content: Text(l.event_cancel_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.common_confirm,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(eventsRepoProvider).cancelEvent(event.id);
      ref.invalidate(eventDetailProvider(event.id));
      ref.invalidate(myHostedEventsProvider);
      if (context.mounted) {
        showToast(context, l.event_cancel_success, success: true);
        context.go('/events');
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingRow — list-style tappable row
// ─────────────────────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.tokens.ink;
    final isDisabled = onTap == null;

    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.tokens.line, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: effectiveColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: context.tokens.inkMute),
            ],
          ),
        ),
      ),
    );
  }
}
