# 轻量级私聊发起 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户能从消息页 "+" 按 `@handle` 精确发起 1v1 私聊，并在三处评分相关页面通过长按头像弹出"用户名片 bottom sheet"发起私聊；DM 幂等创建、消息列表和聊天页正确显示对方名字/头像。

**Architecture:** 新增一个 `ensure_dm_conversation` RPC 在 Postgres 侧原子地 find-or-create DM 会话；新建通用 `showUserCardSheet(userId)` 和 `showNewDmSheet()` 两个 bottom sheet；扩展 `MessagesRepository` / `ProfilesRepository` 的数据层；在 `messages_screen` / `chat_screen` / 三处评分 Row 接入。

**Tech Stack:** Flutter 3.x, Dart 3.11.5, Supabase (PostgreSQL + RLS + RPC), `flutter_riverpod`, `go_router`, `flutter_test`, 项目自有 `AppTokens` / `PrimaryButton` / `Avatar` / `showToast`。

**Spec:** `docs/superpowers/specs/2026-04-21-lightweight-dm-initiation-design.md`

---

## File Structure

**新增文件：**

| 路径 | 职责 |
|---|---|
| `supabase/migrations/0002_ensure_dm_conversation.sql` | RPC `ensure_dm_conversation(uuid)` + view `v_conversation_peers` + grants |
| `lib/widgets/user_card_sheet.dart` | `showUserCardSheet(BuildContext, WidgetRef, {userId})` —— 统一"用户名片"入口 |
| `lib/features/messages/new_dm_sheet.dart` | `showNewDmSheet(BuildContext, WidgetRef)` —— handle 输入 sheet |
| `test/widgets/user_card_sheet_test.dart` | 名片 sheet widget 测试 |
| `test/features/messages/new_dm_sheet_test.dart` | "+" 发起私聊 sheet widget 测试 |

**修改文件：**

| 路径 | 变更 |
|---|---|
| `lib/repositories/messages_repository.dart` | +`ensureDmWith(otherUserId)` / `fetchDmPeerId(convId)` |
| `lib/repositories/profiles_repository.dart` | +`fetchByHandle(handle)` |
| `lib/providers.dart` | +`dmPeerProfileProvider(convId)` / `conversationByIdProvider(convId)` |
| `lib/features/messages/messages_screen.dart` | `_showNewSheet` 顶部加"发起私聊"条目，移除扫码/联系组织者 占位；`_ThreadRow` 对 `kind=='dm'` 的会话展示对端名字/头像 |
| `lib/features/messages/chat_screen.dart` | header 的标题（约 line 263-298）改为根据会话 kind 展示（DM 用对端名字，group 用 `conversation.title`） |
| `lib/features/events/event_detail_screen.dart` | ratings tab 里 `PlayerRatingRow` 列表 Row 增加 `onLongPress` 触发名片 sheet |
| `lib/features/rating/widgets/pitch_view.dart` | Pitch 上头像 slot 增加 `onLongPress` |
| `lib/features/rating/post_match_rating_screen.dart` | 每处显示他人 `Avatar` 的行增加 `onLongPress` |
| `lib/l10n/app_zh.arb` | 新增 5 个 key |
| `lib/l10n/app_en.arb` | 新增 5 个 key |

---

## Task 1: 数据库迁移 — `ensure_dm_conversation` RPC + `v_conversation_peers` view

**Files:**
- Create: `supabase/migrations/0002_ensure_dm_conversation.sql`

- [ ] **Step 1: 新建迁移文件**

Create `supabase/migrations/0002_ensure_dm_conversation.sql` with the following contents:

```sql
-- 0002_ensure_dm_conversation.sql
-- 新增 1v1 DM 的幂等"找到或创建"RPC + DM 对端查询 view。
-- 与 0001_schema.sql 保持风格一致：security definer, search_path=public, grant to authenticated。

-- ───────────────────────────────────────────────────────────────
-- ensure_dm_conversation(p_other_user_id uuid) → uuid
--   当前用户 v_me 与 p_other_user_id 之间若已存在 kind='dm' 且成员恰
--   为 {v_me, other} 的会话，返回该 id；否则新建并插入两位成员。
-- ───────────────────────────────────────────────────────────────

drop function if exists public.ensure_dm_conversation(uuid);

create function public.ensure_dm_conversation(p_other_user_id uuid)
  returns uuid
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null then
    raise exception 'not_authenticated';
  end if;
  if p_other_user_id is null then
    raise exception 'other_required';
  end if;
  if p_other_user_id = v_me then
    raise exception 'cannot_dm_self';
  end if;
  if not exists (select 1 from profiles where id = p_other_user_id) then
    raise exception 'user_not_found';
  end if;

  -- 查：kind='dm' 且成员恰等于 {v_me, p_other_user_id} 的会话
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

  if v_id is not null then
    return v_id;
  end if;

  -- 建：conversations 表无 created_by 列，只填 kind
  insert into conversations (kind) values ('dm') returning id into v_id;

  insert into conversation_members (conv_id, user_id, unread)
  values (v_id, v_me, 0), (v_id, p_other_user_id, 0);

  return v_id;
end;
$$;

grant execute on function public.ensure_dm_conversation(uuid) to authenticated;


-- ───────────────────────────────────────────────────────────────
-- v_conversation_peers
--   列出每个 DM 会话的成员 user_id，供客户端按 conv_id + peer_user_id <> me
--   查询对端 uid（用于消息列表与聊天页显示对方名字/头像）。
-- ───────────────────────────────────────────────────────────────

drop view if exists public.v_conversation_peers;

create view public.v_conversation_peers as
select m.conv_id as conv_id,
       m.user_id as peer_user_id
from conversation_members m
join conversations c on c.id = m.conv_id
where c.kind = 'dm';

grant select on public.v_conversation_peers to authenticated;
```

- [ ] **Step 2: 核对 SQL 与 0001 中字段一致**

用 Grep 确认 0001_schema.sql 中 `conversation_members` 表字段为 `conv_id / user_id / unread / last_read_at`，以及 `conversations` 表有 `kind / title / updated_at`。若有出入，修正上一步 SQL。

Run: `grep -n "create table public.conversations\|create table public.conversation_members" supabase/migrations/0001_schema.sql`
Expected: 两行分别定位到表定义，字段与 SQL 中引用一致。

- [ ] **Step 3: 手动在 Supabase SQL Editor 应用迁移**

本项目没有自动化迁移命令（README 的 "Getting Started" 小节说明手工在 Supabase SQL Editor 里按顺序执行 `supabase/migrations/` 下的 SQL）。将 `0002_ensure_dm_conversation.sql` 的内容整段复制粘贴到 SQL Editor 运行。预期输出：`CREATE FUNCTION / GRANT / CREATE VIEW / GRANT`，无错误。

- [ ] **Step 4: 在 SQL Editor 做一次烟雾测试**

```sql
-- 准备两个真实的 profiles.id (用户 A、B)，并以 A 身份登录
select auth.uid();                     -- 应返回 A 的 id

select public.ensure_dm_conversation('<B_user_id>'::uuid) as conv1;
select public.ensure_dm_conversation('<B_user_id>'::uuid) as conv2;
-- 预期：conv1 = conv2（幂等）

select * from public.v_conversation_peers where conv_id = '<conv1>';
-- 预期：两行，user_id 分别是 A 和 B

-- 自连异常
select public.ensure_dm_conversation(auth.uid()); -- 预期：raise exception 'cannot_dm_self'
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0002_ensure_dm_conversation.sql
git commit -m "feat(db): ensure_dm_conversation RPC + v_conversation_peers view"
```

---

## Task 2: l10n — 新增 5 个 key

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

模板 ARB 是 `app_zh.arb`（见 `l10n.yaml: template-arb-file`），先改模板再补 en。

- [ ] **Step 1: 追加 5 个 zh key 到 `lib/l10n/app_zh.arb`**

在文件末尾右大括号前追加以下 key/value 对（注意保持 JSON 语法，前一条加逗号）：

```json
  "messages_new_dm": "发起私聊",
  "messages_new_dm_hint": "输入对方 @handle",
  "messages_new_dm_not_found": "用户不存在",
  "messages_new_dm_cant_self": "不能和自己私聊",
  "user_card_close": "关闭"
```

- [ ] **Step 2: 追加 5 个 en key 到 `lib/l10n/app_en.arb`**

```json
  "messages_new_dm": "Start DM",
  "messages_new_dm_hint": "Enter the user's handle",
  "messages_new_dm_not_found": "User not found",
  "messages_new_dm_cant_self": "Can't DM yourself",
  "user_card_close": "Close"
```

- [ ] **Step 3: 重新生成 l10n**

Run: `flutter gen-l10n`
Expected: 无输出或 `Generating synthetic localizations package has been removed.` 之类信息；`lib/l10n/generated/app_localizations*.dart` 中新增 5 个 getter。

- [ ] **Step 4: 验证生成结果**

Run: `grep -n "messages_new_dm\b" lib/l10n/generated/app_localizations.dart | head`
Expected: 至少两行（抽象类与实现类）。

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated
git commit -m "i18n: add DM-initiation strings"
```

---

## Task 3: ProfilesRepository.fetchByHandle

**Files:**
- Modify: `lib/repositories/profiles_repository.dart`

无现成的 repository 单测样例；本任务直接改实现，由 Task 7 的 widget 测试覆盖行为。

- [ ] **Step 1: 新增 `fetchByHandle` 方法**

在 `ProfilesRepository` 类末尾（`upsertOnSignup` 之后）新增：

```dart
  /// Look up a profile by its unique `handle`. Returns null if not found.
  Future<Profile?> fetchByHandle(String handle) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('handle', handle)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }
```

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/repositories/profiles_repository.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/profiles_repository.dart
git commit -m "feat(profiles): fetchByHandle lookup"
```

---

## Task 4: MessagesRepository — `ensureDmWith` + `fetchDmPeerId`

**Files:**
- Modify: `lib/repositories/messages_repository.dart`

- [ ] **Step 1: 新增两个方法**

在 `MessagesRepository` 类里，`ensureEventConversation` 之后新增：

```dart
  /// Idempotently find-or-create a 1v1 DM conversation with [otherUserId].
  /// Returns the conversation id. Atomic on the server via RPC.
  Future<String> ensureDmWith(String otherUserId) async {
    if (currentUserId == null) {
      throw StateError('not signed in');
    }
    final convId = await supabase.rpc(
      'ensure_dm_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    return convId as String;
  }

  /// For a DM conversation, return the OTHER member's user_id
  /// (the peer, i.e. not the current user). Returns null if convId
  /// is not a DM or the current user is not signed in.
  Future<String?> fetchDmPeerId(String convId) async {
    final me = currentUserId;
    if (me == null) return null;
    final row = await supabase
        .from('v_conversation_peers')
        .select('peer_user_id')
        .eq('conv_id', convId)
        .neq('peer_user_id', me)
        .maybeSingle();
    if (row == null) return null;
    return row['peer_user_id'] as String?;
  }
```

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/repositories/messages_repository.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/messages_repository.dart
git commit -m "feat(messages): ensureDmWith + fetchDmPeerId"
```

---

## Task 5: Providers — `dmPeerProfileProvider` + `conversationByIdProvider`

**Files:**
- Modify: `lib/providers.dart`

- [ ] **Step 1: 新增两个 FutureProvider.family**

在 `lib/providers.dart` 中 `profileByIdProvider` 附近（约 line 253 附近）新增：

```dart
/// Profile of the peer (the non-me member) of a 1v1 DM conversation.
/// Returns null for group conversations or if the peer profile isn't found.
final dmPeerProfileProvider =
    FutureProvider.family.autoDispose<Profile?, String>((ref, convId) async {
  final peerId =
      await ref.read(messagesRepoProvider).fetchDmPeerId(convId);
  if (peerId == null) return null;
  return ref.watch(profileByIdProvider(peerId).future);
});

/// Look up a single conversation by its id from the cached conversations
/// list. Returns null while [conversationsProvider] is still loading or if
/// no match is found.
final conversationByIdProvider =
    Provider.family.autoDispose<ConversationRow?, String>((ref, convId) {
  final list = ref.watch(conversationsProvider).valueOrNull;
  if (list == null) return null;
  for (final c in list) {
    if (c.id == convId) return c;
  }
  return null;
});
```

若 `ConversationRow` 未在本文件 import，顶部补 `import 'repositories/messages_repository.dart';`（应已存在）。`Profile` 同理。

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/providers.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(providers): dmPeerProfileProvider + conversationByIdProvider"
```

---

## Task 6: `widgets/user_card_sheet.dart` —— 统一"用户名片 bottom sheet"

**Files:**
- Create: `lib/widgets/user_card_sheet.dart`
- Test: `test/widgets/user_card_sheet_test.dart`

**TDD：先写 widget 测试。** 测试用 `ProviderScope.overrides` 打桩 `profileByIdProvider` 与 `messagesRepoProvider`。

- [ ] **Step 1: 写失败的测试**

Create `test/widgets/user_card_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaiqiu_app/models/profile.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/user_card_sheet.dart';

class _FakeMessagesRepo extends MessagesRepository {
  String? calledWithUserId;
  String nextConvId = 'conv-123';
  @override
  Future<String> ensureDmWith(String otherUserId) async {
    calledWithUserId = otherUserId;
    return nextConvId;
  }
}

Profile _sample({String id = 'u-other', String name = 'Bob'}) => Profile(
      id: id,
      name: name,
      handle: 'bobbb',
      city: 'Beijing',
      position: 'CF',
      createdAt: DateTime(2026, 1, 1),
    );

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  final ctrl = ThemeController.test();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ctrl.lightTheme,
      darkTheme: ctrl.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('showUserCardSheet', () {
    testWidgets('renders name, handle, position', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return Center(
            child: Consumer(builder: (c, ref, _) {
              return ElevatedButton(
                onPressed: () =>
                    showUserCardSheet(c, ref, userId: 'u-other'),
                child: const Text('open'),
              );
            }),
          );
        }),
        overrides: [
          profileByIdProvider('u-other')
              .overrideWith((ref) async => _sample()),
        ],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('bobbb'), findsOneWidget);
      expect(find.textContaining('CF'), findsOneWidget);
      expect(find.text('发起私聊'), findsOneWidget);
    });

    testWidgets('tapping Start DM calls ensureDmWith', (tester) async {
      final repo = _FakeMessagesRepo();
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          return Center(
            child: Consumer(builder: (c, ref, _) {
              return ElevatedButton(
                onPressed: () =>
                    showUserCardSheet(c, ref, userId: 'u-other'),
                child: const Text('open'),
              );
            }),
          );
        }),
        overrides: [
          profileByIdProvider('u-other')
              .overrideWith((ref) async => _sample()),
          messagesRepoProvider.overrideWithValue(repo),
        ],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('发起私聊'));
      await tester.pumpAndSettle();

      expect(repo.calledWithUserId, 'u-other');
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/widgets/user_card_sheet_test.dart`
Expected: FAIL — `user_card_sheet.dart` 不存在，导入报错。

- [ ] **Step 3: 实现 `widgets/user_card_sheet.dart`**

Create `lib/widgets/user_card_sheet.dart`:

```dart
// user_card_sheet.dart — 通用"用户名片 bottom sheet"，统一从各处头像长按进入。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../models/profile.dart';
import '../providers.dart';
import '../services/supabase.dart';
import '../theme/app_tokens.dart';
import '../utils/toast.dart';
import 'avatar.dart';
import 'primary_button.dart';

Future<void> showUserCardSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _UserCardSheet(userId: userId),
  );
}

class _UserCardSheet extends ConsumerStatefulWidget {
  final String userId;
  const _UserCardSheet({required this.userId});

  @override
  ConsumerState<_UserCardSheet> createState() => _UserCardSheetState();
}

class _UserCardSheetState extends ConsumerState<_UserCardSheet> {
  bool _busy = false;

  Future<void> _onStartDm() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final convId =
          await ref.read(messagesRepoProvider).ensureDmWith(widget.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/$convId');
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isMe = widget.userId == currentUserId;
    final async = ref.watch(profileByIdProvider(widget.userId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 18),
            async.when(
              loading: () => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 32, color: context.tokens.warn),
                      const SizedBox(height: 8),
                      Text('$e',
                          style: TextStyle(
                              fontSize: 12, color: context.tokens.inkSub)),
                    ],
                  ),
                ),
              ),
              data: (profile) => _buildBody(context, profile, isMe, l),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l.user_card_close,
                  style: TextStyle(color: context.tokens.inkSub)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, Profile? p, bool isMe, dynamic l) {
    if (p == null) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(l.messages_new_dm_not_found,
              style: TextStyle(color: context.tokens.inkSub)),
        ),
      );
    }
    final meta = <String>[
      if ((p.position ?? '').isNotEmpty) p.position!,
      if ((p.city ?? '').isNotEmpty) p.city!,
      if ((p.district ?? '').isNotEmpty) p.district!,
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Avatar(p.name, size: 72),
        const SizedBox(height: 12),
        Text(p.name,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.tokens.ink)),
        if ((p.handle ?? '').isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('@${p.handle}',
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub)),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meta,
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub)),
        ],
        const SizedBox(height: 18),
        if (!isMe)
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: l.messages_new_dm,
              size: BtnSize.md,
              loading: _busy,
              onPressed: _onStartDm,
            ),
          ),
      ],
    );
  }
}
```

Note: `PrimaryButton` 的参数命名以 `lib/widgets/primary_button.dart` 里的定义为准；若没有 `loading` 参数，改成 `onPressed: _busy ? null : _onStartDm` 并在按钮内部条件渲染一个 `CircularProgressIndicator`。实施前先 Read `primary_button.dart` 一眼。

- [ ] **Step 4: 跑测试，确认通过**

Run: `flutter test test/widgets/user_card_sheet_test.dart`
Expected: 两条测试全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/user_card_sheet.dart test/widgets/user_card_sheet_test.dart
git commit -m "feat(ui): user card bottom sheet with Start DM action"
```

---

## Task 7: `features/messages/new_dm_sheet.dart` —— "+" 发起私聊 sheet

**Files:**
- Create: `lib/features/messages/new_dm_sheet.dart`
- Test: `test/features/messages/new_dm_sheet_test.dart`

- [ ] **Step 1: 写失败的测试**

Create `test/features/messages/new_dm_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaiqiu_app/features/messages/new_dm_sheet.dart';
import 'package:kaiqiu_app/models/profile.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/repositories/profiles_repository.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

class _FakeProfilesRepo extends ProfilesRepository {
  Profile? nextByHandle;
  String? calledHandle;
  @override
  Future<Profile?> fetchByHandle(String handle) async {
    calledHandle = handle;
    return nextByHandle;
  }
}

class _FakeMessagesRepo extends MessagesRepository {
  String nextConvId = 'c-1';
  String? calledWith;
  @override
  Future<String> ensureDmWith(String otherUserId) async {
    calledWith = otherUserId;
    return nextConvId;
  }
}

Widget _wrap({required Widget home, List<Override> overrides = const []}) {
  final ctrl = ThemeController.test();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ctrl.lightTheme,
      darkTheme: ctrl.darkTheme,
      home: home,
    ),
  );
}

void main() {
  testWidgets('strips leading @, lowercases, calls fetchByHandle',
      (tester) async {
    final repo = _FakeProfilesRepo()..nextByHandle = null;
    await tester.pumpWidget(_wrap(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Consumer(builder: (c, ref, _) {
            return ElevatedButton(
              onPressed: () => showNewDmSheet(c, ref),
              child: const Text('open'),
            );
          }),
        );
      }),
      overrides: [profilesRepoProvider.overrideWithValue(repo)],
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '@BoB');
    await tester.tap(find.text('发起私聊'));
    await tester.pumpAndSettle();
    expect(repo.calledHandle, 'bob');
    // not found 错误应可见
    expect(find.text('用户不存在'), findsOneWidget);
  });

  testWidgets('success path navigates and closes', (tester) async {
    final pRepo = _FakeProfilesRepo()
      ..nextByHandle = Profile(
        id: 'u-other',
        name: 'Bob',
        handle: 'bob',
        createdAt: DateTime(2026, 1, 1),
      );
    final mRepo = _FakeMessagesRepo()..nextConvId = 'c-99';
    await tester.pumpWidget(_wrap(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Consumer(builder: (c, ref, _) {
            return ElevatedButton(
              onPressed: () => showNewDmSheet(c, ref),
              child: const Text('open'),
            );
          }),
        );
      }),
      overrides: [
        profilesRepoProvider.overrideWithValue(pRepo),
        messagesRepoProvider.overrideWithValue(mRepo),
      ],
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.tap(find.text('发起私聊'));
    await tester.pumpAndSettle();
    expect(mRepo.calledWith, 'u-other');
    // sheet 应已关闭（TextField 不再可见）
    expect(find.byType(TextField), findsNothing);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/features/messages/new_dm_sheet_test.dart`
Expected: FAIL — `new_dm_sheet.dart` 不存在。

- [ ] **Step 3: 实现 `new_dm_sheet.dart`**

Create `lib/features/messages/new_dm_sheet.dart`:

```dart
// new_dm_sheet.dart — "+" 里"发起私聊"入口：按 @handle 精确匹配建 DM。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

Future<void> showNewDmSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: const _NewDmSheet(),
    ),
  );
}

class _NewDmSheet extends ConsumerStatefulWidget {
  const _NewDmSheet();

  @override
  ConsumerState<_NewDmSheet> createState() => _NewDmSheetState();
}

class _NewDmSheetState extends ConsumerState<_NewDmSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _err = l.messages_new_dm_hint);
      return;
    }
    final h = raw.replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final profile = await ref
          .read(profilesRepoProvider)
          .fetchByHandle(h);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _busy = false;
          _err = l.messages_new_dm_not_found;
        });
        return;
      }
      if (profile.id == currentUserId) {
        setState(() {
          _busy = false;
          _err = l.messages_new_dm_cant_self;
        });
        return;
      }
      final convId = await ref
          .read(messagesRepoProvider)
          .ensureDmWith(profile.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/$convId');
      ref.invalidate(conversationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 18),
            Text(l.messages_new_dm,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.ink)),
            const SizedBox(height: 4),
            Text(l.messages_new_dm_hint,
                style:
                    TextStyle(fontSize: 12, color: context.tokens.inkSub)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: TextStyle(color: context.tokens.ink),
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.alternate_email, color: context.tokens.inkSub),
                hintText: 'handle',
                hintStyle: TextStyle(color: context.tokens.inkDim),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_err != null) ...[
              const SizedBox(height: 6),
              Text(_err!,
                  style:
                      TextStyle(fontSize: 12, color: context.tokens.danger)),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: l.messages_new_dm,
              size: BtnSize.md,
              loading: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
```

实施前确认 `PrimaryButton` 是否接受 `loading` 参数；若不支持，`onPressed: _busy ? null : _submit` 并在 `label` 侧展示 loading。

- [ ] **Step 4: 跑测试，确认通过**

Run: `flutter test test/features/messages/new_dm_sheet_test.dart`
Expected: 两条测试 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/features/messages/new_dm_sheet.dart test/features/messages/new_dm_sheet_test.dart
git commit -m "feat(messages): new DM sheet (@handle exact match)"
```

---

## Task 8: `messages_screen._showNewSheet` 接入"发起私聊"

**Files:**
- Modify: `lib/features/messages/messages_screen.dart:146-217`

- [ ] **Step 1: 更新 `_showNewSheet`**

编辑 `lib/features/messages/messages_screen.dart` 的 `_showNewSheet` 方法：

1. 文件顶部 import 区域增加：`import 'new_dm_sheet.dart';`
2. 在 ListTile "新建群聊"（`messages_new_group`）**之前**插入"发起私聊"条目：

```dart
            ListTile(
              leading: Icon(Icons.chat_bubble_outline,
                  color: context.tokens.accent),
              title: Text(
                l.messages_new_dm,
                style: TextStyle(color: context.tokens.ink),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (context.mounted) await showNewDmSheet(context, ref);
              },
            ),
```

3. **删除**原"扫码"（`messages_new_scan`）和"联系组织者"（`messages_new_contact_organizer`）两条 `ListTile`（当前 line 190-211）。两条 l10n key 保留不动。

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/features/messages/messages_screen.dart`
Expected: No issues found.

- [ ] **Step 3: 手动验证**

启动 app，进入消息 tab，点 "+"，应看到两条：发起私聊 / 新建群聊。

- [ ] **Step 4: Commit**

```bash
git add lib/features/messages/messages_screen.dart
git commit -m "feat(messages): wire Start DM into the + sheet; remove placeholders"
```

---

## Task 9: `_ThreadRow` 显示 DM 对端名字/头像

**Files:**
- Modify: `lib/features/messages/messages_screen.dart` — `_ThreadRow.build`（约 line 410-504）

- [ ] **Step 1: 引入 `dmPeerProfileProvider` 并分支展示**

修改 `_ThreadRow.build`：在计算 `title` 前，先对 `thread.kind == 'dm'` 分支：

```dart
    String title;
    if (thread.kind == 'dm') {
      final peer = ref.watch(dmPeerProfileProvider(thread.id)).valueOrNull;
      title = peer?.name ?? context.l10n.messages_thread_default_title;
    } else {
      title = thread.title ?? context.l10n.messages_thread_default_title;
    }
```

`Avatar(title, size: 44)` 已经按名字派生首字母 + 颜色，不需要额外调整头像。

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/features/messages/messages_screen.dart`
Expected: No issues.

- [ ] **Step 3: 手动验证（需要有至少一条 DM）**

- 通过 "+" 发起一段 DM（handle 为另一位 demo 用户）；
- 返回消息列表，确认 DM 那一行标题展示对方名字而不是 "私聊"（默认标题）。

- [ ] **Step 4: Commit**

```bash
git add lib/features/messages/messages_screen.dart
git commit -m "feat(messages): show DM peer name in conversation list"
```

---

## Task 10: `chat_screen` header 根据 kind 展示标题

**Files:**
- Modify: `lib/features/messages/chat_screen.dart`（header 部分，约 line 260-298；顶部 import）

- [ ] **Step 1: 在 `build` 中获取 `kind` 和标题**

替换 header 里硬编码的 `context.l10n.chat_default_group_title`：

```dart
    final conv = ref.watch(conversationByIdProvider(widget.convId));
    String title;
    if (conv?.kind == 'dm') {
      final peer = ref
          .watch(dmPeerProfileProvider(widget.convId))
          .valueOrNull;
      title = peer?.name ?? context.l10n.chat_default_group_title;
    } else {
      title = conv?.title ?? context.l10n.chat_default_group_title;
    }
```

然后在原来的 `Text(context.l10n.chat_default_group_title, ...)` 处改用 `Text(title, ...)`。

- [ ] **Step 2: 静态检查**

Run: `flutter analyze lib/features/messages/chat_screen.dart`
Expected: No issues.

- [ ] **Step 3: 手动验证**

进入一段 DM，标题显示对方名字；进入一个群聊（比如 event 讨论组），标题为 `conversation.title`（例如 "event:xxx"）或默认值。

- [ ] **Step 4: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "feat(chat): show DM peer name / group title in header"
```

---

## Task 11: 场景入口 1 — `event_detail_screen.dart` 的 `PlayerRatingRow` 列表

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart`（Row 外层；约 line 2584、2674、2869 附近 `PlayerRatingRow` 的使用处）

- [ ] **Step 1: 定位 Row 外层的 GestureDetector 或 InkWell**

Run: `grep -n "PlayerRatingRow\|onLongPress\|GestureDetector\|InkWell" lib/features/events/event_detail_screen.dart | head -30`

找到 ratings tab 中渲染每条 `PlayerRatingRow` 的容器。若外层已是 `GestureDetector`，直接在其中增加 `onLongPress` 即可；若是 `InkWell`/`Material`/`ListTile`，用它们原生的 `onLongPress` 属性。如果连可点击包装都没有，在最外层裹一个 `InkWell(onLongPress: ...)`。

- [ ] **Step 2: 绑定 `showUserCardSheet`**

文件顶部 import 区：

```dart
import '../../widgets/user_card_sheet.dart';
```

容器 `onLongPress` 设置为：

```dart
onLongPress: () => showUserCardSheet(context, ref, userId: row.rateeId),
```

（`row` 是 `PlayerRatingRow` 实例的本地变量名；按实际代码调整。）

- [ ] **Step 3: 静态检查**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: No issues.

- [ ] **Step 4: 手动验证**

进入一个 event 的 ratings tab，长按某行玩家，弹出名片 sheet，点"发起私聊"跳转至 chat，消息列表出现新 DM。

- [ ] **Step 5: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(events): long-press PlayerRatingRow opens user card sheet"
```

---

## Task 12: 场景入口 2 — `pitch_view.dart` 上 slot 头像长按

**Files:**
- Modify: `lib/features/rating/widgets/pitch_view.dart`

- [ ] **Step 1: 定位 slot 头像渲染处**

Run: `grep -n "onTap\|GestureDetector\|slot.userId" lib/features/rating/widgets/pitch_view.dart | head -20`

找到 Pitch 上每个 slot 的头像容器（短按会打开评分 sheet 的那段）。

- [ ] **Step 2: 增加 `onLongPress`**

- 顶部 import：`import '../../../widgets/user_card_sheet.dart';`
- 在原 `GestureDetector(onTap: ...)` 中增加 `onLongPress`，仅当 `slot.userId != null` 时触发：

```dart
onLongPress: slot.userId == null
    ? null
    : () => showUserCardSheet(context, ref, userId: slot.userId!),
```

- 注意 `ref` 可用性：若该 widget 不是 Consumer，可用 `Consumer(builder: (c, ref, _) => ...)` 包一层，或改为 `ConsumerWidget`。先读一眼当前 widget 类型决定。

- [ ] **Step 3: 静态检查**

Run: `flutter analyze lib/features/rating/widgets/pitch_view.dart`
Expected: No issues.

- [ ] **Step 4: 手动验证**

打开某场比赛的阵型评分页，长按阵型中一名非自己球员的头像，弹出名片。

- [ ] **Step 5: Commit**

```bash
git add lib/features/rating/widgets/pitch_view.dart
git commit -m "feat(rating): long-press pitch slot opens user card sheet"
```

---

## Task 13: 场景入口 3 — `post_match_rating_screen.dart`

**Files:**
- Modify: `lib/features/rating/post_match_rating_screen.dart`

- [ ] **Step 1: 定位 `Avatar` 渲染处**

Run: `grep -n "Avatar(\|userId\|rateeId" lib/features/rating/post_match_rating_screen.dart | head -30`

定位每位被评分球员的 `Avatar` 行。

- [ ] **Step 2: 增加 `onLongPress`**

- 顶部 import：`import '../../widgets/user_card_sheet.dart';`
- 包裹 `Avatar` 或 Row 的 `GestureDetector(onLongPress: ..., behavior: HitTestBehavior.opaque, child: ...)`，userId 取对应球员的 `userId` / `rateeId`（以实际变量为准）。

```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onLongPress: () =>
      showUserCardSheet(context, ref, userId: <playerId>),
  child: Avatar(<name>, size: <size>),
),
```

- [ ] **Step 3: 静态检查**

Run: `flutter analyze lib/features/rating/post_match_rating_screen.dart`
Expected: No issues.

- [ ] **Step 4: 手动验证**

进入赛后评分页，长按一名球员头像，弹出名片，"发起私聊"正常跳转。

- [ ] **Step 5: Commit**

```bash
git add lib/features/rating/post_match_rating_screen.dart
git commit -m "feat(rating): long-press post-match avatar opens user card sheet"
```

---

## Task 14: 全量回归 & 清理

**Files:** 所有改动过的文件

- [ ] **Step 1: 跑所有测试**

Run: `flutter test`
Expected: all PASS。若因无关的 flaky 测试失败，记录但不修。

- [ ] **Step 2: 跑 analyzer**

Run: `flutter analyze`
Expected: `No issues found.`

- [ ] **Step 3: 清理未使用的 l10n key**

前面保留了 `messages_new_scan` / `messages_new_contact_organizer` 两个 key（spec 显式要求）。检查是否还有其他地方引用：

Run: `grep -rn "messages_new_scan\|messages_new_contact_organizer" lib/ test/`
Expected: 仅生成的 `lib/l10n/generated/` 里有引用；`lib/features/` 内无任何引用。若此条件满足，属实可以安全删除。**本任务不删**——按 spec 指示保留。

- [ ] **Step 4: 冒烟测试清单（手动）**

启动 app，逐一验证：

1. 消息 tab "+" → 发起私聊 → 输入不存在的 handle → 内联报错 "用户不存在"。
2. 输入自己的 handle → "不能和自己私聊"。
3. 输入 `@bob` → 跳到新 chat，消息列表出现对应 DM，标题为 "Bob"。
4. 再次对 Bob 重复发起 → 跳到同一个 chat（无重复会话）。
5. event ratings tab 长按一个球员 → 名片弹出 → 发起私聊可达 chat。
6. 阵型评分页长按队友头像 → 名片弹出。
7. 赛后评分页长按队友头像 → 名片弹出。
8. 自己的头像长按 → 名片弹出，但没有"发起私聊"按钮。
9. 在 group 会话 chat 页，标题依然展示群名。

- [ ] **Step 5: 若手测发现问题，分别修复并以独立 commit 追加**

---

## 风险与回滚

- **迁移没回滚脚本**：`0002_ensure_dm_conversation.sql` 用了 `drop function if exists ... / drop view if exists ...` 来保证重复执行安全；如需回滚，手工执行 drop 即可。
- **生成 l10n 文件**：`lib/l10n/generated/` 建议一起提交（项目现有提交包含 `generated/`），避免下个人拉下来 build 时才重建。
- **长按行为发现性**：如反馈"不知道能长按"，后续在长按首次出现时用一个 snackbar 提示；不纳入本次范围。
