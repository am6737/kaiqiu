// my_teams_screen.dart — 我的队伍（UserTeamsRepository + LocalStore fallback）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../repositories/user_teams_repository.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../utils/validators.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class MyTeamsScreen extends ConsumerWidget {
  const MyTeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final teamsAsync = ref.watch(myTeamsProvider);
    final teammates = ref.watch(teammatesProvider);

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.me_teams_title,
              onBack: () => context.pop(),
              actions: [
                GestureDetector(
                  onTap: () => _showCreateSheet(context, ref),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add, color: T.live),
                  ),
                ),
              ],
            ),
            ...teamsAsync.when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: EmptyState(
                    icon: Icons.shield_outlined,
                    title: l.empty_no_teams,
                    subtitle: l.empty_no_teams_sub,
                    action: PrimaryButton(
                      label: l.me_teams_create,
                      variant: BtnVariant.primary,
                      size: BtnSize.md,
                      onPressed: () => _showCreateSheet(context, ref),
                    ),
                  ),
                ),
              ],
              data: (teams) => [
                if (teams.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: EmptyState(
                      icon: Icons.shield_outlined,
                      title: l.empty_no_teams,
                      subtitle: l.empty_no_teams_sub,
                      action: PrimaryButton(
                        label: l.me_teams_create,
                        variant: BtnVariant.primary,
                        size: BtnSize.md,
                        onPressed: () => _showCreateSheet(context, ref),
                      ),
                    ),
                  ),
                for (final t in teams)
                  _TeamCard(
                    team: t,
                    onRemove: () async {
                      final ok = await _confirm(
                        context,
                        l.me_teams_remove_confirm,
                      );
                      if (ok) {
                        await ref.read(userTeamsRepoProvider).delete(t.id);
                        ref.invalidate(myTeamsProvider);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(title: context.l10n.archive_teammates_title),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(T.r3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final tm in teammates)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Avatar(tm.name, size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tm.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: T.ink,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Label(
                                    context.l10n.archive_teammates_matches(
                                      tm.matches,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final nameC = TextEditingController();
    final cityC = TextEditingController(text: LocalStore.city);
    final subC = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: T.inkMute,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.me_teams_create,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: T.ink,
                  ),
                ),
                const SizedBox(height: 16),
                _Field(label: l.me_teams_create_name, controller: nameC),
                _Field(label: l.me_teams_create_city, controller: cityC),
                _Field(
                  label: l.me_teams_create_sub,
                  controller: subC,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: l.me_teams_create_submit,
                  variant: BtnVariant.primary,
                  size: BtnSize.lg,
                  full: true,
                  onPressed: () async {
                    final err = validateRequired(nameC.text);
                    if (err != null) {
                      showToast(ctx, l.error_required_field, error: true);
                      return;
                    }
                    await ref
                        .read(userTeamsRepoProvider)
                        .create(
                          name: nameC.text.trim(),
                          city: cityC.text.trim(),
                          sub: subC.text.trim(),
                        );
                    ref.invalidate(myTeamsProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirm(BuildContext context, String msg) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.tokens.elev2,
            content: Text(msg, style: const TextStyle(color: T.ink)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  l.common_cancel,
                  style: const TextStyle(color: T.inkSub),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  l.common_confirm,
                  style: const TextStyle(color: T.danger),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _TeamCard extends StatelessWidget {
  final UserTeam team;
  final VoidCallback onRemove;
  const _TeamCard({required this.team, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sub = team.sub ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(T.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.liveDim,
                  border: Border.all(color: const Color(0x6600FF85)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: T.live,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: T.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Label(team.city ?? ''),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    l.me_teams_remove,
                    style: const TextStyle(fontSize: 12, color: T.danger),
                  ),
                ),
              ),
            ],
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12,
                color: T.inkSub,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: T.ink, fontSize: 14),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
