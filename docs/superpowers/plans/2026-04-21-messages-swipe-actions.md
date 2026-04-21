# 消息列表侧滑操作 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `MessagesScreen` 的会话行上左滑露出「置顶 / 静音 / 删除」三个按钮；按钮标签随状态切换；删除保留确认弹窗；同一时刻同组内最多一行展开；长按菜单精简为仅「标为已读」。

**Architecture:** 引入 `flutter_slidable`；用 `Slidable` + `ActionPane(endActionPane)` + 3 个 `SlidableAction` 包裹现有 `_ThreadRow`；外层 `SlidableAutoCloseBehavior` 提供互斥行为。复用现有 `messagesRepoProvider.deleteConversation` 与 `LocalStore.togglePinned/toggleMuted`，复用已存在的 i18n 键，无需改数据层或 ARB。

**Tech Stack:** Flutter 3.x, Dart 3.11.5, `flutter_riverpod`, `flutter_slidable ^3.1.2`（新增依赖），`flutter_test`。

**Spec:** `docs/superpowers/specs/2026-04-21-messages-swipe-actions-design.md`

---

## File Structure

**新增：**

| 路径 | 职责 |
|---|---|
| `test/features/messages/messages_swipe_actions_test.dart` | 侧滑交互的 widget 测试（4 个用例） |

**修改：**

| 路径 | 变更 |
|---|---|
| `pubspec.yaml` | +`flutter_slidable: ^3.1.2` |
| `lib/features/messages/messages_screen.dart` | `ListView.builder` 外加 `SlidableAutoCloseBehavior`；`_ThreadRow.build` 用 `Slidable` 包裹原 `GestureDetector` 并挂 3 个 `SlidableAction`；`_showLongPressMenu` 精简为仅「标为已读」一项；新增文件顶层私有函数 `_confirmAndDelete(BuildContext, WidgetRef, ConversationRow)` |

**不动：** 数据层 (`messages_repository.dart`)、路由、ARB、主题 token、其他所有文件。

---

## 运行测试的命令约定

项目的 Flutter SDK 可能不在 `PATH` 中。每次跑命令前 prepend：
```bash
export PATH="$PATH:/home/coder/flutter/bin"
```
如已在 `PATH`，此行可略去。下文命令一律假设已 export。

---

## Task 1: 引入 `flutter_slidable` 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 在 pubspec.yaml 的 dependencies 块加入依赖**

打开 `pubspec.yaml`，在 `# Utilities` 块之后（`cached_network_image: ^3.4.1` 所在分组下方）新增两行：

```yaml
  # Swipeable list actions (messages screen).
  flutter_slidable: ^3.1.2
```

具体位置参考 pubspec 中相邻的 `share_plus: ^10.1.2` 行，以保持注释+空行风格统一。

- [ ] **Step 2: 执行 pub get**

Run:
```bash
flutter pub get 2>&1 | tail -5
```
Expected 输出包含 `Got dependencies!` 或 `No dependencies changed` 后紧跟的 `Got dependencies.`。如果拉取失败（网络），停下来汇报。

- [ ] **Step 3: 静态分析确认依赖可被解析**

Run:
```bash
flutter analyze lib/features/messages/messages_screen.dart 2>&1 | tail -10
```
Expected: `No issues found!`（该文件尚未 import slidable，所以应当干净）

- [ ] **Step 4: 提交依赖变更**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add flutter_slidable for message list swipe actions"
```

---

## Task 2: 首个失败测试 —— 左滑露出 3 个按钮的 icon

**Files:**
- Create: `test/features/messages/messages_swipe_actions_test.dart`

- [ ] **Step 1: 新建测试文件骨架（含首个用例）**

Create `test/features/messages/messages_swipe_actions_test.dart`:

```dart
// messages_swipe_actions_test.dart — 侧滑露出按钮 / 状态感知文案 /
// 删除确认 / 置顶切换 + 自动收起的 widget 测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/features/messages/messages_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

/// Fake repo — lets us avoid Supabase in tests and record deleteConversation.
class _FakeMessagesRepo extends MessagesRepository {
  final List<String> deletedIds = [];
  @override
  Future<void> deleteConversation(String convId) async {
    deletedIds.add(convId);
  }
  @override
  Future<void> markRead(String convId) async {}
}

ConversationRow _conv(String id, {String? title}) => ConversationRow(
      id: id,
      title: title ?? 'Conv $id',
      kind: 'group',
      updatedAt: DateTime(2026, 4, 21, 10, 0),
      unread: 0,
    );

Widget _wrap({
  required List<ConversationRow> conversations,
  required _FakeMessagesRepo repo,
}) {
  final t = ThemeController.test();
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWith((_) => LocalStoreNotifier()),
      messagesRepoProvider.overrideWithValue(repo),
      conversationsProvider.overrideWith((_) async => conversations),
    ],
    child: MaterialApp(
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const MessagesScreen(),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('left swipe on a thread row reveals pin/mute/delete icons',
      (tester) async {
    final repo = _FakeMessagesRepo();
    await tester.pumpWidget(_wrap(
      conversations: [_conv('c1', title: 'Alpha')],
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Before swipe: no action icons visible.
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // Drag the row to the left past the slidable threshold.
    await tester.drag(find.text('Alpha'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // All 3 action icons now visible (un-pinned / un-muted default state).
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -30
```
Expected: 测试失败。失败原因应是 `Expected: exactly one matching candidate / Actual: _NothingFound` —— 因为 `_ThreadRow` 还没有 `Slidable` 包装。

- [ ] **Step 3: 实现最小 Slidable 包装 —— 添加 import 并用 SlidableAutoCloseBehavior 包 ListView**

打开 `lib/features/messages/messages_screen.dart`：

在 imports 区加一行（放在 `flutter/material.dart` 之后的第 3 行位置）：
```dart
import 'package:flutter_slidable/flutter_slidable.dart';
```

找到 `ListView.builder(` 块（约第 90 行），在它外面套一层 `SlidableAutoCloseBehavior`：

**修改前：**
```dart
                  return RefreshIndicator(
                    color: context.tokens.accent,
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
```

**修改后：**
```dart
                  return RefreshIndicator(
                    color: context.tokens.accent,
                    backgroundColor: context.tokens.elev1,
                    onRefresh: () async =>
                        ref.invalidate(conversationsProvider),
                    child: SlidableAutoCloseBehavior(
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
                    ),
                  );
```

- [ ] **Step 4: 在 `_ThreadRow.build` 中用 Slidable 包裹现有 GestureDetector**

当前 `_ThreadRow.build`（约第 411–502 行）的结构为：
```dart
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
        children: [ /* avatar + title + snippet + time 等原有内容 */ ],
      ),
    ),
  );
}
```

做两处改动（不要动 `title` / `time` / `pinned` 三行，不要改 `Container` 内部 `decoration` 与 `Row`）：

**改动 A** — 在 `final pinned = ...` 下一行新增 `muted`：
```dart
    final pinned = LocalStore.isPinned(thread.id);
    final muted = LocalStore.isMuted(thread.id);   // ← 新增
    return Slidable(                               // ← 下面改动 B
```

**改动 B** — 把 `return GestureDetector(...);` 整块替换为如下 `return Slidable(...);`。`GestureDetector` 及其内部 `Container`/`Row` 原封不动地迁移到 `Slidable.child`：

```dart
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
          child: /* 保留原有 Row(...)，不要改 */,
        ),
      ),
    );
```

**具体说明：** `child: /* 保留原有 Row(...)，不要改 */` 处请把现有 `Container` 的 `child: Row(...)` 整段原样复制过来——从 `child: Row(` 到对应的 `),` 结束，约 60 行，包括 `Stack`/`Avatar`/unread badge/标题/时间/pin 图标等所有原有内容。不要动那部分的任何字符。

`_confirmAndDelete` 在 Task 4 才实现 —— 这一步暂时会让编译报错 `_confirmAndDelete isn't defined`。**先声明一个 stub**：

在 `messages_screen.dart` 文件底部（所有类定义之后）加：
```dart
Future<void> _confirmAndDelete(
  BuildContext context,
  WidgetRef ref,
  ConversationRow c,
) async {
  // Full implementation added in Task 4.
}
```

- [ ] **Step 5: 运行首个测试，确认通过**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -15
```
Expected: `All tests passed!`（1 个测试）

- [ ] **Step 6: 运行 flutter analyze 确保没新警告**

Run:
```bash
flutter analyze lib/features/messages/messages_screen.dart test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -10
```
Expected: `No issues found!`

- [ ] **Step 7: 提交**

```bash
git add lib/features/messages/messages_screen.dart test/features/messages/messages_swipe_actions_test.dart
git commit -m "feat(messages): reveal pin/mute/delete on left-swipe"
```

---

## Task 3: 测试 —— 置顶状态下按钮显示「取消置顶」

**Files:**
- Modify: `test/features/messages/messages_swipe_actions_test.dart`

- [ ] **Step 1: 添加失败测试**

在 `main()` 里，现有测试后面加：

```dart
  testWidgets('pinned conversation shows "unpin" label after swipe',
      (tester) async {
    // Arrange: pre-pin the conversation.
    await LocalStore.togglePinned('c1');
    expect(LocalStore.isPinned('c1'), isTrue);

    final repo = _FakeMessagesRepo();
    await tester.pumpWidget(_wrap(
      conversations: [_conv('c1', title: 'Alpha')],
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Alpha'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Filled pin icon + "取消置顶" label.
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(find.text('取消置顶'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行，确认它已经通过**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -15
```
Expected: `All tests passed!`（2 个测试）

实现中我们已经基于 `LocalStore.isPinned/isMuted` 动态选择 icon/label，所以此测试应直接通过；若失败说明实现有 bug，回到 Task 2 修复。

- [ ] **Step 3: 提交**

```bash
git add test/features/messages/messages_swipe_actions_test.dart
git commit -m "test(messages): assert state-aware swipe action labels"
```

---

## Task 4: 删除按钮 —— 弹确认 + 调 repo + toast

**Files:**
- Modify: `lib/features/messages/messages_screen.dart`
- Modify: `test/features/messages/messages_swipe_actions_test.dart`

- [ ] **Step 1: 添加失败测试**

在测试文件尾加：

```dart
  testWidgets('tapping delete shows confirm dialog and calls repo on confirm',
      (tester) async {
    final repo = _FakeMessagesRepo();
    await tester.pumpWidget(_wrap(
      conversations: [_conv('c1', title: 'Alpha')],
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Swipe.
    await tester.drag(find.text('Alpha'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Tap the delete icon button.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // AlertDialog with confirm copy appears.
    expect(find.text('删除此对话？'), findsOneWidget);
    expect(repo.deletedIds, isEmpty);

    // Tap the "删除" button inside the dialog (the second "删除" text on screen —
    // the first is the slidable action label still visible behind the dialog).
    // We target by widget type + ancestor: TextButton whose label is "删除".
    final deleteBtn = find.widgetWithText(TextButton, '删除');
    expect(deleteBtn, findsOneWidget);
    await tester.tap(deleteBtn);
    await tester.pumpAndSettle();

    // Repo was called with the right id.
    expect(repo.deletedIds, ['c1']);
  });
```

- [ ] **Step 2: 运行，确认失败**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart --plain-name "tapping delete" 2>&1 | tail -20
```
Expected: 失败，因为 `_confirmAndDelete` 现在是个 stub，不会弹 dialog。

- [ ] **Step 3: 实现 `_confirmAndDelete`**

替换 `messages_screen.dart` 末尾 Task 2 Step 4 里加的 stub：

```dart
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

- [ ] **Step 4: 运行该测试，确认通过**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart --plain-name "tapping delete" 2>&1 | tail -15
```
Expected: `All tests passed!`（1 个匹配测试）

- [ ] **Step 5: 运行全部 messages swipe 测试**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -10
```
Expected: `All tests passed!`（3 个测试）

- [ ] **Step 6: 提交**

```bash
git add lib/features/messages/messages_screen.dart test/features/messages/messages_swipe_actions_test.dart
git commit -m "feat(messages): swipe-delete opens confirm dialog and deletes"
```

---

## Task 5: 置顶按钮 —— 测试会改变 `LocalStore.isPinned`

**Files:**
- Modify: `test/features/messages/messages_swipe_actions_test.dart`

- [ ] **Step 1: 添加失败测试**

在测试文件尾加：

```dart
  testWidgets('tapping pin action toggles LocalStore.isPinned',
      (tester) async {
    final repo = _FakeMessagesRepo();
    await tester.pumpWidget(_wrap(
      conversations: [_conv('c1', title: 'Alpha')],
      repo: repo,
    ));
    await tester.pumpAndSettle();

    expect(LocalStore.isPinned('c1'), isFalse);

    await tester.drag(find.text('Alpha'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Tap the pin icon.
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pumpAndSettle();

    expect(LocalStore.isPinned('c1'), isTrue);
  });
```

- [ ] **Step 2: 运行，确认通过**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -10
```
Expected: `All tests passed!`（4 个测试）

实现里 `onPressed` 已经调用 `LocalStore.togglePinned`，所以此测试应直接通过。若失败检查 Task 2 实现。

- [ ] **Step 3: 提交**

```bash
git add test/features/messages/messages_swipe_actions_test.dart
git commit -m "test(messages): assert pin action toggles LocalStore"
```

---

## Task 6: 精简长按菜单为仅「标为已读」

**Files:**
- Modify: `lib/features/messages/messages_screen.dart`

- [ ] **Step 1: 删除长按菜单中的「置顶」「静音」「删除」三个 ListTile**

打开 `lib/features/messages/messages_screen.dart`，找到 `_showLongPressMenu` 方法（约第 266 行）。当前 `Column` 的 `children` 里有这样的顺序：
```
SizedBox(height: 12)       // drag handle spacer
Center(drag handle bar)    // 抓手
SizedBox(height: 6)
ListTile(置顶/取消置顶)     ← 删除
ListTile(静音/取消静音)     ← 删除
ListTile(标为已读)          ← 保留
ListTile(删除)              ← 删除
SizedBox(height: 10)
```

删除三个 ListTile 及其 `onTap` 内部逻辑（行号约为 294–325 的"置顶"、326–340 的"静音"、341–389 的"删除"），**只保留**「标为已读」那一项。

"删除" ListTile 里原本调用 `showDialog + messagesRepoProvider.deleteConversation(c.id)` 的那一整段逻辑可以彻底丢弃 —— 该逻辑已经迁移到文件尾的 `_confirmAndDelete` 函数。

最终 `_showLongPressMenu` 中 `Column` 的 `children` 应为：
```dart
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
```

- [ ] **Step 2: 检查是否有因删除导入变为未使用的 import / 未引用的本地变量**

长按菜单过去引用过 `LocalStore.isPinned/isMuted/togglePinned/toggleMuted`（但我们现在在 `_ThreadRow.build` 中仍引用），`showDialog`（`_confirmAndDelete` 仍用），`showToast`（同）。所以没有 import 需要移除。

Run:
```bash
flutter analyze lib/features/messages/messages_screen.dart 2>&1 | tail -15
```
Expected: `No issues found!`。若出现 `unused_import` 或 `unused_element`，按提示删除即可。

- [ ] **Step 3: 运行测试套件确保功能没破**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -10
```
Expected: `All tests passed!`（4 个测试）

- [ ] **Step 4: 手动核查 long-press 菜单（可选）**

启动 app，进入消息页，长按任意会话，应只看到「标为已读」一项（加顶部 drag handle）。若环境不便起 app 可跳过。

- [ ] **Step 5: 提交**

```bash
git add lib/features/messages/messages_screen.dart
git commit -m "refactor(messages): trim long-press menu to mark-as-read only"
```

---

## Task 7: 同组互斥 —— 打开 A 行后打开 B 行时 A 收起

**Files:**
- Modify: `test/features/messages/messages_swipe_actions_test.dart`

`SlidableAutoCloseBehavior` + 相同 `groupTag: 'messages'` 在 Task 2 Step 3/4 已经写入实现，此任务只补一个测试验证。

- [ ] **Step 1: 添加失败测试**

在测试文件尾加：

```dart
  testWidgets('opening another row auto-closes the first', (tester) async {
    final repo = _FakeMessagesRepo();
    await tester.pumpWidget(_wrap(
      conversations: [
        _conv('c1', title: 'Alpha'),
        _conv('c2', title: 'Bravo'),
      ],
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Open Alpha.
    await tester.drag(find.text('Alpha'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Open Bravo.
    await tester.drag(find.text('Bravo'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Only one delete icon on screen (Bravo's) — Alpha's pane closed.
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
```

- [ ] **Step 2: 运行，确认通过**

Run:
```bash
flutter test test/features/messages/messages_swipe_actions_test.dart 2>&1 | tail -10
```
Expected: `All tests passed!`（5 个测试）

`SlidableAutoCloseBehavior` 已在 Task 2 Step 3 加在 `ListView.builder` 外，所以行为应已具备。若失败，确认 `groupTag: 'messages'` 且每个 `Slidable` 都带 `key: ValueKey(thread.id)`。

- [ ] **Step 3: 提交**

```bash
git add test/features/messages/messages_swipe_actions_test.dart
git commit -m "test(messages): assert single-open invariant across rows"
```

---

## Task 8: 全局验证 & 收尾

**Files:** 无新增，只跑命令。

- [ ] **Step 1: 跑整个测试套件，确保没有回归**

Run:
```bash
flutter test 2>&1 | tail -15
```
Expected: `All tests passed!` 包含本次新增的 5 个用例。若有其他文件失败：
- 如果是与 messages 无关的失败（eg. `wc_live_screen_test.dart`），可能是并发会话的在途工作引入的；**不要修**，停下来汇报。
- 如果与本次改动相关，立刻回到对应任务修复，修好再继续。

- [ ] **Step 2: `flutter analyze` 全局干净**

Run:
```bash
flutter analyze 2>&1 | tail -10
```
Expected: `No issues found!` 或与本次改动无关的 info-level 提示（比如其他文件历史遗留）。

- [ ] **Step 3: 目视检查 diff 没混入无关改动**

Run:
```bash
git log --oneline -10
git diff HEAD~7 -- pubspec.yaml lib/features/messages/messages_screen.dart | head -50
```
核对：只有 `pubspec.yaml` 加了 `flutter_slidable`；`messages_screen.dart` 的改动限于 `_ThreadRow.build`、`_showLongPressMenu`、新增 import、新增 `_confirmAndDelete`；没有误删其他无关代码。

- [ ] **Step 4: 推送（不要 force）**

```bash
git push origin main 2>&1 | tail -5
```
Expected: `main -> main`，无错误。若被拒（因远端有新 commit），`git pull --rebase origin main` 后再推。

- [ ] **Step 5: 更新 spec 文档状态（可选）**

若需要，把 `docs/superpowers/specs/2026-04-21-messages-swipe-actions-design.md` 第 4 行 `状态：待实现` 改为 `状态：已实现`，单独提交：
```bash
git add docs/superpowers/specs/2026-04-21-messages-swipe-actions-design.md
git commit -m "docs(spec): mark messages swipe-to-delete as implemented"
git push origin main
```

---

## 完成标准

- [x] `flutter_slidable: ^3.1.2` 在 `pubspec.yaml`
- [x] `_ThreadRow` 左滑露出 3 个按钮（置顶/静音/删除）
- [x] 按钮 icon + label 随 `LocalStore.isPinned/isMuted` 动态切换
- [x] 删除按钮弹出确认对话框，确认后调 `deleteConversation` + toast
- [x] 同组内最多一行展开（点击/滑动其他行自动收起）
- [x] 长按菜单精简为仅「标为已读」
- [x] 新增 5 个 widget 测试全部通过
- [x] `flutter analyze` 干净
- [x] 未新增 ARB 键、未改数据层、未改路由
