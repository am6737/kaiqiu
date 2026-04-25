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
    if (registered) {
      disabledReason = l.event_already_registered;
    } else if (!isRegistering) {
      disabledReason = l.event_registration_closed;
    } else if (isFull) {
      disabledReason = l.event_registration_full;
    } else if (deadlinePassed) {
      disabledReason = l.event_registration_deadline_passed;
    }

    final rightButton = _buildRightButton(context, ref, l,
      isCreator: isCreator,
      isRegistering: isRegistering,
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
    final teamC = TextEditingController();
    final contactC = TextEditingController();
    final phoneC = TextEditingController();
    final sloganC = TextEditingController();
    final membersNotifier = ValueNotifier<List<({String userId, String name, String? avatarUrl, int? jersey})>>([]);
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
              RegField(label: l.event_register_contact, controller: contactC),
              RegField(
                label: l.event_register_phone,
                controller: phoneC,
                keyboardType: TextInputType.phone,
              ),
              RegField(
                label: l.event_register_slogan,
                controller: sloganC,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: membersNotifier,
                builder: (ctx, members, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.event_register_members,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showUserSearchDialog(ctx, membersNotifier),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.tokens.accentSubtle,
                              borderRadius: BorderRadius.circular(context.tokens.r1),
                            ),
                            child: Text(
                              l.event_register_add_member,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.tokens.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < members.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: context.tokens.elev3,
                              backgroundImage: members[i].avatarUrl != null
                                  ? NetworkImage(members[i].avatarUrl!)
                                  : null,
                              child: members[i].avatarUrl == null
                                  ? Icon(Icons.person, size: 14, color: context.tokens.inkDim)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                members[i].name,
                                style: TextStyle(fontSize: 13, color: context.tokens.ink),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 12, color: context.tokens.ink),
                                decoration: InputDecoration(
                                  hintText: l.event_register_jersey,
                                  hintStyle: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: context.tokens.line),
                                  ),
                                ),
                                onChanged: (v) {
                                  final list = List.of(membersNotifier.value);
                                  final old = list[i];
                                  list[i] = (userId: old.userId, name: old.name, avatarUrl: old.avatarUrl, jersey: int.tryParse(v));
                                  membersNotifier.value = list;
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                final list = List.of(membersNotifier.value);
                                list.removeAt(i);
                                membersNotifier.value = list;
                              },
                              child: Icon(Icons.close, size: 16, color: context.tokens.inkDim),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
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
                  if (contactC.text.trim().isEmpty) {
                    showToast(ctx, l.validation_contact_required, error: true);
                    return;
                  }
                  if (phoneC.text.trim().isEmpty) {
                    showToast(ctx, l.validation_phone_required, error: true);
                    return;
                  }
                  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(phoneC.text.trim())) {
                    showToast(ctx, l.validation_phone_format, error: true);
                    return;
                  }
                  try {
                    // Write to teams table
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': contactC.text.trim(),
                      'phone': phoneC.text.trim(),
                      'slogan': sloganC.text.trim().isEmpty ? null : sloganC.text.trim(),
                      'status': event.reviewMode == 'manual'
                          ? 'pending'
                          : 'approved',
                    });
                    // Fetch the newly created team to get its ID
                    final newTeams = await ref.read(eventsRepoProvider).listTeams(event.id);
                    final newTeam = newTeams.where((t) => t.captainId == currentUserId).lastOrNull;
                    if (newTeam != null) {
                      // Insert captain as member
                      if (currentUserId != null) {
                        await ref.read(eventsRepoProvider).addTeamMember(
                          newTeam.id, currentUserId!, null,
                        );
                      }
                      // Insert selected members
                      for (final m in membersNotifier.value) {
                        await ref.read(eventsRepoProvider).addTeamMember(
                          newTeam.id, m.userId, m.jersey,
                        );
                      }
                    }
                    // Also create conversation for communication
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

Future<void> _showUserSearchDialog(
  BuildContext context,
  ValueNotifier<List<({String userId, String name, String? avatarUrl, int? jersey})>> membersNotifier,
) async {
  final searchC = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.tokens.elev1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctx.l10n.event_register_search_user,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ctx.tokens.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchC,
              style: TextStyle(fontSize: 13, color: ctx.tokens.ink),
              decoration: InputDecoration(
                hintText: ctx.l10n.common_search,
                hintStyle: TextStyle(color: ctx.tokens.inkDim),
                prefixIcon: Icon(Icons.search, size: 18, color: ctx.tokens.inkDim),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ctx.tokens.line),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: _UserSearchResults(
                searchController: searchC,
                onSelect: (userId, name, avatarUrl) {
                  final existing = membersNotifier.value.any((m) => m.userId == userId);
                  if (!existing) {
                    membersNotifier.value = [
                      ...membersNotifier.value,
                      (userId: userId, name: name, avatarUrl: avatarUrl, jersey: null),
                    ];
                  }
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _UserSearchResults extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final void Function(String userId, String name, String? avatarUrl) onSelect;

  const _UserSearchResults({
    required this.searchController,
    required this.onSelect,
  });

  @override
  ConsumerState<_UserSearchResults> createState() => _UserSearchResultsState();
}

class _UserSearchResultsState extends ConsumerState<_UserSearchResults> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final q = widget.searchController.text.trim();
    if (q != _query) setState(() => _query = q);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onQueryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_query.length < 2) {
      return Center(
        child: Text(
          '...',
          style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
        ),
      );
    }
    final async = ref.watch(profileSearchProvider(_query));
    return async.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return Center(
            child: Text(
              context.l10n.empty_no_search,
              style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: profiles.length,
          itemBuilder: (ctx, i) {
            final p = profiles[i];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: context.tokens.elev3,
                backgroundImage: p['avatar_url'] != null
                    ? NetworkImage(p['avatar_url'] as String)
                    : null,
                child: p['avatar_url'] == null
                    ? Icon(Icons.person, size: 16, color: context.tokens.inkDim)
                    : null,
              ),
              title: Text(
                p['name'] as String? ?? '—',
                style: TextStyle(fontSize: 13, color: context.tokens.ink),
              ),
              onTap: () => widget.onSelect(
                p['id'] as String,
                p['name'] as String? ?? '—',
                p['avatar_url'] as String?,
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.tokens.accent,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 12)),
      ),
    );
  }
}
