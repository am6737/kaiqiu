// chat_screen.dart — 单会话聊天 (real-time via Supabase)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/message.dart';
import '../../providers.dart';
import '../../services/supabase.dart' as svc;
import '../../theme/tokens.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
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
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: T.line, width: 1)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 20, color: T.ink),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('开球 · 新手大厅',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: T.ink)),
                  ),
                  const Icon(Icons.more_horiz, size: 20, color: T.inkSub),
                ],
              ),
            ),
            Expanded(
              child: messagesAsync.when(
                data: (list) => ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _Bubble(
                    msg: list[i],
                    isMe: list[i].senderId == me,
                  ),
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: T.live, strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Text('加载失败: $e',
                      style: const TextStyle(color: T.inkSub)),
                ),
              ),
            ),
            // Send bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              decoration: const BoxDecoration(
                color: T.elev1,
                border: Border(top: BorderSide(color: T.line, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: T.elev2,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _input,
                        style: const TextStyle(
                            fontSize: 14, color: T.ink, height: 1.4),
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: '输入消息…',
                          hintStyle: TextStyle(color: T.inkDim),
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
                        color: _sending ? T.elev3 : T.live,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: T.inkSub,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send,
                              size: 16, color: Colors.black),
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
              color: T.elev2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              msg.body ?? '',
              style: const TextStyle(fontSize: 11, color: T.inkSub),
            ),
          ),
        ),
      );
    }

    final time = DateFormat('HH:mm').format(msg.createdAt.toLocal());
    final who = msg.senderId != null
        ? msg.senderId!.substring(0, 4)
        : '系统';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: isMe ? T.live : T.elev2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg.body ?? '',
        style: TextStyle(
          fontSize: 14,
          color: isMe ? Colors.black : T.ink,
          height: 1.4,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Avatar(who, size: 28),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              bubble,
              const SizedBox(height: 2),
              Text(time,
                  style: const TextStyle(
                      fontFamily: T.fontMono,
                      fontFamilyFallback: T.monoFallbacks,
                      fontSize: 9,
                      color: T.inkDim)),
            ],
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
