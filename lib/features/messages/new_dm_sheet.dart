// new_dm_sheet.dart — bottom sheet to start a new DM by @handle lookup
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

/// Shows a modal bottom sheet that lets the user type a `@handle` and opens
/// (or creates) a DM conversation with that user.
Future<void> showNewDmSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _NewDmSheetBody(),
    ),
  );
}

class _NewDmSheetBody extends ConsumerStatefulWidget {
  const _NewDmSheetBody();

  @override
  ConsumerState<_NewDmSheetBody> createState() => _NewDmSheetBodyState();
}

class _NewDmSheetBodyState extends ConsumerState<_NewDmSheetBody> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final l = context.l10n;
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _err = l.messages_new_dm_hint);
      return;
    }

    final h = raw.replaceFirst(RegExp(r'^@+'), '').toLowerCase();

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final profile = await ref.read(profilesRepoProvider).fetchByHandle(h);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _busy = false;
          _err = l.messages_new_dm_not_found;
        });
        return;
      }

      // Guard against self-DM. currentUserId reads from a live Supabase
      // session; wrap in try/catch so widget tests don't blow up.
      // Note: in tests Supabase is uninitialized so this throws an
      // AssertionError (not a StateError), hence the broad catch.
      String? myId;
      try {
        myId = currentUserId;
      } catch (_) {
        myId = null;
      }
      if (profile.id == myId) {
        setState(() {
          _busy = false;
          _err = l.messages_new_dm_cant_self;
        });
        return;
      }

      final convId =
          await ref.read(messagesRepoProvider).ensureDmWith(profile.id);
      if (!mounted) return;

      final router = GoRouter.of(context);
      ref.invalidate(conversationsProvider);
      Navigator.of(context).pop();
      router.push('/chat/$convId');
    } catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() => _busy = false);
      showToast(context, '${l.messages_new_failed}: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              // Title
              Text(
                l.messages_new_dm,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 6),
              // Hint line
              Text(
                l.messages_new_dm_hint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.tokens.inkSub,
                ),
              ),
              const SizedBox(height: 16),
              // Handle input
              TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                style: TextStyle(color: context.tokens.ink),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.alternate_email,
                    color: context.tokens.inkSub,
                  ),
                  hintText: 'handle',
                  hintStyle: TextStyle(color: context.tokens.inkDim),
                ),
              ),
              // Inline error
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(
                  _err!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.danger,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Submit button
              PrimaryButton(
                label: l.messages_new_dm,
                full: true,
                disabled: _busy,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
