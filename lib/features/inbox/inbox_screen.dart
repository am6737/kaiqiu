// inbox_screen.dart — 合并消息 + 通知的收件箱。
// 顶部 PageTitleBar + 顶层"消息 | 通知" tab + IndexedStack（保留 state）。
// Header action 随 tab 切换：消息 tab 显示"新建 DM"，通知 tab 显示"全部已读"。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../messages/messages_tab.dart';
import '../notifications/notifications_tab.dart';

enum InboxTab { messages, notifications }

class InboxScreen extends ConsumerStatefulWidget {
  final InboxTab initialTab;
  const InboxScreen({super.key, this.initialTab = InboxTab.notifications});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  late InboxTab _current = widget.initialTab;
  final _notifsKey = GlobalKey<NotificationsTabState>();

  @override
  void initState() {
    super.initState();
    // The notification tab dot reads _notifsKey.currentState?.unreadCount,
    // which is null during the first build. Re-evaluate once the subtree is
    // mounted. Remove together with the GlobalKey when notifications get a
    // real provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.inbox_title,
              onBack: () => context.pop(),
              actions: [_buildAction(context)],
            ),
            _TopTabs(
              current: _current,
              messagesUnread: ref.watch(messagesUnreadProvider),
              notificationsUnread:
                  (_notifsKey.currentState?.unreadCount ?? 0) > 0,
              onSelect: (t) => setState(() => _current = t),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IndexedStack(
                index: _current.index,
                children: [
                  const MessagesTab(),
                  NotificationsTab(key: _notifsKey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    final l = context.l10n;
    return switch (_current) {
      InboxTab.messages => GestureDetector(
          onTap: () => showMessagesNewSheet(context, ref),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.tokens.accentSubtle,
              border: Border.all(color: const Color(0x6600FF85)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(Icons.add, size: 18, color: context.tokens.accent),
          ),
        ),
      InboxTab.notifications => GestureDetector(
          onTap: () {
            _notifsKey.currentState?.markAllRead();
            // Force the dot on the notifications tab label to disappear.
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Label(l.notif_mark_all_read),
          ),
        ),
    };
  }
}

class _TopTabs extends StatelessWidget {
  final InboxTab current;
  final bool messagesUnread;
  final bool notificationsUnread;
  final ValueChanged<InboxTab> onSelect;
  const _TopTabs({
    required this.current,
    required this.messagesUnread,
    required this.notificationsUnread,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Row(
          children: [
            Expanded(
              child: _InboxTabButton(
                label: l.inbox_tab_messages,
                active: current == InboxTab.messages,
                showDot: messagesUnread,
                onTap: () => onSelect(InboxTab.messages),
              ),
            ),
            Expanded(
              child: _InboxTabButton(
                label: l.inbox_tab_notifications,
                active: current == InboxTab.notifications,
                showDot: notificationsUnread,
                onTap: () => onSelect(InboxTab.notifications),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool showDot;
  final VoidCallback onTap;
  const _InboxTabButton({
    required this.label,
    required this.active,
    required this.showDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.elev3 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? context.tokens.ink : context.tokens.inkSub,
              ),
            ),
            if (showDot) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: context.tokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
