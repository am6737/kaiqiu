// chat_screen.dart — 单会话聊天 (real-time via Supabase)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/message.dart';
import '../../models/profile.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart' as svc;
import '../../services/storage.dart';
import '../../utils/toast.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/rich_input.dart';
import '../../theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeConvIdProvider.notifier).state = widget.convId;
      ref.read(messagesRepoProvider).markRead(widget.convId);
    });
  }

  @override
  void dispose() {
    ref.read(activeConvIdProvider.notifier).state = null;
    final repo = ref.read(messagesRepoProvider);
    repo.markRead(widget.convId).then((_) {
      repo.refreshConversations();
    });
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

  Future<void> _showMoreMenu({required bool isDm}) async {
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
            if (!isDm)
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
              leading: Icon(Icons.delete_sweep_outlined, color: context.tokens.warn),
              title: Text(
                l.chat_more_clear_history,
                style: TextStyle(color: context.tokens.warn),
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
                          style: TextStyle(color: context.tokens.danger),
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

  Future<void> _pickAndSendImage() async {
    final url = await StorageService().pickCropCompressAndUpload(
      bucket: 'chat-images',
      pathPrefix: widget.convId,
      square: false,
    );
    if (url == null || !mounted) return;
    try {
      await ref.read(messagesRepoProvider).send(widget.convId, url, kind: 'image');
    } catch (e) {
      if (mounted) {
        showToast(context, '${context.l10n.chat_send_failed}：$e', error: true);
      }
    }
  }

  void _sendPlaceholder(String label) {
    final l = context.l10n;
    ref.read(messagesRepoProvider).send(
      widget.convId,
      '${l.chat_attachment_system_placeholder} · $label',
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.convId));
    final me = svc.currentUserId;

    final conv = ref.watch(conversationByIdProvider(widget.convId));
    final isDm = conv?.kind == 'dm';
    final peerAsync = isDm
        ? ref.watch(dmPeerProfileProvider(widget.convId))
        : const AsyncValue<Profile?>.data(null);
    final peerProfile = peerAsync.valueOrNull;

    String title;
    if (conv == null) {
      title = '…';
    } else if (isDm) {
      title = peerAsync.when(
        data: (p) => p?.name ?? '…',
        loading: () => '…',
        error: (_, _) => '…',
      );
    } else {
      final raw = conv.title ?? '';
      if (raw.startsWith('event:')) {
        final eventId = raw.substring(6);
        final event = ref.watch(eventDetailProvider(eventId)).valueOrNull;
        title = event?.name ?? context.l10n.chat_default_group_title;
      } else {
        title = raw.isEmpty
            ? context.l10n.chat_default_group_title
            : raw;
      }
    }

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
                    child: GestureDetector(
                      onTap: isDm && peerProfile != null
                          ? () => context.push('/user/${peerProfile.id}')
                          : null,
                      child: Row(
                        children: [
                          if (isDm && peerProfile != null) ...[
                            NetworkAvatar(peerProfile.name, url: peerProfile.avatarUrl, size: 28),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.tokens.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showMoreMenu(isDm: isDm),
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
                data: (list) {
                  if (isDm && list.isEmpty) {
                    return _DmEmptyState(peerAsync: peerAsync);
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        _Bubble(msg: list[i], isMe: list[i].senderId == me),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.tokens.accent,
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
            RichInput(
              controller: _input,
              onSend: _send,
              sending: _sending,
              showAttachments: true,
              onPickImage: _pickAndSendImage,
              onPickLocation: () => _sendPlaceholder(context.l10n.chat_attachment_location),
              onInvite: () => _sendPlaceholder(context.l10n.chat_attachment_invite),
              hintText: context.l10n.chat_hint,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  final Message msg;
  final bool isMe;
  const _Bubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final senderProfile = msg.senderId != null
        ? ref.watch(profileByIdProvider(msg.senderId!)).valueOrNull
        : null;
    final who = senderProfile?.name ??
        (msg.senderId != null ? msg.senderId!.substring(0, 4) : context.l10n.chat_sender_system);

    final Widget bubble;
    if (msg.kind == 'image' && msg.body != null) {
      bubble = GestureDetector(
        onTap: () => _showFullImage(context, msg.body!),
        onLongPress: () {
          HapticFeedback.lightImpact();
          Clipboard.setData(ClipboardData(text: msg.body!));
          showToast(context, context.l10n.chat_copied, success: true);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 260),
            child: CachedNetworkImage(
              imageUrl: msg.body!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                width: 160,
                height: 120,
                color: context.tokens.elev3,
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.tokens.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                width: 160,
                height: 80,
                color: context.tokens.elev3,
                child: Icon(Icons.broken_image, color: context.tokens.inkDim),
              ),
            ),
          ),
        ),
      );
    } else {
      bubble = GestureDetector(
        onLongPress: () {
          if (msg.body != null) {
            HapticFeedback.lightImpact();
            Clipboard.setData(ClipboardData(text: msg.body!));
            showToast(context, context.l10n.chat_copied, success: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isMe ? context.tokens.accent : context.tokens.elev2,
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[NetworkAvatar(who, url: senderProfile?.avatarUrl, size: 28), const SizedBox(width: 8)],
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
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
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

  static void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _DmEmptyState extends StatelessWidget {
  final AsyncValue<Profile?> peerAsync;
  const _DmEmptyState({required this.peerAsync});

  @override
  Widget build(BuildContext context) {
    return peerAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.tokens.accent,
          strokeWidth: 2,
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final metaParts = [
          if ((profile.position ?? '').isNotEmpty) profile.position!,
          if ((profile.city ?? '').isNotEmpty) profile.city!,
          if ((profile.district ?? '').isNotEmpty) profile.district!,
        ];
        final metaLine = metaParts.isNotEmpty ? metaParts.join(' · ') : null;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (metaLine != null) ...[
                  Text(
                    metaLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.inkDim,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.chat_dm_empty_title,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.tokens.inkSub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.chat_dm_empty_subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.inkDim,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
