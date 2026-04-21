// chat_screen.dart — 单会话聊天 (real-time via Supabase)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/message.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart' as svc;
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String convId;
  const ChatScreen({super.key, required this.convId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagesRepoProvider).send(widget.convId, text);
      _input.clear();
    } catch (e) {
      if (!mounted) return;
      showToast(context, '${context.l10n.chat_send_failed}：$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showMoreMenu() async {
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
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.people_outline, color: context.tokens.inkSub),
              title: Text(
                l.chat_more_members,
                style: TextStyle(color: context.tokens.ink),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                showToast(context, l.chat_more_members);
              },
            ),
            ListTile(
              leading: Icon(
                LocalStore.isMuted(widget.convId)
                    ? Icons.notifications_off
                    : Icons.notifications_off_outlined,
                color: context.tokens.inkSub,
              ),
              title: Text(
                LocalStore.isMuted(widget.convId)
                    ? l.chat_more_unmute
                    : l.chat_more_mute,
                style: TextStyle(color: context.tokens.ink),
              ),
              onTap: () async {
                await LocalStore.toggleMuted(widget.convId);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: T.warn),
              title: Text(
                l.chat_more_clear_history,
                style: const TextStyle(color: T.warn),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: context.tokens.elev2,
                    content: Text(
                      l.chat_clear_confirm,
                      style: TextStyle(color: context.tokens.ink),
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
                if (ok == true) {
                  try {
                    await ref
                        .read(messagesRepoProvider)
                        .clearMessages(widget.convId);
                    ref.invalidate(chatMessagesProvider(widget.convId));
                    if (mounted) {
                      showToast(context, l.chat_cleared, success: true);
                    }
                  } catch (e) {
                    if (mounted) showToast(context, '$e', error: true);
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: context.tokens.inkSub),
              title: Text(
                l.chat_more_report,
                style: TextStyle(color: context.tokens.ink),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                showToast(context, l.chat_more_report);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachmentSheet() async {
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
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttBtn(
                  icon: Icons.image_outlined,
                  label: l.chat_attachment_image,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _sendSystem(
                      '${l.chat_attachment_system_placeholder} · ${l.chat_attachment_image}',
                    );
                  },
                ),
                _AttBtn(
                  icon: Icons.location_on_outlined,
                  label: l.chat_attachment_location,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _sendSystem(
                      '${l.chat_attachment_system_placeholder} · ${l.chat_attachment_location}',
                    );
                  },
                ),
                _AttBtn(
                  icon: Icons.sports_soccer,
                  label: l.chat_attachment_invite,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _sendSystem(
                      '${l.chat_attachment_system_placeholder} · ${l.chat_attachment_invite}',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSystem(String body) async {
    try {
      await ref.read(messagesRepoProvider).send(widget.convId, body);
    } catch (e) {
      if (mounted) {
        showToast(context, '${context.l10n.chat_send_failed}: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.convId));
    final me = svc.currentUserId;

    // Auto-scroll to bottom when new data arrives.
    messagesAsync.whenData((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    });

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.chat_default_group_title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showMoreMenu,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.more_horiz, size: 20, color: context.tokens.inkSub),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messagesAsync.when(
                data: (list) => ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _Bubble(msg: list[i], isMe: list[i].senderId == me),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: T.live,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '${context.l10n.error_load_failed}: $e',
                    style: TextStyle(color: context.tokens.inkSub),
                  ),
                ),
              ),
            ),
            // Send bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              decoration: BoxDecoration(
                color: context.tokens.elev1,
                border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showAttachmentSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.tokens.elev2,
                        border: Border.all(color: context.tokens.line),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, size: 18, color: context.tokens.inkSub),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.tokens.elev2,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _input,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.tokens.ink,
                          height: 1.4,
                        ),
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: context.l10n.chat_hint,
                          hintStyle: TextStyle(color: context.tokens.inkDim),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _sending ? context.tokens.elev3 : T.live,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: context.tokens.inkSub,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              size: 16,
                              color: Colors.black,
                            ),
                    ),
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

class _AttBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: context.tokens.ink),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: context.tokens.inkSub)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message msg;
  final bool isMe;
  const _Bubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (msg.kind == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              msg.body ?? '',
              style: TextStyle(fontSize: 11, color: context.tokens.inkSub),
            ),
          ),
        ),
      );
    }

    final time = DateFormat('HH:mm').format(msg.createdAt.toLocal());
    final who = msg.senderId != null
        ? msg.senderId!.substring(0, 4)
        : context.l10n.chat_sender_system;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe ? T.live : context.tokens.elev2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg.body ?? '',
        style: TextStyle(
          fontSize: 14,
          color: isMe ? Colors.black : context.tokens.ink,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[Avatar(who, size: 28), const SizedBox(width: 8)],
          Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              bubble,
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontFamily: T.fontMono,
                  fontFamilyFallback: T.monoFallbacks,
                  fontSize: 9,
                  color: context.tokens.inkDim,
                ),
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
