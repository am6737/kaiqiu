# 消息列表侧滑操作（Messages Swipe Actions）设计

日期：2026-04-21
状态：待实现

## 背景

消息页 `lib/features/messages/messages_screen.dart` 的会话行（`_ThreadRow`，行 398）当前只支持两种手势：点击进入聊天、长按弹出一个包含 4 项（置顶 / 静音 / 标为已读 / 删除）的 bottom sheet 菜单。删除需要两步：长按 → 选"删除" → 确认弹窗，不符合 IM 类产品的主流操作预期。

数据层 `messagesRepoProvider.deleteConversation(convId)` 已实现级联删除，`LocalStore.togglePinned/toggleMuted` 的本地开关也已就绪——功能都在，只缺一个更快捷的入口。

## 目标

1. 在会话行上左滑即可露出「置顶 / 静音 / 删除」三个按钮，一次手势即可触达高频操作。
2. 按钮文案与图标随当前状态切换：已置顶的会话显示"取消置顶"，已静音的显示"取消静音"。
3. 删除操作保留二次确认，与现有行为一致（防误触）。
4. 同一列表中，任意时刻最多只有一行处于展开态（iOS 风格）。

## 非目标

- 不实现"一滑到底直接删除"的 Gmail 风格动作；删除始终需要点击按钮 + 确认弹窗。
- 不实现撤销删除（undo snackbar）。
- 不在侧滑面板里加入"标为已读"——该动作保留在长按菜单中作为低频入口。
- 不改动 `deleteConversation` 的后端级联逻辑。
- 不改动 `_ThreadRow` 的视觉样式（圆角、padding、置顶底色等）。

## 架构总览

```
UI
└── lib/features/messages/messages_screen.dart
    ├── ListView.builder 外层包 SlidableAutoCloseBehavior
    ├── _ThreadRow.build 用 Slidable 包裹原 GestureDetector
    └── _showLongPressMenu 精简为仅"标为已读"一项

依赖
└── pubspec.yaml
    └── flutter_slidable: ^3.1.2  （新增）
```

数据层、i18n、主题 token 均不新增——所有字符串（`common_pin/unpin/mute/unmute/delete`、`messages_delete_confirm`、`messages_deleted`、`messages_long_press_actions_mark_read`）和颜色 token（`accent/inkSub/danger`）均已存在。

## 交互详细设计

### 滑动面板

- 使用 `flutter_slidable` 的 `Slidable` 包裹 `_ThreadRow`，挂 `endActionPane`（仅右侧滑动展开，不支持左滑）。
- `key: ValueKey(thread.id)` 确保列表重排时状态不错位。
- `groupTag: 'messages'` + 外层 `SlidableAutoCloseBehavior`：滑开 A 行后点击/滑开 B 行，A 行自动收起。
- `motion: const BehindMotion()`：按钮预先铺在底层，会话行向左滑动露出；视觉更稳定。
- `extentRatio: 0.75`：三个按钮共占行宽 75%，每个约 25%。
- `dismissible`: **不启用**（不需要"滑到底直接删除"的行为）。

### 三个按钮（从内到外，即从左到右显示顺序）

| 索引 | 操作 | 图标 | 未激活态（前景/背景） | 已激活态（前景/背景） | 点击行为 |
|---|---|---|---|---|---|
| 0 | 置顶 / 取消置顶 | `push_pin_outlined` / `push_pin` | `tokens.ink` / `tokens.elev2` | `tokens.bg` / `tokens.accent` | `await LocalStore.togglePinned(c.id);` 面板自动收起（调用 `Slidable.of(context)?.close()`） |
| 1 | 静音 / 取消静音 | `notifications_off_outlined` / `notifications_off` | `tokens.ink` / `tokens.elev2` | `tokens.bg` / `tokens.inkSub` | `await LocalStore.toggleMuted(c.id);` 面板自动收起 |
| 2 | 删除 | `delete_outline` | `Colors.white` / `tokens.danger` | （无激活态） | 弹出 `AlertDialog` 确认 → `messagesRepoProvider.deleteConversation(c.id)` + `ref.invalidate(conversationsProvider)` + 成功 toast |

- 置顶/静音按钮的**标签**通过 `LocalStore.isPinned(c.id)` / `isMuted(c.id)` 在每次构建时动态解析：
  ```dart
  label: LocalStore.isPinned(c.id) ? l.common_unpin : l.common_pin,
  ```
- 若主题 token 中 `tokens.elev2`、`tokens.bg` 等色值与实际主题存在对比度冲突，实现时以「满足 WCAG AA 对比度」为准调整，但不新增 token。
- 所有按钮用 `SlidableAction`（`flutter_slidable` 内建），避免自造。

### 删除确认

复用当前 `_showLongPressMenu` 中的确认对话框逻辑（行 350–388）：
```
AlertDialog( content: l.messages_delete_confirm ) → [取消] [删除]
```
抽取为私有函数 `_confirmAndDelete(BuildContext context, WidgetRef ref, ConversationRow c)`，放在 `messages_screen.dart` 文件顶层（非 `_MessagesScreenState` 的成员），供 `_ThreadRow` 内部直接调用。

### 长按菜单精简

`_showLongPressMenu` 删除三个 ListTile（置顶、静音、删除），保留仅「标为已读」一项。bottom sheet 的 drag handle 保留。

## 状态流

```
用户左滑 _ThreadRow
        ↓
  Slidable 展开 endActionPane（75% 行宽）
        ↓
[点击置顶]           [点击静音]           [点击删除]
        ↓                   ↓                   ↓
togglePinned         toggleMuted         showDialog 确认
   + close()           + close()              ↓
                                      confirm==true?
                                            ↓ yes
                                   deleteConversation
                                            ↓
                                   invalidate provider
                                            ↓
                                   showToast 已删除
```

列表本身由 `conversationsProvider` 驱动；置顶/静音改动本地存储后不需 invalidate（`ref.watch(localStoreProvider)` 已在 `_ThreadRow.build` 头部订阅）。

## 错误处理

- `deleteConversation` 抛异常 → 捕获并 `showToast('$e', error: true)`，列表不变。
- 置顶/静音写 `SharedPreferences` 失败概率极低，沿用现有代码不额外处理。
- 滑开某行时列表刷新（realtime 事件）→ `ValueKey(thread.id)` 保证状态正确迁移；若行被删除，Slidable 随 widget 销毁。

## 测试

新建 `test/features/messages/messages_swipe_actions_test.dart`：

1. **露出面板**：`pumpWidget` 渲染一个包含两行会话的 `MessagesScreen`，`tester.drag(find.byKey(...), const Offset(-300, 0))`，断言 3 个 `SlidableAction` 出现。
2. **删除流程**：滑开后 `tap` 删除按钮 → 断言 `AlertDialog` 出现 → `tap` 确认 → 验证 `deleteConversation` 被调用（用 mock repo）。
3. **置顶切换**：滑开 → `tap` 置顶按钮 → `expect(LocalStore.isPinned(id), isTrue)`。
4. **状态感知文案**：预置 `LocalStore.togglePinned` 让某行已置顶，滑开后断言按钮文案是 `common_unpin`。
5. **自动收起**：滑开行 A 后滑开行 B，断言 A 行面板已关闭。

测试需要 mock `messagesRepoProvider` 和 `conversationsProvider`，参考现有 `test/features/` 下的 widget 测试风格。

## 改动范围汇总

- `pubspec.yaml` — 新增 `flutter_slidable: ^3.1.2`
- `lib/features/messages/messages_screen.dart` — 改动 `_ThreadRow.build`、`_showLongPressMenu`、新增 `_confirmAndDelete`；`ListView.builder` 外层加 `SlidableAutoCloseBehavior`
- `test/features/messages/messages_swipe_actions_test.dart` — 新建
- **无** 新增 ARB 键、新增 provider、新增 repository 方法、新增路由

## 风险 & 取舍

- **新增 npm/pub 依赖**：`flutter_slidable` 是 pub.dev 头部包（3.9k likes，稳定维护），风险可控。自研同等体验投入产出比低。
- **按钮颜色与主题 token 的贴合**：激活态色需要在实现时目视核对深色/浅色两模；若 token 不够，用现有 token 的不透明叠加（如 `accent.withOpacity(0.15)`）而非新增。
- **误触风险**：删除始终弹确认 + 滑动需要超过阈值触发，组合起来与长按菜单同等安全。
- **与 Chat 页返回后的列表刷新**：已有 `ref.invalidate(conversationsProvider)` 覆盖，无需新逻辑。
