import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../repositories/favorites_repository.dart';
import '../../../services/local_storage.dart';
import '../../../services/storage.dart';
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
    final isCreator = event.creatorId != null && event.creatorId == currentUserId;

    // Organizer has their own ManagePanel — hide entirely for creators.
    if (isCreator) return const SizedBox.shrink();

    ref.watch(localStoreProvider);
    final registered = LocalStore.isEventFavorited(event.id);
    final teamsCount = ref.watch(eventTeamsCountProvider(event.id)).valueOrNull ?? 0;
    final isFull = event.teamsMax != null && teamsCount >= event.teamsMax!;
    final deadlinePassed = event.deadline != null && DateTime.now().isAfter(event.deadline!);
    final isRegistering = event.status == EventStatus.registering;
    final isOngoing = event.status == EventStatus.ongoing;

    // ── Registering + already registered → cancel button ──────────────────
    if (isRegistering && registered) {
      return _bar(
        context,
        PrimaryButton(
          label: l.event_register_cancel,
          variant: BtnVariant.ghost,
          size: BtnSize.lg,
          full: true,
          onPressed: () => _showCancelConfirmation(context, ref),
        ),
      );
    }

    // ── Registering + not registered ──────────────────────────────────────
    if (isRegistering && !registered) {
      final canRegister = !isFull && !deadlinePassed;
      final disabledReason = isFull
          ? l.event_registration_full
          : deadlinePassed
              ? l.event_registration_deadline_passed
              : null;

      return _bar(
        context,
        PrimaryButton(
          label: disabledReason ?? l.event_cta_register,
          variant: canRegister ? BtnVariant.primary : BtnVariant.secondary,
          size: BtnSize.lg,
          full: true,
          onPressed: canRegister
              ? () {
                  if (event.registrationMode == 'team_and_individual') {
                    _showRegistrationModeChoice(context, ref);
                  } else {
                    showRegisterSheet(context, ref);
                  }
                }
              : null,
        ),
      );
    }

    // ── Ongoing + has live matches → watch live button ─────────────────────
    if (isOngoing) {
      final liveMatches =
          ref.watch(liveMatchesForEventProvider(event.id)).valueOrNull ?? [];
      if (liveMatches.isNotEmpty) {
        return _bar(
          context,
          PrimaryButton(
            variant: BtnVariant.primary,
            size: BtnSize.lg,
            full: true,
            onPressed: () => context.push('/worldcup/live/${event.id}'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tv, size: 16),
                const SizedBox(width: 6),
                Text(
                  l.event_cta_watch_live,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // All other cases — nothing to show.
    return const SizedBox.shrink();
  }

  Widget _bar(BuildContext context, Widget button) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: button,
    );
  }

  Future<void> showRegisterSheet(BuildContext context, WidgetRef ref) async {
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
    final contactC = TextEditingController(text: profile?.name ?? '');
    final phoneC = TextEditingController(text: profile?.phone ?? '');
    String? logoUrl;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: context.tokens.inkMute,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l.event_register_form_title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink),
                ),
                const SizedBox(height: 16),
                RegField(label: l.event_register_team_name, controller: teamC),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(l.event_register_logo),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final url = await StorageService().pickCropCompressAndUpload(
                            bucket: 'avatars',
                            pathPrefix: 'teams',
                          );
                          if (url != null) setSheetState(() => logoUrl = url);
                        },
                        child: Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: context.tokens.elev2,
                            border: Border.all(color: context.tokens.line),
                            borderRadius: BorderRadius.circular(12),
                            image: logoUrl != null
                                ? DecorationImage(image: NetworkImage(logoUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: logoUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, size: 20, color: context.tokens.inkDim),
                                    const SizedBox(height: 2),
                                    Text(l.event_register_logo_hint, style: TextStyle(fontSize: 9, color: context.tokens.inkDim), textAlign: TextAlign.center),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Label(l.event_register_contact_label),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: RegField(label: l.event_register_contact, controller: contactC)),
                    const SizedBox(width: 10),
                    Expanded(child: RegField(label: l.event_register_phone, controller: phoneC, keyboardType: TextInputType.phone)),
                  ],
                ),
                const SizedBox(height: 4),
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
                        'contact': contactC.text.trim(),
                        'phone': phoneC.text.trim(),
                        if (logoUrl != null) 'logo_url': logoUrl,
                        'status': event.reviewMode == 'manual' ? 'pending' : 'approved',
                      });
                      final newTeams = await ref.read(eventsRepoProvider).listTeams(event.id);
                      final newTeam = newTeams.where((t) => t.captainId == currentUserId).lastOrNull;
                      if (newTeam != null && currentUserId != null) {
                        await ref.read(eventsRepoProvider).addTeamMember(
                          newTeam.id, currentUserId!, null,
                        );
                      }
                      try {
                        await ref.read(messagesRepoProvider).createConversation(
                          title: 'event:${event.id}:reg:${teamC.text.trim()}',
                          kind: 'team',
                        );
                      } catch (_) {}
                      await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.event, event.id);
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
                      final teams = await ref.read(eventsRepoProvider).listTeams(event.id);
                      final myTeam = teams.where((t) => t.captainId == currentUserId).lastOrNull;
                      if (myTeam != null && context.mounted) {
                        context.push('/event/${event.id}/team/${myTeam.id}');
                      }
                    }
                  },
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(l.event_register_post_hint, style: TextStyle(fontSize: 11, color: context.tokens.inkDim), textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showIndividualRegisterSheet(BuildContext context, WidgetRef ref) async {
    final uid = currentUserId;
    if (uid != null) {
      final alreadyRegistered = await ref.read(eventsRepoProvider).isUserIndividuallyRegistered(event.id, uid);
      if (alreadyRegistered && context.mounted) {
        showToast(context, context.l10n.event_already_registered, error: true);
        return;
      }
    }
    if (!context.mounted) return;
    final l = context.l10n;
    final profile = ref.read(myProfileProvider).valueOrNull;
    final nameC = TextEditingController(text: profile?.name ?? '');
    final phoneC = TextEditingController(text: profile?.phone ?? '');
    String? selectedPosition;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.tokens.inkMute, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text(l.event_register_individual_title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: RegField(label: l.event_register_contact, controller: nameC)),
                    const SizedBox(width: 10),
                    Expanded(child: RegField(label: l.event_register_phone, controller: phoneC, keyboardType: TextInputType.phone)),
                  ],
                ),
                Label(l.event_register_position),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final pos in [
                      ('forward', l.position_forward),
                      ('midfielder', l.position_midfielder),
                      ('defender', l.position_defender),
                      ('goalkeeper', l.position_goalkeeper),
                    ])
                      GestureDetector(
                        onTap: () => setSheetState(() => selectedPosition = pos.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selectedPosition == pos.$1 ? context.tokens.elev3 : context.tokens.elev2,
                            border: Border.all(color: selectedPosition == pos.$1 ? context.tokens.accent : context.tokens.line),
                            borderRadius: BorderRadius.circular(context.tokens.r2),
                          ),
                          child: Text(pos.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selectedPosition == pos.$1 ? context.tokens.accent : context.tokens.ink)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: l.event_register_submit,
                  variant: BtnVariant.primary,
                  size: BtnSize.lg,
                  full: true,
                  onPressed: () async {
                    if (nameC.text.trim().isEmpty || selectedPosition == null) {
                      showToast(ctx, l.error_required_field, error: true);
                      return;
                    }
                    try {
                      await ref.read(eventsRepoProvider).insertIndividualRegistration({
                        'event_id': event.id,
                        'user_id': currentUserId,
                        'name': nameC.text.trim(),
                        'phone': phoneC.text.trim(),
                        'position': selectedPosition,
                      });
                      await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.event, event.id);
                      ref.invalidate(isUserIndividuallyRegisteredProvider(event.id));
                      ref.invalidate(individualRegistrationsProvider(event.id));
                    } catch (e) {
                      if (ctx.mounted) showToast(ctx, '$e', error: true);
                      return;
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (context.mounted) showToast(context, l.event_register_success, success: true);
                  },
                ),
                const SizedBox(height: 10),
                Center(child: Text(l.event_register_individual_hint, style: TextStyle(fontSize: 11, color: context.tokens.inkDim), textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegistrationModeChoice(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.tokens.inkMute, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            PrimaryButton(
              label: l.event_register_form_title,
              variant: BtnVariant.primary,
              size: BtnSize.lg,
              full: true,
              onPressed: () { Navigator.pop(ctx); showRegisterSheet(context, ref); },
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: l.event_register_individual_title,
              variant: BtnVariant.secondary,
              size: BtnSize.lg,
              full: true,
              onPressed: () { Navigator.pop(ctx); showIndividualRegisterSheet(context, ref); },
            ),
          ],
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