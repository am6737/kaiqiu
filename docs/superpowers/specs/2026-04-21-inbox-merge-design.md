# 收件箱合并（Inbox Merge：消息 + 通知）设计

日期：2026-04-21
状态：待实现

## 背景

当前底部导航有 5 个 tab：`首页 / Pickup / 赛事 / 消息 / 我`；首页右上角的铃铛图标会 push 到独立的 `/notifications` 页面（内含 `全部 / 未读` 子切换）。消息和通知被分成两个完全独立的入口：

- `lib/widgets/bottom_nav_shell.dart`：5-tab 底部导航
- `lib/features/messages/messages_screen.dart`：`/messages` StatefulShellBranch
- `lib/features/notifications/notifications_screen.dart`：`/notifications` 全屏 overlay
- `lib/features/home/home_screen.dart:171-183`：首页右上角铃铛，跳转 `/notifications`

两类内容都是"别人发给我的消息"，性质相近、切换频繁，独立一个底部 tab 对"消息"这种非首要动作来说过重。把两者合并到一个"收件箱"页面，一方面释放底部 tab 位，一方面统一心智模型（Gmail / Instagram / X 均采用这种收件箱形态）。

## 目标

1. 将"消息"和"通知"合并到一个 `InboxScreen`（`/inbox`），顶部两 tab：`消息 | 通知`。
2. 底部导航从 5 tab 减为 4 tab（`首页 / Pickup / 赛事 / 我`），均分底部宽度。
3. 首页右上角单一入口：铃铛图标替换为收件箱图标，点击进 `/inbox`，默认打开"通知" tab。
4. 旧路径 `/messages`、`/notifications` 保留为 redirect，不破坏已发送的推送 / 深链。
5. 消息未读、通知未读由两个 tab label 独立呈现；首页图标红点表示"任一未读"。
6. 新建 DM 按钮随 tab 动态切换到 header action 区（消息 tab）；通知 tab 保留"全部已读"按钮。
7. 保留现有所有下层能力：pull-to-refresh、左滑操作、`/chat/:convId` 的 push 与 pop、通知路由跳转。

## 非目标

- 不合并"消息"与"通知"的未读计数到一个统一数字。
- 不重构 `messagesRepository` 或 `conversationsProvider`（业务逻辑零改动）。
- 不新增"已读/未读筛选"到消息 tab（消息本身在列表上已有未读点）。
- 不做 FAB / 左右滑切换 tab / 智能默认 tab 这些增强。
- 不实现"收到 DM"类型的新通知条目；当前 demo 数据里没有，将来如果加，按 `route=/chat/:convId` push 即可，无需本次设计覆盖。
- 不改变 `/chat/:convId` 路由行为。
- 不改 `messages_screen.dart` 的业务 provider、Slidable 交互或新建 DM sheet。

## 架构总览

```
lib/features/
├── inbox/
│   └── inbox_screen.dart                (新增 InboxScreen —— 路由 /inbox 的容器)
├── messages/
│   └── messages_tab.dart                (新增 —— 从 MessagesScreen 抽出的可嵌入列表；messages_screen.dart 删除)
├── notifications/
│   └── notifications_tab.dart           (新增 —— 从 NotificationsScreen 抽出的可嵌入列表；notifications_screen.dart 删除)
└── home/
    └── home_screen.dart                 (改：铃铛 → inbox 图标 → /inbox)

lib/widgets/
└── bottom_nav_shell.dart                (改：5 tab → 4 tab)

lib/routes.dart                          (改：删 /messages branch；/messages、/notifications 改为 redirect；新增 /inbox)

lib/l10n/arb/app_en.arb, app_zh.arb      (新增：inbox_title / inbox_tab_messages / inbox_tab_notifications)
```

数据层、provider、消息 repository、SharedPreferences 本地存储均不改动。

## 路由结构

```dart
// routes.dart
GoRoute(
  path: '/inbox',
  builder: (_, s) => InboxScreen(
    initialTab: switch (s.uri.queryParameters['tab']) {
      'messages' => InboxTab.messages,
      _ => InboxTab.notifications,   // 默认通知
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

- `/inbox` 作为全屏 overlay（不是 shell branch），保持和 `/notifications` 原本的层级一致 —— 从首页 push 进入、pop 返回首页。
- `/inbox?tab=messages` 和 `/inbox?tab=notifications` 通过 query 选择初始 tab；没有 tab 参数时默认 `notifications`。
- `InboxTab` 为 `inbox_screen.dart` 内部枚举：`enum InboxTab { messages, notifications }`。
- 从 `/messages` branch 删除：删除 `routes.dart:80-87` 的 `StatefulShellBranch`；`StatefulShellRoute` 的 branches 从 5 个减至 4 个。

## `InboxScreen` 布局

```
┌─────────────────────────────────────────────┐
│ PageTitleBar                                 │
│   [← back]  收件箱 (inbox_title)    [action] │  ← action 随 tab 切换
├─────────────────────────────────────────────┤
│   ┌─────────────┬─────────────┐              │
│   │  消息 ● 3   │  通知 ● 2    │  ← 顶层 tab │
│   └─────────────┴─────────────┘              │
├─────────────────────────────────────────────┤
│                                              │
│     IndexedStack(index: currentTab.index,    │
│       children: [MessagesTab, NotificationsTab]) │
│                                              │
└─────────────────────────────────────────────┘
```

- 外层：`Scaffold` + `SafeArea`(与现 `NotificationsScreen` 一致)。
- 顶部：`PageTitleBar(title: l.inbox_title, onBack: () => context.pop(), actions: [...])`。
- Tab 切换：沿用 `notifications_screen.dart:207-235` 的 `_Tab` 样式（Container + 选中态底色），不用 `TabBar`/`TabBarView`。两个 tab 等宽（`Expanded`）。**纯点击切换，不支持左右滑手势**，视觉上与原通知页 `全部 / 未读` 一致。
- Tab label 带未读红点：label 右侧 6px 圆点，红点色 `tokens.accent`，仅当对应 tab 内容有未读时显示（与 `_NotifRow` 里的未读点大小一致,见 `notifications_screen.dart:288-296`）。
- 内容区：`IndexedStack`，两个子 widget 同时活着但只显示一个，**切换 tab 时滚动位置和子 state 保留**。

### Header action 动态切换

```dart
actions: switch (_currentTab) {
  InboxTab.messages => [_NewDmButton()],          // 原 MessagesScreen 里的 + 按钮
  InboxTab.notifications => [_MarkAllReadButton()], // 原 NotificationsScreen 里的按钮
},
```

- `_NewDmButton`：复用 `messages_screen.dart` 里 `_showNewSheet(context, ref)` 的调用（需要将该函数从私有提升为顶层或通过 `MessagesTab` 暴露；见"改动清单"）。
- `_MarkAllReadButton`：复用 `notifications_screen.dart` 里 `setState(() => _read.addAll(...))` 逻辑（搬到 `NotificationsTab` 的 state 中）。

## `MessagesTab` widget

从 `MessagesScreen` 抽取内容区（现文件 `messages_screen.dart:30-156`），去掉 `Scaffold` + 顶部 header，只保留：

- `conversationsProvider` 订阅
- 空态 / 加载 / 错误三态
- 排序（pinned 优先）
- `SlidableAutoCloseBehavior` + `ListView.builder` + `_ThreadRow`
- pull-to-refresh

新建 `lib/features/messages/messages_tab.dart`：

```dart
class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) { ... }
}
```

- 底部 padding：原 `ListView` 里是 `bottom: 100`（为底部 tab bar 让位）。收件箱是 overlay，没有底部 tab bar，改为 `bottom: 24`。
- 其他业务逻辑（`_ThreadRow`、`_showLongPressMenu`、`_confirmAndDelete`、`_EmptyState` 等私有组件）从 `messages_screen.dart` 迁入 `messages_tab.dart`。`new_dm_sheet.dart` 导入不变。
- `context.push('/chat/${id}')` 路径不变；从 chat 页 `pop()` 回到 `/inbox`（消息 tab）——行为与原 `/messages` 一致。

## `NotificationsTab` widget

从 `NotificationsScreen` 抽取内容区（`notifications_screen.dart:40-117`），去掉 `Scaffold` 和顶部 `PageTitleBar`，只保留：

- `_unreadOnly` 状态 + `_read` 已读集合
- `全部 / 未读` 子切换（原 `_Tab` 行）
- 分组的 `ListView` + `_NotifRow`

新建 `lib/features/notifications/notifications_tab.dart`：

```dart
class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});
  @override
  ConsumerState<NotificationsTab> createState() => NotificationsTabState();
}

class NotificationsTabState extends ConsumerState<NotificationsTab> {
  bool _unreadOnly = false;
  final Set<String> _read = {};
  int get unreadCount => _demoItems(context.l10n).where((n) => !_read.contains(n.id)).length;
  void markAllRead() => setState(() => _read.addAll(_demoItems(context.l10n).map((i) => i.id)));
  ...
}
```

- `_branchRoots`：从 `{'/home','/pickup','/events','/messages','/me'}` 改为 `{'/home','/pickup','/events','/me'}`。点击"收到 DM"类通知时若 `route == '/messages'`（历史兼容），用 `context.go('/inbox?tab=messages')`。
- `markAllRead()` 和 `unreadCount` 作为 public 方法供 `InboxScreen` 通过 `GlobalKey<NotificationsTabState>` 调用（用于 header action 和 tab label 红点）。
- 子 tab "全部 / 未读" 样式、`_Notif`、`_NotifRow`、`_Empty`、`_demoItems` 全部搬过来。

## 未读信号数据流

```
         ┌───────────────────────┐
         │  conversationsProvider │  (existing, unread: int per row)
         └──────────┬────────────┘
                    │
           messagesUnreadProvider (新增: Provider<bool>)
                    │  = list.any((c) => c.unread > 0)
                    ▼
┌──────────────────────────────────┐     ┌──────────────────────────┐
│ HomeScreen 铃铛图标红点:         │     │ InboxScreen 消息 tab 红点:│
│   _WarnDot 替换为                │     │   在 InboxScreen 内部     │
│   Consumer(                      │     │   ref.watch(messagesUnread│
│     (ref) => messagesUnread       │     │            Provider)      │
│              || notifsUnread)     │     │   决定小点是否渲染         │
└──────────────────────────────────┘     └──────────────────────────┘

通知未读：
  NotificationsTabState._read 为"已读集合"，
  通过 GlobalKey 暴露 unreadCount → InboxScreen widget tree
  首页铃铛红点暂用 provider-free 的降级：demo 通知数据 - SharedPreferences 持久化的 read id 集合
  （本次本 spec 只要求"demo 未读 > 0 就亮"——因为通知本身还是 demo 数据；正式上线时通知有自己的 provider 再接入）
```

- 新增 `lib/providers.dart` 内：
  ```dart
  final messagesUnreadProvider = Provider<bool>((ref) {
    final async = ref.watch(conversationsProvider);
    return async.maybeWhen(
      data: (list) => list.any((c) => c.unread > 0),
      orElse: () => false,
    );
  });
  ```
- 通知未读目前仍是内存状态（`_read` 集合），重启 app 会重置。这与现状一致，本次不做持久化改造。
- 首页铃铛红点：用一个 `ConsumerWidget` 替换 `_WarnDot()`，订阅 `messagesUnreadProvider`；通知未读暂为常量 `true`（现 demo 数据总有未读条目），待后续通知落地 provider 时再接入。**这是本次的已知取舍**（见"风险 & 取舍"）。

### Tab label 红点

```dart
Expanded(
  child: _InboxTab(
    label: l.inbox_tab_messages,
    showDot: ref.watch(messagesUnreadProvider),
    active: _current == InboxTab.messages,
    onTap: () => setState(() => _current = InboxTab.messages),
  ),
),
Expanded(
  child: _InboxTab(
    label: l.inbox_tab_notifications,
    showDot: _notifsKey.currentState?.unreadCount != null
        && _notifsKey.currentState!.unreadCount > 0,
    active: _current == InboxTab.notifications,
    onTap: () => setState(() => _current = InboxTab.notifications),
  ),
),
```

- `_InboxTab` 复刻 `notifications_screen.dart` 的 `_Tab`，只在 label 右侧多画一个 6×6 圆点（showDot=true 时）。
- 通知 tab 红点通过 `GlobalKey<NotificationsTabState>` 读；每次 `setState` 重建顶层时同步刷新。点击"全部已读"后红点立刻消失。

## 首页铃铛改造

`lib/features/home/home_screen.dart:171-183`：

- `Icons.notifications_none` → `Icons.inbox_outlined`（激活态对称：`Icons.inbox`，但目前不用区分激活）。
- `context.push('/notifications')` → `context.push('/inbox')`（默认通知 tab）。
- `_WarnDot()` 替换为新的 `_InboxUnreadDot()`，它是 `ConsumerWidget`，根据 `messagesUnreadProvider || _hasUnreadNotifs()` 决定显隐。`_hasUnreadNotifs()` 当前返回 `true`（demo 期降级，见上）。

## 底部导航改造

`lib/widgets/bottom_nav_shell.dart`：
- `tabs` 数组第 4 项（消息）删除：
  ```dart
  final tabs = <(String, IconData, IconData)>[
    (l.tab_home, Icons.home_outlined, Icons.home),
    (l.tab_pickup, Icons.map_outlined, Icons.map),
    (l.tab_events, Icons.emoji_events_outlined, Icons.emoji_events),
    (l.tab_me, Icons.person_outline, Icons.person),
  ];
  ```
- 其他代码不变，`shell.currentIndex` 和 `goBranch(i)` 自动适配 4 branches。
- `Expanded` 会让 4 个 tab 均分底部宽度，每个 tab 宽度从 ~20% 提升到 25%。

## l10n

新增 ARB 键（`lib/l10n/arb/app_en.arb`、`app_zh.arb`）：

```json
{
  "inbox_title": "Inbox" / "收件箱",
  "inbox_tab_messages": "Messages" / "消息",
  "inbox_tab_notifications": "Notifications" / "通知"
}
```

- `tab_messages`：实现阶段先 `grep -r 'tab_messages' lib/` 确认引用；如果仅 `bottom_nav_shell.dart` 使用，删除该 key;否则保留。新架构不再由底部导航引用。
- `inbox_tab_messages` 和 `tab_messages` 取值可以相同（中文都是"消息"），分两个 key 是为语义定位 + 将来分化文案。

## 交互时序

### 点击铃铛 → 进入收件箱（默认通知）

```
HomeScreen: tap _InboxButton
  → context.push('/inbox')
  → GoRouter 匹配 /inbox，InboxScreen 构建
  → _current = InboxTab.notifications（默认）
  → IndexedStack 显示 NotificationsTab
  → header action = MarkAllRead
```

### 从通知列表跳转到其他页面

```
用户点击一条通知行
  → NotificationsTab 内部：
      setState(_read.add(n.id))      // 本地标已读
      route = n.route
      if (_branchRoots.contains(route)) context.go(route)
      else context.push(route)
  → 返回收件箱时（pop）通知 tab 仍在，_read 保留
```

### 从消息 tab 打开一条会话

```
用户点击会话行
  → MessagesTab 内部：context.push('/chat/${convId}')
  → ChatScreen 正常展示
  → ChatScreen 返回（pop）→ 回到 InboxScreen，消息 tab active
```

### 推送 / 深链点击 `/notifications` 或 `/messages`

```
deep link /messages
  → redirect /inbox?tab=messages
  → InboxScreen(initialTab: messages)

deep link /notifications
  → redirect /inbox?tab=notifications
  → InboxScreen(initialTab: notifications)
```

### 切换 tab

```
用户点击 "消息" _InboxTab
  → setState(_current = InboxTab.messages)
  → IndexedStack 切换到 MessagesTab（滚动/state 保留）
  → header action 切换为 NewDmButton
  → tab label 红点同步刷新
```

## 错误处理

- `MessagesTab` 内的错误态沿用 `messages_screen.dart` 现有的 error UI（`error_outline` + 重试按钮），不改。
- `NotificationsTab` 内没有异步错误路径（demo 数据），维持现状。
- `/inbox?tab=xxx` 的未知 `tab` 值 → fallback 到 notifications（`switch` 默认分支）。
- 从 `/messages` redirect 到 `/inbox?tab=messages` 时,若 GoRouter 历史栈有异常,允许 `router.go` 重置;不做额外防御。

## 测试

新建 `test/features/inbox/inbox_screen_test.dart`：

1. **初始 tab 判断**
   - 渲染 `/inbox` → 默认显示 NotificationsTab（通知条目可见）。
   - 渲染 `/inbox?tab=messages` → 显示 MessagesTab（会话行可见）。
   - 渲染 `/inbox?tab=garbage` → 显示 NotificationsTab。

2. **Tab 切换**
   - 点击"消息" tab → MessagesTab 可见，header action 为新建 DM 按钮。
   - 点击"通知" tab → NotificationsTab 可见，header action 为"全部已读"。

3. **Tab state 保留**
   - 滚动消息列表到中间 → 切换到通知 tab → 切回消息 tab → 验证滚动位置仍在中间。

4. **未读红点**
   - Mock `conversationsProvider` 返回含 `unread: 2` 的会话 → 消息 tab label 显示小红点。
   - Mock 所有会话 `unread: 0` → 消息 tab label 无红点。

5. **路由 redirect**
   - `context.go('/messages')` → 期望路径解析为 `/inbox?tab=messages`。
   - `context.go('/notifications')` → 期望路径解析为 `/inbox?tab=notifications`。

6. **底部导航**
   - 新建 `test/widgets/bottom_nav_shell_test.dart`：断言渲染出 4 个 tab，label 分别为 home/pickup/events/me。

7. **首页铃铛**
   - 点击首页的 inbox 图标 → 期望 router 定位到 `/inbox`（默认通知 tab）。
   - Mock 消息 provider 有未读 → 图标旁显示红点。

Widget 测试沿用项目已有的 `ProviderScope` override 风格（参考 `test/features/messages/` 下的现有测试）。

## 改动清单

**新增文件**
- `lib/features/inbox/inbox_screen.dart` — 收件箱容器、顶层 `_InboxTab` 组件、`_current` state、header action 切换逻辑、未读红点计算。
- `lib/features/messages/messages_tab.dart` — 从 `MessagesScreen` 抽出的列表 widget（无 Scaffold / 无 header）。
- `lib/features/notifications/notifications_tab.dart` — 从 `NotificationsScreen` 抽出的列表 widget（无 Scaffold / 无 PageTitleBar）；暴露 `markAllRead()` 和 `unreadCount`。
- `test/features/inbox/inbox_screen_test.dart`
- `test/widgets/bottom_nav_shell_test.dart`

**修改文件**
- `lib/routes.dart` — 删 `/messages` branch；新增 `/inbox` GoRoute；`/messages` 和 `/notifications` 改为 redirect。
- `lib/widgets/bottom_nav_shell.dart` — `tabs` 从 5 项减至 4 项。
- `lib/features/home/home_screen.dart` — 铃铛 icon 和目标路由替换；`_WarnDot` 升级为订阅 provider 的 `_InboxUnreadDot`。
- `lib/features/messages/messages_screen.dart` — **删除**（路由 redirect 后已无消费者；业务逻辑全部迁入 `messages_tab.dart`）。
- `lib/features/notifications/notifications_screen.dart` — **删除**（同上）。
- `lib/providers.dart` — 新增 `messagesUnreadProvider`。
- `lib/l10n/arb/app_en.arb` / `app_zh.arb` — 新增三个 key；`tab_messages` 按实际引用情况保留或删除。

**无改动**
- `messagesRepository`、`conversationsProvider`、`new_dm_sheet.dart`、`chat_screen.dart`、`_ThreadRow` 内部逻辑。
- `/chat/:convId` 路由。
- 主题 tokens。

## 风险 & 取舍

- **删除 `messages_screen.dart` 和 `notifications_screen.dart`**：两个旧 Screen 的 Scaffold 外壳在抽出子 widget 后等于空壳。实现阶段先 `grep` 确认仅被 `routes.dart` 引用再删；若有 deep link 工具 / 测试 / analytics 仍直接 `import`，先改引用再删。
- **通知未读 demo 降级**：目前通知列表是纯 demo 数据，未读状态只在内存里；首页"任一未读"红点不得不用 "`messagesUnread || true`" 这种降级逻辑,意味着铃铛一直亮(只要消息非空或 demo 未读非空)。这是**已知妥协**,接受到"通知落地真实 provider"的那个 PR 统一修复——本次 spec 不引入通知持久化或后端对接。
- **GlobalKey 跨组件读状态**（`InboxScreen` 读 `NotificationsTabState.unreadCount`）：Flutter 常见做法但有耦合。更干净的做法是把通知未读状态也提成 provider，但这会牵动通知 demo 数据的模型重写,超出本次范围。暂用 GlobalKey,待通知上真实数据时一并 refactor。
- **Redirect 死循环**：`/messages` → `/inbox?tab=messages`,GoRouter 不会二次 match `/messages`(query 改写后仍是 `/inbox` 这条路由),无循环风险；但编码时必须保证 redirect 返回的是完整路径,不是 `'?tab=messages'`。
- **IndexedStack 两个 tab 同时常驻内存**：消息 tab 会始终订阅 `conversationsProvider`（realtime）；这是期望的行为（切 tab 不丢失滚动位置），额外内存占用可忽略。
- **ARB 文件未生成代码**：新增的 l10n key 需要跑 `flutter gen-l10n`（或 `flutter pub get`，视项目配置）生成 `AppL10n` getter 后才能 `l.inbox_title` 调用；plan 阶段把这一步标进任务列表。
- **通知里 `route == '/messages'` 的兼容**：当前 demo 数据中没有这种条目，但 `_branchRoots` 的定义需要同步更新；未来如果加"收到 DM"类通知，推荐直接写 `route: '/chat/$convId'` 而不是 `/messages`。

## 改动后的视觉对照

**底部导航**

```
Before:  [ 首页 ] [ Pickup ] [ 赛事 ] [ 消息 ] [ 我 ]    5 tabs, ~20% each
After:   [ 首页 ] [ Pickup ] [ 赛事 ]          [ 我 ]    4 tabs, ~25% each
```

**首页右上角**

```
Before:  [🔍] [🔔•]        (search, notifications with warn dot)
After:   [🔍] [📥•]        (search, inbox with unread dot)
```

**合并页内部**

```
┌───────────────────────────────┐
│  ← 收件箱           [+]        │  ← + 随 tab 切换为 "全部已读"
├───────────────────────────────┤
│  ┌───────┬───────┐            │
│  │消息•3 │通知•2 │            │  ← 顶层 tab
│  └───────┴───────┘            │
├───────────────────────────────┤
│  (messages 或 notifications    │
│   的内容区域,保留所有现有      │
│   下层交互)                    │
└───────────────────────────────┘
```
