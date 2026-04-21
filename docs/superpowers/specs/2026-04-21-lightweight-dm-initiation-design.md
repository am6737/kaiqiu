# 轻量级私聊发起（Lightweight DM Initiation）设计

日期：2026-04-21
状态：待实现

## 背景

消息页（`lib/features/messages/messages_screen.dart`）目前只允许用户新建群聊，或触发两个未实现的占位菜单（"扫码"、"联系组织者"）。数据层 `conversations.kind` 已经支持 `'dm'`，但 UI 完全没有发起单聊的入口。与此同时，用户在评分、评分阵型图、比赛后评分等场景中会频繁遇到其他球友，却无法在那些位置直接发起私聊。

该设计在不新增"好友系统"的前提下，引入一条轻量级的 DM 发起链路：`+` 入口的按 `@handle` 精确发起，以及三处场景头像长按弹出的"用户名片"。

## 目标

1. `消息` 页面右上角 `+` 能发起新的 1v1 DM，无需已存在的社交图谱。
2. 在评分相关页面的头像上，通过长按即可打开对方的"用户名片"，并从名片发起私聊。
3. DM 会话的创建是幂等的：同一对用户反复发起永远返回同一条会话，不产生重复记录。
4. DM 会话在消息列表与聊天页的标题上正确显示对方的名字和头像，而不是回退到"默认标题"。

## 非目标

- 不实现好友/关注系统、好友请求流程、好友列表管理。
- 不实现用户模糊搜索（按姓名搜索）；只支持精确的 `@handle` 匹配。
- 不实现弹幕（`DanmakuItem`）场景的头像点击 DM——当前 `DanmakuItem.user` 仅为昵称字符串，没有 `user_id`，改造范围超出本设计。
- 不新建通用的"查看他人个人资料页"全屏页面——用轻量 bottom sheet 承担该职责。
- 不改动 `_showNewSheet` 里的"新建群聊"逻辑与现有 conversation 长按菜单。

## 架构总览

```
UI
├── lib/features/messages/messages_screen.dart       # _showNewSheet 重排：发起私聊置顶，移除两个占位
├── lib/features/messages/new_dm_sheet.dart          # 新增：handle 输入 sheet
├── lib/widgets/user_card_sheet.dart                 # 新增：统一"用户名片" bottom sheet
├── lib/features/events/event_detail_screen.dart     # PlayerRatingRow 列表 Row 长按
├── lib/features/rating/widgets/pitch_view.dart      # Pitch 头像长按
└── lib/features/rating/post_match_rating_screen.dart # Avatar 长按

Data
├── lib/repositories/messages_repository.dart        # +ensureDmWith(otherUserId)
└── lib/repositories/profiles_repository.dart        # +fetchByHandle(handle)

Backend
└── supabase/migrations/0002_ensure_dm_conversation.sql  # 新 RPC + DM peer 解析支持

l10n
└── lib/l10n/app_{en,zh}.arb                         # 新增 5 个 key
```

UI 调用关系：

- 场景头像长按 → `showUserCardSheet(userId)` → 按钮"发起私聊" → `ensureDmWith` → `push('/chat/:id)`。
- `+` → `_showNewSheet` → "发起私聊" → `showNewDmSheet()` → `fetchByHandle` → `ensureDmWith` → `push('/chat/:id)`。

## 后端设计

### RPC：`ensure_dm_conversation(p_other_user_id uuid) returns uuid`

**文件**：新增 `supabase/migrations/0002_ensure_dm_conversation.sql`（不改动 `0001_schema.sql`）。

**签名**：`security definer`，schema `public`，授权给 `authenticated`。

**算法**：

1. `v_me := auth.uid();` 若 null 抛 `not_authenticated`。
2. 参数校验：
   - `p_other_user_id is null` → `raise exception 'other_required'`；
   - `p_other_user_id = v_me` → `raise exception 'cannot_dm_self'`；
   - 在 `profiles` 里不存在该 id → `raise exception 'user_not_found'`。
3. **查**：查找满足"`kind='dm'` 且成员集合恰等于 `{v_me, p_other_user_id}`"的会话。注意项目中外键列名是 `conv_id`（见 `conversation_members`）：

   ```sql
   select c.id into v_id
   from conversations c
   where c.kind = 'dm'
     and exists (select 1 from conversation_members m
                 where m.conv_id = c.id and m.user_id = v_me)
     and exists (select 1 from conversation_members m
                 where m.conv_id = c.id and m.user_id = p_other_user_id)
     and (select count(*) from conversation_members m
          where m.conv_id = c.id) = 2
   limit 1;
   ```

   找到就 `return v_id`。
4. **建**（`conversations` 表只有 `kind/title/updated_at` 列，无 `created_by`）：
   - `insert into conversations(kind) values ('dm') returning id into v_id;`
   - `insert into conversation_members(conv_id, user_id, unread) values (v_id, v_me, 0), (v_id, p_other_user_id, 0);`
   - `return v_id;`
5. **并发防护**：插入逻辑包一层 `begin ... exception when unique_violation then <重走查询分支> end;`。并发极低的情况下若两侧同时插入，返回其中任意一条（读方以 RPC 返回的 id 为准，不阻塞用户）。

**Grant**：`grant execute on function public.ensure_dm_conversation(uuid) to authenticated;`

### DM 对端解析（DM peer resolution）

列表页与聊天页需要显示对方的名字和头像。后端提供一个便于客户端获取"对端 user_id"的路径：

**方案**：在同一迁移文件中新增 view `v_conversation_peers`：

```sql
create or replace view public.v_conversation_peers as
select m.conv_id as conv_id,
       m.user_id as peer_user_id
from conversation_members m
join conversations c on c.id = m.conv_id
where c.kind = 'dm';
```

输出列名沿用项目约定的 `conv_id`。客户端按需：`select peer_user_id from v_conversation_peers where conv_id=$1 and peer_user_id <> auth.uid()` 取得对端 id。

**优化（可选，作为后续优化点，不在本设计强制范围内）**：`listConversations()` 的 SQL 可一次性 JOIN 出 DM 对端的 `name / avatar_url / handle`，避免 N+1。初版可以先按"每个 DM 行发一次 `profileByIdProvider`"的方式工作，客户端侧的 provider 会对同一 id 去重。

## 客户端设计

### `MessagesRepository` 扩展

新增方法（`lib/repositories/messages_repository.dart`）：

```dart
Future<String> ensureDmWith(String otherUserId) async {
  if (currentUserId == null) throw StateError('not signed in');
  final res = await supabase.rpc('ensure_dm_conversation',
      params: {'p_other_user_id': otherUserId});
  return res as String;
}

Future<String?> fetchDmPeerId(String convId) async {
  final me = currentUserId;
  if (me == null) return null;
  final row = await supabase.from('v_conversation_peers')
      .select('peer_user_id')
      .eq('conv_id', convId)
      .neq('peer_user_id', me)
      .maybeSingle();
  return row == null ? null : row['peer_user_id'] as String;
}
```

### `ProfilesRepository` 扩展

新增方法（`lib/repositories/profiles_repository.dart`）：

```dart
Future<Profile?> fetchByHandle(String handle) async {
  final row = await supabase
      .from('profiles')
      .select()
      .eq('handle', handle)
      .maybeSingle();
  return row == null ? null : Profile.fromMap(row);
}
```

### `widgets/user_card_sheet.dart`（新建）

对外仅暴露一个函数：

```dart
Future<void> showUserCardSheet(BuildContext context, WidgetRef ref,
    {required String userId});
```

内部 `StatelessConsumerWidget` 结构：

- 顶部抓手条（36×4，与现有 sheet 风格一致）。
- 头像（`Avatar` size=72），居中。
- 名字（20/w700/ink）。
- `@handle`（12/inkSub），无 handle 时隐藏该行。
- 元信息行（12/inkSub）：`position · city / district`，缺省字段跳过；全空则整行不渲染。
- `PrimaryButton` 标签 "发起私聊" / "Start DM"，icon `chat_bubble_outline`，宽度撑满；**当 `userId == auth.currentUser.id` 时整个按钮不渲染**。
- 次要按钮（`TextButton`）"关闭" / "Close"。

行为：

- `ref.watch(profileByIdProvider(userId))` 加载资料；loading 态给一个中等高度的 `SizedBox(height: 220)` + `CircularProgressIndicator`；error 态给错误图标 + 重试按钮。
- "发起私聊"按钮点击：进入内部 loading 状态 → `await ref.read(messagesRepoProvider).ensureDmWith(userId)` → `if (context.mounted) { Navigator.pop(ctx); context.push('/chat/$convId'); ref.invalidate(conversationsProvider); }`；失败走 `showToast(context, '...', error: true)`，不关闭 sheet。

### `features/messages/new_dm_sheet.dart`（新建）

对外：

```dart
Future<void> showNewDmSheet(BuildContext context, WidgetRef ref);
```

UI：

- 标题 "发起私聊"（`messages_new_dm`）。
- 说明 "输入对方 @handle"（`messages_new_dm_hint`）。
- `TextField`：`prefixIcon: alternate_email`、`autofocus: true`、`textInputAction: search`、`hintText: "handle"`。
- 内联错误文字位（12/danger）：默认隐藏，错误态显示。
- `PrimaryButton` "发起私聊"（宽度撑满，含 loading 状态）。

**弹出顺序约定**：在外层 `_showNewSheet` 的"发起私聊" `ListTile` `onTap` 中，先 `Navigator.pop(sheetCtx)` 关闭外层 sheet，再 `await showNewDmSheet(screenCtx, ref)`。`screenCtx` 是 `_showNewSheet(BuildContext context, ...)` 的 `context` 参数（页面级 context，非 sheet 内的 `ctx`）。这样 new_dm_sheet 的 sheet 下面没有 modal 叠加，提交成功只需 pop 一次。

提交逻辑（点击按钮 或 onSubmitted）：

```
1. raw = controller.text.trim();
2. if raw.isEmpty: inline err = messages_new_dm_hint; return;
3. h = raw.replaceFirst(RegExp(r'^@+'), '').toLowerCase();
4. btn.loading = true;
5. profile = await profilesRepo.fetchByHandle(h);
6. if profile == null: inline err = messages_new_dm_not_found; loading=false; return;
7. if profile.id == currentUid: inline err = messages_new_dm_cant_self; loading=false; return;
8. convId = await messagesRepo.ensureDmWith(profile.id);
9. if (!sheetCtx.mounted) return;
   Navigator.pop(sheetCtx);                        // 关 new_dm_sheet
   context.push('/chat/$convId');                  // GoRouter 全局路由
   ref.invalidate(conversationsProvider);
```

外层 `messages_screen.dart` 的 `_showNewSheet` 条目顺序：

1. "发起私聊"（新）→ `Navigator.pop(sheetCtx); await showNewDmSheet(screenCtx, ref);`
2. "新建群聊"（原 `_newGroup`，保持不变）

**移除**原 "扫码" 与 "联系组织者" 两条 `ListTile`。对应 l10n key 保留不动（其他位置可能引用；简单删除此处调用即可）。

### DM 展示调整

**消息列表 `_ThreadRow`（`messages_screen.dart`）**：

- 若 `thread.kind == 'dm'`：
  - 用 `FutureBuilder` 或新 provider `dmPeerProfileProvider(conversationId)` 拿到对端 profile；
  - 标题 = peer.name；Avatar 种子 = peer.name；无 peer 时回退到 `messages_thread_default_title`。
- 若 `thread.kind == 'group'`：沿用 `thread.title ?? messages_thread_default_title`。

推荐新增一个 riverpod `FutureProvider.family`：

```dart
final dmPeerProfileProvider =
    FutureProvider.family<Profile?, String>((ref, conversationId) async {
  final peerId = await ref.read(messagesRepoProvider)
      .fetchDmPeerId(conversationId);
  if (peerId == null) return null;
  return ref.watch(profileByIdProvider(peerId).future);
});
```

**聊天页 `chat_screen.dart`**：`chat_screen.dart` 不使用 `AppBar`，而是自绘 header（约 line 263-298）。目前标题硬编码为 `l.chat_default_group_title`。改为：DM 用对端 name（走同一 provider），group 用 conversation title，缺省回退到 `chat_default_group_title`。由于 chat_screen 只持有 `convId`，需要新增派生 provider `conversationByIdProvider(convId)`（内部从 `conversationsProvider` 的列表里 `firstWhereOrNull`）来获取 `kind`/`title`。

### 场景入口改造

**三处统一策略（方案 a）**：短按保留评分行为不变，**长按**打开名片 sheet。

| 文件 | 位置 | 改法 |
|---|---|---|
| `lib/features/events/event_detail_screen.dart` | ratings tab 内的 `PlayerRatingRow` 列表 Row（参照 line 2584 附近 `onOpenPlayer` 回调周边） | Row 外层 `GestureDetector` 增加 `onLongPress: () => showUserCardSheet(context, ref, userId: p.rateeId)` |
| `lib/features/rating/widgets/pitch_view.dart` | Pitch 头像（`slot.userId != null` 时） | 增加 `onLongPress: () => showUserCardSheet(ctx, ref, userId: slot.userId!)`，`_isSelf` 时仍显示名片（sheet 内部按钮会自动隐藏） |
| `lib/features/rating/post_match_rating_screen.dart` | 每个 `Avatar` 或其父 row | 同上长按 |

`event_detail_screen.dart` 里每处需要 ratee 的 `String` id 的节点必须确认字段已就位（`PlayerRatingRow.rateeId` 是必填）。

### i18n

`lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb` 同步新增：

| key | en | zh |
|---|---|---|
| `messages_new_dm` | Start DM | 发起私聊 |
| `messages_new_dm_hint` | Enter the user's handle | 输入对方 @handle |
| `messages_new_dm_not_found` | User not found | 用户不存在 |
| `messages_new_dm_cant_self` | Can't DM yourself | 不能和自己私聊 |
| `user_card_close` | Close | 关闭 |

已有 key `messages_new_scan` 和 `messages_new_contact_organizer` 暂不删除（避免遗漏引用），仅从 `_showNewSheet` 中停止调用。

## 数据流

```
[场景头像]---long-press--->[showUserCardSheet(userId)]
   profileByIdProvider.watch ---> 展示资料
   [发起私聊 btn] ---> ensureDmWith(userId)
                      ---> ensure_dm_conversation RPC
                      ---> conversationId
                      ---> pop + push('/chat/:id') + invalidate(conversationsProvider)

[+] ---> _showNewSheet ---> [发起私聊]
   ---> showNewDmSheet() ---> handle 输入
   ---> fetchByHandle(h) ---> profile | null
   ---> ensureDmWith(profile.id) ---> convId
   ---> pop x2 + push('/chat/:convId') + invalidate
```

## 错误与边界

- **网络/RPC 失败**：sheet 不关闭，用 `showToast(error: true)` 展示；按钮恢复可点。
- **handle 不存在**：内联错误（`messages_new_dm_not_found`）；不弹 toast，避免双重提示。
- **输入自己的 handle**：`fetchByHandle` 成功返回自己的 profile，`profile.id == currentUid` 判定，内联错误（`messages_new_dm_cant_self`）。
- **已有历史 DM**：`ensure_dm_conversation` RPC 返回既有 id，直接 push 进去。
- **并发双写**：见 RPC 设计的 `unique_violation` 兜底。
- **profile 加载失败（名片 sheet）**：错误态 + 重试按钮；"发起私聊"按钮禁用。
- **从自己的头像长按打开**：名片 sheet 可打开，只是不显示"发起私聊"按钮（非错误）。

## 测试范围

- Widget：`user_card_sheet.dart`
  - 加载/成功/错误三态渲染；
  - `userId == currentUid` 时按钮隐藏；
  - 点击"发起私聊"触发 `ensureDmWith` 并跳转。
- Widget：`new_dm_sheet.dart`
  - 空输入 → 错误态；
  - `@` 前缀正确剥离，大小写正确归一；
  - `fetchByHandle` 返回 null → "用户不存在"；
  - 自己的 handle → "不能和自己私聊"；
  - 成功路径：触发跳转并 invalidate。
- Unit：`MessagesRepository.ensureDmWith` / `fetchDmPeerId`，`ProfilesRepository.fetchByHandle`。
- RPC：手工验证同一对用户反复调用返回同一 id；禁止自连；不存在的 user 报错。

## 实施分阶段

推荐的顺序（每阶段可独立验证）：

1. **Backend + Repo**：新建 `0002_ensure_dm_conversation.sql` + `v_conversation_peers`；`MessagesRepository.ensureDmWith` 与 `fetchDmPeerId`；`ProfilesRepository.fetchByHandle`。
2. **UserCardSheet**：新建 `widgets/user_card_sheet.dart`，无引入点；单元测试 + 手测通过。
3. **"+" 发起私聊**：`new_dm_sheet.dart` + `messages_screen._showNewSheet` 重排 + l10n key。
4. **DM 展示修复**：`_ThreadRow` + `chat_screen` 头部读取对端名字/头像。
5. **场景入口接入**：`event_detail_screen` / `pitch_view` / `post_match_rating_screen` 长按绑定。

## 风险与权衡

- **handle 精确匹配的可用性**：对用户要求较高；可接受，未来可渐进升级为模糊搜索（相当于在此处再加一个模糊结果列表，不破坏现有结构）。
- **DM 展示的 N+1**：初版按 `dmPeerProfileProvider.family` 逐条解析。`profileByIdProvider` 有本地缓存，实际负载有限；若后期性能有问题再把对端信息 JOIN 进 `listConversations()`。
- **评分场景长按的发现性**：长按是否足够直观？替代方案（方案 b：改"短按"）会改掉现有评分打开流程，本期不做，保持保守。
