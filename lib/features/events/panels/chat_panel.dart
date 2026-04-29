import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/message.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../services/storage.dart';
import '../../../utils/toast.dart';
import '../../../widgets/network_avatar.dart';
import '../../../widgets/rich_input.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class ChatPanel extends ConsumerWidget {
  final String eventId;
  const ChatPanel({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(eventChatMessagesProvider(eventId));
    return Container(
      padding: const EdgeInsets.all(14),
      color: context.tokens.elev1,
      child: async.when(
        data: (msgs) {
          if (msgs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  l.empty_no_messages,
                  style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final m in msgs.reversed) Msg(msg: m)],
          );
        },
        loading: () => Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              '${l.error_load_failed}: $e',
              style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatInput extends ConsumerStatefulWidget {
  final String eventId;
  const ChatInput({super.key, required this.eventId});

  @override
  ConsumerState<ChatInput> createState() => ChatInputState();
}

class ChatInputState extends ConsumerState<ChatInput> {
  final _inputC = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _inputC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputC.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final convId = await ref.read(
        eventChatConvProvider(widget.eventId).future,
      );
      await ref.read(messagesRepoProvider).send(convId, text);
      _inputC.clear();
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.chat_send_failed, error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final convId = await ref.read(
      eventChatConvProvider(widget.eventId).future,
    );
    final url = await StorageService().pickCropCompressAndUpload(
      bucket: 'chat-images',
      pathPrefix: convId,
      square: false,
    );
    if (url == null || !mounted) return;
    try {
      await ref.read(messagesRepoProvider).send(convId, url, kind: 'image');
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.chat_send_failed, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichInput(
      controller: _inputC,
      onSend: _send,
      sending: _sending,
      showAttachments: true,
      onPickImage: _pickAndSendImage,
      hintText: context.l10n.event_chat_hint,
    );
  }
}

class Msg extends ConsumerWidget {
  final Message msg;
  const Msg({super.key, required this.msg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final profile = msg.senderId != null
        ? ref.watch(profileByIdProvider(msg.senderId!)).valueOrNull
        : null;
    final sender = msg.senderId == currentUserId
        ? l.event_chat_sender_you
        : (profile?.name ?? l.event_chat_sender_stranger);
    final hh = msg.createdAt.hour.toString().padLeft(2, '0');
    final mm = msg.createdAt.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkAvatar(sender, url: profile?.avatarUrl, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sender,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.tokens.inkSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Label('$hh:$mm'),
                  ],
                ),
                if (msg.kind == 'image' && msg.body != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180, maxHeight: 220),
                        child: CachedNetworkImage(
                          imageUrl: msg.body!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            width: 140,
                            height: 100,
                            color: context.tokens.elev3,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: context.tokens.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            width: 140,
                            height: 60,
                            color: context.tokens.elev3,
                            child: Icon(Icons.broken_image, color: context.tokens.inkDim),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    msg.body ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.ink,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
