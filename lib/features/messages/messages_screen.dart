// messages_screen.dart — 消息列表 (real Supabase data)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../repositories/messages_repository.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(conversationsProvider);
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  Text(
                    l.messages_title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showNewSheet(context, ref),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.liveDim,
                        border: Border.all(color: const Color(0x6600FF85)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.add, size: 18, color: T.live),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                data: (list) {
                  if (list.isEmpty) {
                    return RefreshIndicator(
                      color: T.live,
                      backgroundColor: context.tokens.elev1,
                      onRefresh: () async =>
                          ref.invalidate(conversationsProvider),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [SizedBox(height: 120), _EmptyState()],
                      ),
                    );
                  }
                  // Sort: pinned first, then by time.
                  final pinned = list
                      .where((c) => LocalStore.isPinned(c.id))
                      .toList();
                  final others = list
                      .where((c) => !LocalStore.isPinned(c.id))
                      .toList();
                  final sorted = [...pinned, ...others];
                  return RefreshIndicator(
                    color: T.live,
                    backgroundColor: context.tokens.elev1,
                    onRefresh: () async =>
                        ref.invalidate(conversationsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: sorted.length,
                      itemBuilder: (_, i) => _ThreadRow(
                        thread: sorted[i],
                        isFirst: i == 0,
                        onTap: () => context.push('/chat/${sorted[i].id}'),
                        onLongPress: () =>
                            _showLongPressMenu(context, ref, sorted[i]),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: T.live,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 32,
                          color: T.warn,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${l.error_load_failed}：$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: T.inkSub),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: l.common_retry,
                          variant: BtnVariant.secondary,
                          size: BtnSize.sm,
                          onPressed: () =>
                              ref.invalidate(conversationsProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNewSheet(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 14),
            Text(
              l.messages_new_sheet_title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: T.ink,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.groups_outlined, color: T.live),
              title: Text(
                l.messages_new_group,
                style: const TextStyle(color: T.ink),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _newGroup(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: T.inkSub),
              title: Text(
                l.messages_new_scan,
                style: const TextStyle(color: T.ink),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                showToast(context, l.common_more);
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: T.inkSub),
              title: Text(
                l.messages_new_contact_organizer,
                style: const TextStyle(color: T.ink),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                showToast(context, l.common_more);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _newGroup(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final titleC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.elev2,
        title: Text(l.messages_new_group, style: const TextStyle(color: T.ink)),
        content: TextField(
          controller: titleC,
          style: const TextStyle(color: T.ink),
          decoration: InputDecoration(
            hintText: l.messages_new_group_title_hint,
            hintStyle: const TextStyle(color: T.inkDim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.common_confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(messagesRepoProvider)
          .createConversation(
            title: titleC.text.trim().isEmpty ? null : titleC.text.trim(),
            kind: 'group',
          );
      ref.invalidate(conversationsProvider);
      if (context.mounted) {
        showToast(context, l.messages_new_created, success: true);
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, '${l.messages_new_failed}: $e', error: true);
      }
    }
  }

  Future<void> _showLongPressMenu(
    BuildContext context,
    WidgetRef ref,
    ConversationRow c,
  ) async {
    final l = context.l10n;
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
            const SizedBox(height: 6),
            ListTile(
              leading: Icon(
                LocalStore.isPinned(c.id)
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
                color: T.live,
              ),
              title: Text(
                LocalStore.isPinned(c.id) ? l.common_unpin : l.common_pin,
                style: const TextStyle(color: T.ink),
              ),
              onTap: () async {
                await LocalStore.togglePinned(c.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: Icon(
                LocalStore.isMuted(c.id)
                    ? Icons.notifications_off
                    : Icons.notifications_off_outlined,
                color: T.inkSub,
              ),
              title: Text(
                LocalStore.isMuted(c.id) ? l.common_unmute : l.common_mute,
                style: const TextStyle(color: T.ink),
              ),
              onTap: () async {
                await LocalStore.toggleMuted(c.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.mark_email_read_outlined,
                color: T.inkSub,
              ),
              title: Text(
                l.messages_long_press_actions_mark_read,
                style: const TextStyle(color: T.ink),
              ),
              onTap: () async {
                await ref.read(messagesRepoProvider).markRead(c.id);
                ref.invalidate(conversationsProvider);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: T.danger),
              title: Text(
                l.messages_long_press_actions_delete,
                style: const TextStyle(color: T.danger),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: context.tokens.elev2,
                    content: Text(
                      l.messages_delete_confirm,
                      style: const TextStyle(color: T.ink),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(false),
                        child: Text(l.common_cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(d).pop(true),
                        child: Text(
                          l.common_delete,
                          style: const TextStyle(color: T.danger),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await ref
                        .read(messagesRepoProvider)
                        .deleteConversation(c.id);
                    ref.invalidate(conversationsProvider);
                    if (context.mounted) {
                      showToast(context, l.messages_deleted, success: true);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showToast(context, '$e', error: true);
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  final ConversationRow thread;
  final bool isFirst;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ThreadRow({
    required this.thread,
    required this.isFirst,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localStoreProvider);
    final title = thread.title ?? context.l10n.messages_thread_default_title;
    final time = DateFormat('HH:mm').format(thread.updatedAt.toLocal());
    final pinned = LocalStore.isPinned(thread.id);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: pinned ? const Color(0x0800FF85) : null,
          border: isFirst
              ? null
              : Border(top: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(title, size: 44),
                if (thread.unread > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.warn,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.tokens.bg, width: 2),
                      ),
                      child: Text(
                        '${thread.unread}',
                        style: const TextStyle(
                          fontFamily: T.fontMono,
                          fontFamilyFallback: T.monoFallbacks,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (pinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin, size: 11, color: T.live),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: T.ink,
                          ),
                        ),
                      ),
                      Label(time),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Label(
                    thread.kind == 'group'
                        ? context.l10n.messages_kind_group
                        : context.l10n.messages_kind_dm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 40, color: T.inkMute),
          const SizedBox(height: 10),
          Text(
            l.messages_empty_title,
            style: const TextStyle(color: T.ink, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            l.messages_empty_sub,
            style: const TextStyle(color: T.inkSub, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
