# Inbox Merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"消息"tab 和"通知"overlay 合并成一个带顶层 tab 的 `/inbox` 页面;底部导航从 5 个 tab 减为 4 个;首页铃铛图标换成 `inbox_outlined` 并指向新页面。

**Architecture:** 抽出 `MessagesTab` 和 `NotificationsTab` 两个可嵌入 widget,放进新建的 `InboxScreen` 容器中(`IndexedStack` 保留切换 state)。顶部 header action 随当前 tab 切换。旧路由 `/messages` 和 `/notifications` 改为 redirect 到 `/inbox?tab=xxx`,保证推送深链不失效。业务 provider / repository 零改动。

**Tech Stack:** Flutter 3.11+、flutter_riverpod 2.6、go_router 14.6、flutter_slidable 3.1、flutter_gen_l10n(ARB)、SharedPreferences。

**Spec:** `docs/superpowers/specs/2026-04-21-inbox-merge-design.md`

---

## 文件结构变化

**新增**
- `lib/features/inbox/inbox_screen.dart` — 合并页容器(顶层 tab 切换、header action、未读红点)
- `lib/features/messages/messages_tab.dart` — 从 `MessagesScreen` 抽出的可嵌入会话列表
- `lib/features/notifications/notifications_tab.dart` — 从 `NotificationsScreen` 抽出的可嵌入通知列表
- `test/features/inbox/inbox_screen_test.dart`
- `test/widgets/bottom_nav_shell_test.dart`

**修改**
- `lib/routes.dart` — 删 `/messages` shell branch;新增 `/inbox` GoRoute;`/messages`、`/notifications` 改为 redirect
- `lib/widgets/bottom_nav_shell.dart` — `tabs` 从 5 项减至 4 项
- `lib/features/home/home_screen.dart` — 铃铛图标改 `inbox_outlined`,跳 `/inbox`;`_WarnDot` 升级为 `_InboxUnreadDot`(订阅 provider)
- `lib/providers.dart` — 新增 `messagesUnreadProvider`
- `lib/l10n/app_en.arb` / `app_zh.arb` — 新增 `inbox_title` / `inbox_tab_messages` / `inbox_tab_notifications`;删除 `tab_messages`
- `test/features/messages/messages_swipe_actions_test.dart` — 把 `MessagesScreen` 换成 `MessagesTab` + Scaffold 包装

**删除**
- `lib/features/messages/messages_screen.dart`
- `lib/features/notifications/notifications_screen.dart`

---

## Task 1:新增 l10n 键并重新生成

**Files:**
- Modify: `lib/l10n/app_zh.arb`(模板,需放第一位)
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/widgets/bottom_nav_shell.dart`(先把 `l.tab_messages` 引用替换,避免 gen-l10n 后编译断)

- [ ] **Step 1: 打开 `lib/l10n/app_zh.arb`,定位第 9 行 `"tab_messages": "消息",`**

删除该行,然后在文件顶部 `"tab_me": "我",` 之后(约第 10 行附近)新增三个键。

找到类似:
```json
  "tab_home": "首页",
  "tab_pickup": "约球",
  "tab_events": "赛事",
  "tab_messages": "消息",
  "tab_me": "我",
```

替换为:
```json
  "tab_home": "首页",
  "tab_pickup": "约球",
  "tab_events": "赛事",
  "tab_me": "我",

  "inbox_title": "收件箱",
  "inbox_tab_messages": "消息",
  "inbox_tab_notifications": "通知",
```

- [ ] **Step 2: 打开 `lib/l10n/app_en.arb`,做对应改动**

删除 `"tab_messages": "Messages",`,并在同位置加:
```json
  "inbox_title": "Inbox",
  "inbox_tab_messages": "Messages",
  "inbox_tab_notifications": "Notifications",
```

- [ ] **Step 3: 先把 `bottom_nav_shell.dart` 里的 `l.tab_messages` 引用清掉**

打开 `lib/widgets/bottom_nav_shell.dart`,找到第 19 行:
```dart
(l.tab_messages, Icons.chat_bubble_outline, Icons.chat_bubble),
```

**整行删除**(Task 7 会正式改 tabs 结构,这里先删引用,让编译能通过)。

- [ ] **Step 4: 运行 gen-l10n 重新生成本地化代码**

Run: `flutter gen-l10n`
Expected: `lib/l10n/generated/app_localizations*.dart` 被覆盖,`tab_messages` getter 消失,`inbox_title` / `inbox_tab_messages` / `inbox_tab_notifications` getter 出现。

- [ ] **Step 5: 跑一下分析确认没有残留的 `tab_messages` 引用**

Run: `flutter analyze lib/ test/ 2>&1 | grep -i 'tab_messages' || echo 'clean'`
Expected: `clean`

- [ ] **Step 6: 提交**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated lib/widgets/bottom_nav_shell.dart
git commit -m "chore(l10n): add inbox_* keys, remove tab_messages"
```

---

## Task 2:新增 `messagesUnreadProvider`

**Files:**
- Modify: `lib/providers.dart:105-109`(`conversationsProvider` 附近)

- [ ] **Step 1: 在 `conversationsProvider` 定义后紧跟加入新 provider**

打开 `lib/providers.dart`,定位到:
```dart
final conversationsProvider = FutureProvider<List<ConversationRow>>((
  ref,
) async {
  return ref.read(messagesRepoProvider).listConversations();
});
```

在它之后插入:
```dart
/// `true` if any conversation has `unread > 0`. Used for inbox unread dot.
final messagesUnreadProvider = Provider<bool>((ref) {
  final async = ref.watch(conversationsProvider);
  return async.maybeWhen(
    data: (list) => list.any((c) => c.unread > 0),
    orElse: () => false,
  );
});
```

- [ ] **Step 2: 确认编译通过**

Run: `flutter analyze lib/providers.dart`
Expected: `No issues found!`

- [ ] **Step 3: 提交**

```bash
git add lib/providers.dart
git commit -m "feat(providers): add messagesUnreadProvider"
```

---

## Task 3:抽出 `MessagesTab` widget(保留 `MessagesScreen` 作为瘦壳)

本任务把 `messages_screen.dart` 的列表区域抽到新文件 `messages_tab.dart`;`MessagesScreen` 暂时保留并改为"壳",内部调用 `MessagesTab`,这样既有的 `/messages` 路由和测试仍能跑通(删除会放到 Task 9)。

**Files:**
- Create: `lib/features/messages/messages_tab.dart`
- Modify: `lib/features/messages/messages_screen.dart`(保留但精简)

- [ ] **Step 1: 创建 `lib/features/messages/messages_tab.dart`**

写入以下内容(从 `messages_screen.dart` 抽列表+所有私有 widget/helper,去掉顶部 header 的 Row,改为不带 Scaffold/SafeArea 的内容):

```dart
// messages_tab.dart — 嵌入 InboxScreen 的会话列表(无 Scaffold / 无 header)。
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../repositories/messages_repository.dart';
import '../../services/local_storage.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';
import 'new_dm_sheet.dart';

class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(conversationsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return RefreshIndicator(
            color: context.tokens.accent,
            backgroundColor: context.tokens.elev1,
            onRefresh: () async =>
                ref.invalidate(conversationsProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 120), _EmptyState()],
            ),
          );
        }
        final pinned = list
            .where((c) => LocalStore.isPinned(c.id))
            .toList();
        final others = list
            .where((c) => !LocalStore.isPinned(c.id))
            .toList();
        final sorted = [...pinned, ...others];
        return RefreshIndicator(
          color: context.tokens.accent,
          backgroundColor: context.tokens.elev1,
          onRefresh: () async =>
              ref.invalidate(conversationsProvider),
          child: SlidableAutoCloseBehavior(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _ThreadRow(
                thread: sorted[i],
                isFirst: i == 0,
                onTap: () => context.push('/chat/${sorted[i].id}'),
                onLongPress: () =>
                    _showLongPressMenu(context, ref, sorted[i]),
              ),
            ),
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.tokens.accent,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 32, color: context.tokens.warn),
              const SizedBox(height: 8),
              Text(
                '${l.error_load_failed}：$e',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: l.common_retry,
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                onPressed: () => ref.invalidate(conversationsProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Exposed so `InboxScreen` can invoke it from the header "+"" action.
Future<void> showMessagesNewSheet(BuildContext context, WidgetRef ref) async {
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
          const SizedBox(height: 14),
          Text(
            l.messages_new_sheet_title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.chat_bubble_outline,
                color: context.tokens.accent),
            title: Text(
              l.messages_new_dm,
              style: TextStyle(color: context.tokens.ink),
            ),
            onTap: () async {
              Navigator.of(ctx).pop();
              if (context.mounted) {
                await showNewDmSheet(context, ref);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.groups_outlined, color: context.tokens.accent),
            title: Text(
              l.messages_new_group,
              style: TextStyle(color: context.tokens.ink),
            ),
            onTap: () async {
              Navigator.of(ctx).pop();
              await _newGroup(context, ref);
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
      title: Text(l.messages_new_group, style: TextStyle(color: context.tokens.ink)),
      content: TextField(
        controller: titleC,
        style: TextStyle(color: context.tokens.ink),
        decoration: InputDecoration(
          hintText: l.messages_new_group_title_hint,
          hintStyle: TextStyle(color: context.tokens.inkDim),
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
                color: context.tokens.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Icon(
              Icons.mark_email_read_outlined,
              color: context.tokens.inkSub,
            ),
            title: Text(
              l.messages_long_press_actions_mark_read,
              style: TextStyle(color: context.tokens.ink),
            ),
            onTap: () async {
              await ref.read(messagesRepoProvider).markRead(c.id);
              ref.invalidate(conversationsProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
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
    String title;
    if (thread.kind == 'dm') {
      final peer = ref.watch(dmPeerProfileProvider(thread.id)).valueOrNull;
      title = peer?.name ?? context.l10n.messages_thread_default_title;
    } else {
      title = thread.title ?? context.l10n.messages_thread_default_title;
    }
    final time = DateFormat('HH:mm').format(thread.updatedAt.toLocal());
    final pinned = LocalStore.isPinned(thread.id);
    final muted = LocalStore.isMuted(thread.id);
    return Slidable(
      key: ValueKey(thread.id),
      groupTag: 'messages',
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.75,
        children: [
          SlidableAction(
            onPressed: (_) async {
              await LocalStore.togglePinned(thread.id);
            },
            backgroundColor: pinned
                ? context.tokens.accent
                : context.tokens.elev2,
            foregroundColor: pinned
                ? context.tokens.accentInk
                : context.tokens.ink,
            icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: pinned
                ? context.l10n.common_unpin
                : context.l10n.common_pin,
          ),
          SlidableAction(
            onPressed: (_) async {
              await LocalStore.toggleMuted(thread.id);
            },
            backgroundColor: muted
                ? context.tokens.inkSub
                : context.tokens.elev2,
            foregroundColor: muted
                ? context.tokens.bg
                : context.tokens.ink,
            icon: muted
                ? Icons.notifications_off
                : Icons.notifications_off_outlined,
            label: muted
                ? context.l10n.common_unmute
                : context.l10n.common_mute,
          ),
          SlidableAction(
            onPressed: (slidableCtx) =>
                _confirmAndDelete(slidableCtx, ref, thread),
            backgroundColor: context.tokens.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: context.l10n.common_delete,
          ),
        ],
      ),
      child: GestureDetector(
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
                          color: context.tokens.warn,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.tokens.bg, width: 2),
                        ),
                        child: Text(
                          '${thread.unread}',
                          style: TextStyle(
                            fontFamily: context.tokens.fontMono,
                            fontFamilyFallback: context.tokens.monoFallbacks,
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
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin, size: 11, color: context.tokens.accent),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.ink,
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
          Icon(Icons.chat_bubble_outline, size: 40, color: context.tokens.inkMute),
          const SizedBox(height: 10),
          Text(
            l.messages_empty_title,
            style: TextStyle(color: context.tokens.ink, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            l.messages_empty_sub,
            style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmAndDelete(
  BuildContext context,
  WidgetRef ref,
  ConversationRow c,
) async {
  final l = context.l10n;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: context.tokens.elev2,
      content: Text(
        l.messages_delete_confirm,
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
  if (confirm != true) return;
  try {
    await ref.read(messagesRepoProvider).deleteConversation(c.id);
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
```

- [ ] **Step 2: 把 `messages_screen.dart` 改为壳**

整个文件替换为:

```dart
// messages_screen.dart — 薄壳:保留旧路由引用,内部直接挂 MessagesTab。
// 即将在 Task 9 删除,路由改为 redirect 到 /inbox?tab=messages。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import 'messages_tab.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
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
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.tokens.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
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
                ],
              ),
            ),
            const Expanded(child: MessagesTab()),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 确保原有测试仍通过**

Run: `flutter test test/features/messages/messages_swipe_actions_test.dart`
Expected: 所有既有 case 通过(widget 树结构不变,只是内部实现换了)。

- [ ] **Step 4: 提交**

```bash
git add lib/features/messages/messages_tab.dart lib/features/messages/messages_screen.dart
git commit -m "refactor(messages): extract MessagesTab from MessagesScreen"
```

---

## Task 4:抽出 `NotificationsTab` widget(保留 `NotificationsScreen` 作为瘦壳)

**Files:**
- Create: `lib/features/notifications/notifications_tab.dart`
- Modify: `lib/features/notifications/notifications_screen.dart`

- [ ] **Step 1: 创建 `lib/features/notifications/notifications_tab.dart`**

写入:

```dart
// notifications_tab.dart — 嵌入 InboxScreen 的通知列表(无 Scaffold / 无 PageTitleBar)。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../utils/time_fmt.dart';
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

// Shell-branch roots (after inbox merge, /messages is gone).
const _branchRoots = {'/home', '/pickup', '/events', '/me'};

class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => NotificationsTabState();
}

class NotificationsTabState extends ConsumerState<NotificationsTab> {
  bool _unreadOnly = false;
  final Set<String> _read = {};

  /// Total count of unread items. Callers (InboxScreen) read this via GlobalKey
  /// to decide whether to draw a red dot on the notification tab label.
  int get unreadCount =>
      _demoItems(context.l10n).where((n) => !_read.contains(n.id)).length;

  /// Invoked by the "Mark all read" header action.
  void markAllRead() {
    setState(() => _read.addAll(_demoItems(context.l10n).map((i) => i.id)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _demoItems(l);
    final list = _unreadOnly
        ? items.where((n) => !_read.contains(n.id)).toList()
        : items;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  child: _SubTab(
                    label: l.notif_all,
                    active: !_unreadOnly,
                    onTap: () => setState(() => _unreadOnly = false),
                  ),
                ),
                Expanded(
                  child: _SubTab(
                    label: l.notif_unread,
                    active: _unreadOnly,
                    onTap: () => setState(() => _unreadOnly = true),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _Empty(label: l.empty_no_notifications)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final group in _grouped(list).entries) ...[
                      SectionHeader(title: _groupLabel(group.key)),
                      for (final n in group.value)
                        _NotifRow(
                          item: n,
                          read: _read.contains(n.id),
                          onTap: () {
                            setState(() => _read.add(n.id));
                            final route = n.route;
                            if (route == null) return;
                            // Legacy notifications may still carry /messages.
                            if (route == '/messages') {
                              context.go('/inbox?tab=messages');
                              return;
                            }
                            if (_branchRoots.contains(route)) {
                              context.go(route);
                            } else {
                              context.push(route);
                            }
                          },
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Map<String, List<_Notif>> _grouped(List<_Notif> items) {
    final m = <String, List<_Notif>>{};
    for (final n in items) {
      m.putIfAbsent(n.group, () => []).add(n);
    }
    return m;
  }

  String _groupLabel(String key) {
    final l = context.l10n;
    return switch (key) {
      'system' => l.notif_group_system,
      'match' => l.notif_group_match,
      'pickup' => l.notif_group_pickup,
      'rating' => l.notif_group_rating,
      _ => '',
    };
  }

  List<_Notif> _demoItems(AppL10n l) {
    final now = DateTime.now();
    return [
      _Notif(
        id: 'welcome',
        group: 'system',
        icon: Icons.celebration,
        title: l.notif_demo_welcome_t,
        body: l.notif_demo_welcome_b,
        at: now.subtract(const Duration(seconds: 10)),
        route: '/me',
      ),
      _Notif(
        id: 'rate-1',
        group: 'rating',
        icon: Icons.star_outline,
        title: l.notif_demo_rate_t,
        body: l.notif_demo_rate_b,
        at: now.subtract(const Duration(minutes: 20)),
        route: '/rate/$demoMatchId',
      ),
      _Notif(
        id: 'pickup-1',
        group: 'pickup',
        icon: Icons.sports_soccer,
        title: l.notif_demo_pickup_t,
        body: l.notif_demo_pickup_b,
        at: now.subtract(const Duration(hours: 1)),
        route: '/pickup',
      ),
      _Notif(
        id: 'event-1',
        group: 'match',
        icon: Icons.emoji_events,
        title: l.notif_demo_event_t,
        body: l.notif_demo_event_b,
        at: now.subtract(const Duration(hours: 3)),
        route: '/events',
      ),
      _Notif(
        id: 'follow-1',
        group: 'system',
        icon: Icons.person_add_alt,
        title: l.notif_demo_follow_t,
        body: l.notif_demo_follow_b,
        at: now.subtract(const Duration(days: 1)),
        route: '/me',
      ),
    ];
  }
}

class _Notif {
  final String id, group, title, body;
  final DateTime at;
  final IconData icon;
  final String? route;
  const _Notif({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    required this.body,
    required this.at,
    this.route,
  });
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SubTab({required this.label, required this.active, required this.onTap});

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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? context.tokens.ink : context.tokens.inkSub,
          ),
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final _Notif item;
  final bool read;
  final VoidCallback onTap;
  const _NotifRow({
    required this.item,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.tokens.line),
              ),
              child: Icon(item.icon, size: 18, color: context.tokens.accent),
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
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: read ? context.tokens.inkSub : context.tokens.ink,
                          ),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: context.tokens.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.inkSub,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Label(formatRelative(item.at, context: context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Avatar('📭', size: 40),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: context.tokens.inkSub, fontSize: 13)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 把 `notifications_screen.dart` 改为壳**

整个文件替换为:

```dart
// notifications_screen.dart — 薄壳:仅为了让旧 /notifications 路由在 Task 6
// 改为 redirect 前仍然编译。Task 9 将删除。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import 'notifications_tab.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _tabKey = GlobalKey<NotificationsTabState>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.notif_title,
              onBack: () => context.pop(),
              actions: [
                GestureDetector(
                  onTap: () => _tabKey.currentState?.markAllRead(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Label(l.notif_mark_all_read),
                  ),
                ),
              ],
            ),
            Expanded(child: NotificationsTab(key: _tabKey)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 确认编译通过,且应用手动跑一下 /notifications 仍然可用**

Run: `flutter analyze lib/features/notifications/`
Expected: `No issues found!`

- [ ] **Step 4: 提交**

```bash
git add lib/features/notifications/notifications_tab.dart lib/features/notifications/notifications_screen.dart
git commit -m "refactor(notifications): extract NotificationsTab from NotificationsScreen"
```

---

## Task 5:创建 `InboxScreen` 合并页

**Files:**
- Create: `lib/features/inbox/inbox_screen.dart`

- [ ] **Step 1: 创建 `lib/features/inbox/inbox_screen.dart`**

写入:

```dart
// inbox_screen.dart — 合并消息 + 通知的收件箱。
// 顶部 PageTitleBar + 顶层"消息 | 通知" tab + IndexedStack(保留 state)。
// Header action 随 tab 切换:消息 tab 显示"新建 DM",通知 tab 显示"全部已读"。
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
```

- [ ] **Step 2: 编译检查**

Run: `flutter analyze lib/features/inbox/`
Expected: `No issues found!`

- [ ] **Step 3: 提交**

```bash
git add lib/features/inbox/inbox_screen.dart
git commit -m "feat(inbox): add InboxScreen merging messages + notifications"
```

---

## Task 6:改路由 — 新增 `/inbox`,删 `/messages` branch,`/messages` 和 `/notifications` 改 redirect

**Files:**
- Modify: `lib/routes.dart`

- [ ] **Step 1: 在 import 区加入 `InboxScreen`**

打开 `lib/routes.dart`,在 `import 'features/home/city_picker_screen.dart';` 之后加:

```dart
import 'features/inbox/inbox_screen.dart';
```

- [ ] **Step 2: 删除 `/messages` shell branch**

定位到 `lib/routes.dart:80-87`:

```dart
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (_, s) => const MessagesScreen(),
            ),
          ],
        ),
```

**整块删除(含逗号)**。现在 `StatefulShellRoute.indexedStack` 只剩 4 个 branch。

- [ ] **Step 3: 删除 `MessagesScreen` 的 import**

删除 `lib/routes.dart:20`:
```dart
import 'features/messages/messages_screen.dart';
```

- [ ] **Step 4: 把旧 `/notifications` GoRoute 换成 redirect,并新增 `/inbox` + `/messages` redirect**

定位 `lib/routes.dart:152-155`:

```dart
    GoRoute(
      path: '/notifications',
      builder: (_, s) => const NotificationsScreen(),
    ),
```

替换为:

```dart
    GoRoute(
      path: '/inbox',
      builder: (_, s) => InboxScreen(
        initialTab: switch (s.uri.queryParameters['tab']) {
          'messages' => InboxTab.messages,
          _ => InboxTab.notifications,
        },
      ),
    ),
    GoRoute(
      path: '/messages',
      redirect: (_, __) => '/inbox?tab=messages',
    ),
    GoRoute(
      path: '/notifications',
      redirect: (_, __) => '/inbox?tab=notifications',
    ),
```

- [ ] **Step 5: 删除 `NotificationsScreen` 的 import**

删除 `lib/routes.dart:21`:
```dart
import 'features/notifications/notifications_screen.dart';
```

- [ ] **Step 6: 编译检查**

Run: `flutter analyze lib/routes.dart`
Expected: `No issues found!`

- [ ] **Step 7: 提交**

```bash
git add lib/routes.dart
git commit -m "feat(routes): add /inbox; redirect /messages and /notifications"
```

---

## Task 7:底部导航 widget 测试(锁定 4-tab 行为)

**Files:**
- Create: `test/widgets/bottom_nav_shell_test.dart`

底部导航的实际改动已在 Task 1 Step 3 完成(删除了 `l.tab_messages` 那一行)。本任务通过测试把"底部 4 个 tab"作为契约锁定,防止后续回归。

- [ ] **Step 1: 创建测试文件**

写入:

```dart
// bottom_nav_shell_test.dart — 底部导航应为 4 个 tab(home/pickup/events/me)。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/bottom_nav_shell.dart';

Widget _shellWith4Branches() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => BottomNavShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const _Stub('H')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pickup', builder: (_, __) => const _Stub('P')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/events', builder: (_, __) => const _Stub('E')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/me', builder: (_, __) => const _Stub('M')),
          ]),
        ],
      ),
    ],
  );
  final t = ThemeController.test();
  return ProviderScope(
    child: MaterialApp.router(
      locale: const Locale('zh'),
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('renders exactly 4 bottom tabs', (tester) async {
    await tester.pumpWidget(_shellWith4Branches());
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('约球'), findsOneWidget);
    expect(find.text('赛事'), findsOneWidget);
    expect(find.text('我'), findsOneWidget);
    expect(find.text('消息'), findsNothing);
  });

  testWidgets('tapping a tab switches branch', (tester) async {
    await tester.pumpWidget(_shellWith4Branches());
    await tester.pumpAndSettle();

    expect(find.text('H'), findsOneWidget);
    await tester.tap(find.text('赛事'));
    await tester.pumpAndSettle();
    expect(find.text('E'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑测试**

Run: `flutter test test/widgets/bottom_nav_shell_test.dart`
Expected: 2 个 case 通过。

- [ ] **Step 3: 提交**

```bash
git add test/widgets/bottom_nav_shell_test.dart
git commit -m "test(nav): assert bottom nav has 4 tabs and switches branch"
```

---

## Task 8:改首页铃铛图标 + 订阅未读 provider

**Files:**
- Modify: `lib/features/home/home_screen.dart:171-200`

- [ ] **Step 1: 改铃铛图标和目标路由**

打开 `lib/features/home/home_screen.dart`,定位第 171-183 行:

```dart
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.notifications_none, color: context.tokens.ink, size: 20),
                ),
                Positioned(right: 4, top: 4, child: _WarnDot()),
              ],
            ),
          ),
```

替换为:

```dart
          GestureDetector(
            onTap: () => context.push('/inbox'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.inbox_outlined, color: context.tokens.ink, size: 20),
                ),
                Positioned(right: 4, top: 4, child: _InboxUnreadDot()),
              ],
            ),
          ),
```

- [ ] **Step 2: 新增 `_InboxUnreadDot` 并删除 `_WarnDot`**

找到 `_WarnDot` 类定义(约 190-200 行):

```dart
class _WarnDot extends StatelessWidget {
  const _WarnDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: context.tokens.warn, shape: BoxShape.circle),
    );
  }
}
```

替换为:

```dart
// Notifications are still demo data, so we don't yet have a provider for
// "any notification unread". Until notifications land real data, the dot
// renders whenever there's an unread DM OR unconditionally (for demo).
// The ref.watch() keeps the widget reactive so new DMs light it up.
class _InboxUnreadDot extends ConsumerWidget {
  const _InboxUnreadDot();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(messagesUnreadProvider);
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: context.tokens.warn,
        shape: BoxShape.circle,
      ),
    );
  }
}
```

- [ ] **Step 3: 如果 `home_screen.dart` 顶部没有 `flutter_riverpod` import,加上**

文件开头检查是否有:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

没有就加。另外加:
```dart
import '../../providers.dart';
```

- [ ] **Step 4: 编译检查**

Run: `flutter analyze lib/features/home/home_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat(home): replace bell with inbox icon; subscribe unread provider"
```

---

## Task 9:删除旧 `MessagesScreen` 和 `NotificationsScreen` 壳文件

**Files:**
- Delete: `lib/features/messages/messages_screen.dart`
- Delete: `lib/features/notifications/notifications_screen.dart`
- Modify: `test/features/messages/messages_swipe_actions_test.dart`(把 `MessagesScreen` 引用换成 `MessagesTab`)

- [ ] **Step 1: 确认没有其他 import**

Run: `grep -rn "messages_screen\|notifications_screen" lib/ test/ 2>/dev/null | grep -v 'lib/features/messages/messages_screen.dart\|lib/features/notifications/notifications_screen.dart'`
Expected: 只打印 `test/features/messages/messages_swipe_actions_test.dart` 里的引用;`lib/routes.dart` 应该已经在 Task 6 清理干净。

- [ ] **Step 2: 修改测试文件,改用 `MessagesTab`**

打开 `test/features/messages/messages_swipe_actions_test.dart`,修改:

第 10 行:
```dart
import 'package:kaiqiu_app/features/messages/messages_screen.dart';
```
改为:
```dart
import 'package:kaiqiu_app/features/messages/messages_tab.dart';
```

第 88 行(在 `_wrap` helper 的 `home:`):
```dart
      home: const MessagesScreen(),
```
改为:
```dart
      home: const Scaffold(body: SafeArea(child: MessagesTab())),
```

- [ ] **Step 3: 跑测试确认通过**

Run: `flutter test test/features/messages/messages_swipe_actions_test.dart`
Expected: 所有 case 绿。(widget 树结构不变,只是外壳从 `MessagesScreen` 换成 `Scaffold+MessagesTab`。)

- [ ] **Step 4: 删除两个壳文件**

```bash
rm lib/features/messages/messages_screen.dart
rm lib/features/notifications/notifications_screen.dart
```

- [ ] **Step 5: 编译 + 分析确认干净**

Run: `flutter analyze lib/ test/`
Expected: `No issues found!`

- [ ] **Step 6: 提交**

```bash
git add -u lib/features/messages/ lib/features/notifications/ test/features/messages/
git commit -m "refactor(messages,notifications): remove legacy Screen shells"
```

---

## Task 10:Widget 测试 — `inbox_screen_test.dart`

**Files:**
- Create: `test/features/inbox/inbox_screen_test.dart`

- [ ] **Step 1: 创建测试文件**

写入:

```dart
// inbox_screen_test.dart — 初始 tab / 切换 / 红点 / redirect 的 widget 测试。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/features/inbox/inbox_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/models/message.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

class _FakeMessagesRepo extends MessagesRepository {
  @override
  Future<List<ConversationRow>> listConversations() async => const [];
  @override
  Future<List<Message>> listMessages(String convId) async => const [];
  @override
  Future<Message> send(String convId, String body) =>
      throw UnimplementedError();
  @override
  Stream<List<Message>> streamMessages(String convId) => const Stream.empty();
  @override
  Future<String> createConversation({String? title, String kind = 'group'}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteConversation(String convId) async {}
  @override
  Future<void> clearMessages(String convId) async {}
  @override
  Future<void> markRead(String convId) async {}
  @override
  Future<void> markUnread(String convId, {int count = 1}) async {}
  @override
  Future<String> ensureEventConversation(String eventId) =>
      throw UnimplementedError();
}

ConversationRow _conv(String id, {int unread = 0}) => ConversationRow(
      id: id,
      title: 'Conv $id',
      kind: 'group',
      updatedAt: DateTime(2026, 4, 21, 10, 0),
      unread: unread,
    );

Widget _wrap({
  required List<ConversationRow> conversations,
  InboxTab initialTab = InboxTab.notifications,
}) {
  final t = ThemeController.test();
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWith((_) => LocalStoreNotifier()),
      messagesRepoProvider.overrideWithValue(_FakeMessagesRepo()),
      conversationsProvider.overrideWith((_) async => conversations),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: InboxScreen(initialTab: initialTab),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('defaults to notifications tab', (tester) async {
    await tester.pumpWidget(_wrap(conversations: const []));
    await tester.pumpAndSettle();
    // Notif sub-tab "全部 / 未读" is visible (NotificationsTab only).
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('未读'), findsOneWidget);
  });

  testWidgets('initialTab=messages shows messages content', (tester) async {
    await tester.pumpWidget(
      _wrap(
        conversations: [_conv('c1')],
        initialTab: InboxTab.messages,
      ),
    );
    await tester.pumpAndSettle();
    // Messages tab is shown: conversation title visible.
    expect(find.text('Conv c1'), findsOneWidget);
    // Notifications sub-tabs are NOT visible (hidden by IndexedStack).
    expect(find.text('全部'), findsNothing);
  });

  testWidgets('tapping messages tab switches header action to "+ new DM"',
      (tester) async {
    await tester.pumpWidget(_wrap(conversations: const []));
    await tester.pumpAndSettle();
    // Default (notifications) action is "全部已读" label, not "+".
    expect(find.byIcon(Icons.add), findsNothing);
    // Tap "消息" top tab.
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('messages unread provider → shows red dot on messages tab label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(conversations: [_conv('c1', unread: 2)]),
    );
    await tester.pumpAndSettle();
    // Unread dot: find the 6x6 accent-colored circle next to "消息" label.
    // Heuristic: assert at least one Container with shape: BoxShape.circle
    // within the _InboxTabButton row labeled "消息".
    final messagesLabel = find.text('消息');
    expect(messagesLabel, findsOneWidget);
    final dots = find.descendant(
      of: find.ancestor(of: messagesLabel, matching: find.byType(Row)),
      matching: find.byType(Container),
    );
    // Row contains label container + dot container when showDot is true.
    expect(dots.evaluate().length, greaterThanOrEqualTo(1));
  });
}
```

- [ ] **Step 2: 跑测试**

Run: `flutter test test/features/inbox/inbox_screen_test.dart`
Expected: 4 个 case 全部通过。

- [ ] **Step 3: 提交**

```bash
git add test/features/inbox/inbox_screen_test.dart
git commit -m "test(inbox): add widget tests for tabs, header action, unread dot"
```

---

## Task 11:全量回归 + 手工 smoke test

**Files:** 无新改动,只是验证。

- [ ] **Step 1: 跑全量测试**

Run: `flutter test`
Expected: 所有测试通过,包含新增的 `inbox_screen_test` 和 `bottom_nav_shell_test`。

- [ ] **Step 2: 静态分析**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: 手工 smoke(如果能跑应用)**

Run: `flutter run -d <device>`

手工验证清单:
- 启动后底部 4 个 tab,分别可切换。
- 首页右上角看到"收件箱"图标(`inbox_outlined`);旁边有红点。
- 点击收件箱图标 → 进入 `/inbox`,默认显示"通知" tab,顶部 action 是"全部已读",下面是原通知列表。
- 点击顶部"消息" tab → 切到消息 tab,header action 变为"+",下面是原消息列表。
- 点击"+" → 弹出新建 DM bottom sheet,行为与原 `/messages` 页一致。
- 滚到消息列表中部 → 切回通知 tab → 切回消息 tab → 滚动位置保留。
- 左滑某条消息 → `pin / mute / delete` 三按钮正常出现。
- 点击"全部已读" → 通知 tab 的未读变为 0,通知 tab 标签上的红点消失。
- 点击某条通知(route=`/me`) → 跳转到"我" tab(shell branch);返回(back)回到收件箱的通知 tab。
- 浏览器地址栏 / 深链 `myapp://messages` → 跳 `/inbox?tab=messages`。
- `myapp://notifications` → 跳 `/inbox?tab=notifications`。

- [ ] **Step 4: 清理最终 state(无需 commit)**

确认 `git status` 干净。

```bash
git status
```

Expected: `nothing to commit, working tree clean`

---

## 已知取舍(出自 spec)

- **通知未读降级**:通知侧仍是 demo 数据;`_InboxUnreadDot` 目前永远亮(因为 demo 通知总有未读)。这是 spec 中明确列出的取舍,等通知上真实 provider 时一并修复。
- **GlobalKey 跨组件读 `NotificationsTabState.unreadCount`**:在通知数据上 provider 化之前作为过渡方案。
- **旧路由兼容**:`/messages` 和 `/notifications` 保留为 redirect,不做下一步清理,等推送 / 深链消费者都迁移后再移除。
