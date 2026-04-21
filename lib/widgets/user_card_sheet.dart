// user_card_sheet.dart — reusable bottom sheet showing a user profile
// with a "Start DM" action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../providers.dart';
import '../services/supabase.dart';
import '../theme/app_tokens.dart';
import '../utils/toast.dart';
import 'avatar.dart';
import 'primary_button.dart';

/// Shows a modal bottom sheet with the profile for [userId] and a
/// "Start DM" button (hidden if [userId] matches the current user).
Future<void> showUserCardSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _UserCardSheetBody(userId: userId),
  );
}

class _UserCardSheetBody extends ConsumerStatefulWidget {
  final String userId;

  const _UserCardSheetBody({required this.userId});

  @override
  ConsumerState<_UserCardSheetBody> createState() => _UserCardSheetBodyState();
}

class _UserCardSheetBodyState extends ConsumerState<_UserCardSheetBody> {
  bool _busy = false;

  Future<void> _startDm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final convId =
          await ref.read(messagesRepoProvider).ensureDmWith(widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/$convId');
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      showToast(context, '$e', error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profileAsync = ref.watch(profileByIdProvider(widget.userId));
    // currentUserId requires an initialized Supabase session; guard against
    // the case where Supabase is not yet set up (e.g. in widget tests).
    String? myId;
    try {
      myId = currentUserId;
    } catch (_) {
      myId = null;
    }
    final isSelf = myId != null && myId == widget.userId;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle bar
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
            const SizedBox(height: 20),
            profileAsync.when(
            loading: () => const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '$e',
                      style: TextStyle(color: context.tokens.danger),
                    ),
                  ),
                ],
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Text(
                    l.messages_new_dm_not_found,
                    style: TextStyle(color: context.tokens.inkSub),
                  ),
                );
              }

              // Build meta line: position · city · district (skip empties)
              final metaParts = [
                if ((profile.position ?? '').isNotEmpty) profile.position!,
                if ((profile.city ?? '').isNotEmpty) profile.city!,
                if ((profile.district ?? '').isNotEmpty) profile.district!,
              ];
              final metaLine =
                  metaParts.isNotEmpty ? metaParts.join(' · ') : null;

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Avatar(profile.name, size: 72)),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.ink,
                      ),
                    ),
                    if ((profile.handle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${profile.handle}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokens.inkSub,
                        ),
                      ),
                    ],
                    if (metaLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaLine,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.tokens.inkDim,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (!isSelf)
                      PrimaryButton(
                        label: l.messages_new_dm,
                        full: true,
                        disabled: _busy,
                        onPressed: _busy ? null : _startDm,
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l.common_close),
                    ),
                  ],
                ),
              );
            },
          ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
