import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../repositories/favorites_repository.dart';
import '../../../services/local_storage.dart';
import '../../../services/supabase.dart';
import '../../../utils/toast.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class BottomCta extends ConsumerWidget {
  final Event event;
  const BottomCta({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final registered = LocalStore.isEventFavorited(event.id);
    final isCreator = event.creatorId != null && event.creatorId == currentUserId;
    final teamsCount = ref.watch(eventTeamsCountProvider(event.id)).valueOrNull ?? 0;
    final isFull = event.teamsMax != null && teamsCount >= event.teamsMax!;
    final deadlinePassed = event.deadline != null && DateTime.now().isAfter(event.deadline!);
    final isRegistering = event.status == EventStatus.registering;
    final isOngoing = event.status == EventStatus.ongoing;

    String? disabledReason;
    if (registered && !isRegistering) {
      disabledReason = l.event_already_registered;
    } else if (!registered && !isRegistering) {
      disabledReason = l.event_registration_closed;
    } else if (!registered && isFull) {
      disabledReason = l.event_registration_full;
    } else if (!registered && deadlinePassed) {
      disabledReason = l.event_registration_deadline_passed;
    }

    final rightButton = _buildRightButton(context, ref, l,
      isCreator: isCreator,
      isRegistering: isRegistering,
      registered: registered,
      disabledReason: disabledReason,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              variant: BtnVariant.ghost,
              size: BtnSize.lg,
              full: true,
              onPressed: isOngoing
                  ? () => context.push('/worldcup/live/${event.id}')
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tv, size: 16,
                    color: isOngoing ? context.tokens.ink : context.tokens.inkDim),
                  const SizedBox(width: 6),
                  Text(
                    l.event_cta_watch_live,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isOngoing ? context.tokens.ink : context.tokens.inkDim,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (rightButton != null) ...[
            const SizedBox(width: 10),
            Expanded(child: rightButton),
          ],
        ],
      ),
    );
  }

  Widget? _buildRightButton(
    BuildContext context,
    WidgetRef ref,
    dynamic l, {
    required bool isCreator,
    required bool isRegistering,
    required bool registered,
    required String? disabledReason,
  }) {
    if (isCreator) {
      if (event.status == EventStatus.registering) {
        return PrimaryButton(
          label: l.event_close_registration,
          full: true,
          size: BtnSize.lg,
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.event_close_registration),
                content: Text(l.event_close_registration_confirm),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.scheduling);
            ref.invalidate(eventDetailProvider(event.id));
          },
        );
      }
      if (event.status == EventStatus.scheduling) {
        return PrimaryButton(
          label: l.schedule_generate,
          full: true,
          size: BtnSize.lg,
          onPressed: () => context.push('/event/${event.id}/schedule'),
        );
      }
      if (event.status == EventStatus.ongoing) {
        return PrimaryButton(
          label: l.event_complete,
          full: true,
          size: BtnSize.lg,
          variant: BtnVariant.warn,
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.event_complete),
                content: Text(l.event_complete_confirm),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.completed);
            ref.invalidate(eventDetailProvider(event.id));
            if (context.mounted) showToast(context, l.event_complete_success, success: true);
          },
        );
      }
      return null;
    }

    final canCancel = registered && isRegistering;

    if (canCancel) {
      return PrimaryButton(
        label: l.event_register_cancel,
        variant: BtnVariant.warn,
        size: BtnSize.lg,
        full: true,
        onPressed: () => _showCancelConfirmation(context, ref),
      );
    }

    if (isRegistering) {
      return PrimaryButton(
        label: disabledReason ?? l.event_cta_register,
        variant: disabledReason != null ? BtnVariant.secondary : BtnVariant.primary,
        size: BtnSize.lg,
        full: true,
        onPressed: disabledReason != null
            ? null
            : () => showRegisterSheet(context, ref),
      );
    }

    return null;
  }

  Future<void> showRegisterSheet(BuildContext context, WidgetRef ref) async {
    // Double-check duplicate registration
    final uid = currentUserId;
    if (uid != null) {
      final alreadyRegistered = await ref.read(eventsRepoProvider).isUserRegistered(event.id, uid);
      if (alreadyRegistered && context.mounted) {
        showToast(context, context.l10n.event_already_registered, error: true);
        return;
      }
    }

    if (!context.mounted) return;
    final l = context.l10n;
    final profile = ref.read(myProfileProvider).valueOrNull;
    final teamC = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
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
                l.event_register_form_title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 16),
              RegField(label: l.event_register_team_name, controller: teamC),
              const SizedBox(height: 10),
              PrimaryButton(
                label: l.event_register_submit,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: () async {
                  if (teamC.text.trim().isEmpty) {
                    showToast(ctx, l.error_required_field, error: true);
                    return;
                  }
                  try {
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': profile?.name,
                      'phone': profile?.phone,
                      'status': event.reviewMode == 'manual'
                          ? 'pending'
                          : 'approved',
                    });
                    final newTeams = await ref.read(eventsRepoProvider).listTeams(event.id);
                    final newTeam = newTeams.where((t) => t.captainId == currentUserId).lastOrNull;
                    if (newTeam != null && currentUserId != null) {
                      await ref.read(eventsRepoProvider).addTeamMember(
                        newTeam.id, currentUserId!, null,
                      );
                    }
                    try {
                      await ref
                          .read(messagesRepoProvider)
                          .createConversation(
                            title: 'event:${event.id}:reg:${teamC.text.trim()}',
                            kind: 'team',
                          );
                    } catch (_) {}
                    await ref
                        .read(favoritesRepoProvider)
                        .toggle(FavoriteEntity.event, event.id);
                    ref.invalidate(eventTeamsCountProvider(event.id));
                    ref.invalidate(isUserRegisteredProvider(event.id));
                    ref.invalidate(eventTeamsProvider(event.id));
                  } catch (e) {
                    if (ctx.mounted) showToast(ctx, '$e', error: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    showToast(context, l.event_register_success, success: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCancelConfirmation(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_register_cancel_confirm_title),
        content: Text(l.event_register_cancel_confirm_body),
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
      final uid = currentUserId;
      if (uid == null) return;
      await ref.read(eventsRepoProvider).cancelRegistration(event.id, uid);
      await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.event, event.id);
      ref.invalidate(eventTeamsCountProvider(event.id));
      ref.invalidate(isUserRegisteredProvider(event.id));
      ref.invalidate(eventTeamsProvider(event.id));
      if (context.mounted) {
        showToast(context, l.event_register_cancel_success, success: true);
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

class RegField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const RegField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(color: context.tokens.ink, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}