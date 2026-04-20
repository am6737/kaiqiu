// messages_screen.dart — 消息列表 (real Supabase data)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../../repositories/messages_repository.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  bool _bootstrapping = false;

  Future<void> _bootstrapIfNeeded(List<ConversationRow> list) async {
    if (list.isNotEmpty || _bootstrapping) return;
    setState(() => _bootstrapping = true);
    try {
      await ref.read(messagesRepoProvider).ensureDemoConversation();
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建对话失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Text('消息',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -0.5)),
            ),
            Expanded(
              child: async.when(
                data: (list) {
                  if (list.isEmpty) {
                    // Auto-bootstrap a demo conversation on first open.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _bootstrapIfNeeded(list);
                    });
                    return const _EmptyState();
                  }
                  return RefreshIndicator(
                    color: T.live,
                    backgroundColor: T.elev1,
                    onRefresh: () async =>
                        ref.invalidate(conversationsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ThreadRow(
                        thread: list[i],
                        isFirst: i == 0,
                        onTap: () => context.push('/chat/${list[i].id}'),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: T.live, strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 32, color: T.warn),
                        const SizedBox(height: 8),
                        Text('加载失败：$e',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12, color: T.inkSub)),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: '重试',
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
}

class _ThreadRow extends StatelessWidget {
  final ConversationRow thread;
  final bool isFirst;
  final VoidCallback onTap;
  const _ThreadRow({
    required this.thread,
    required this.isFirst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = thread.title ?? '对话';
    final time = DateFormat('HH:mm').format(thread.updatedAt.toLocal());
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isFirst
              ? null
              : const Border(top: BorderSide(color: T.line, width: 1)),
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
                          minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: T.warn,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: T.bg, width: 2),
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
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: T.ink),
                        ),
                      ),
                      Label(time),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Label(thread.kind == 'group' ? '群聊' : '私信'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 40, color: T.inkMute),
            SizedBox(height: 10),
            Text('正在创建新手大厅…',
                style: TextStyle(color: T.inkSub, fontSize: 14)),
            SizedBox(height: 4),
            Label('稍等'),
          ],
        ),
      ),
    );
  }
}
