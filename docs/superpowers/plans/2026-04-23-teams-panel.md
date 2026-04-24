# 赛事详情页"队伍"标签页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在赛事详情页新增"队伍"标签页，展示参赛队伍列表，创建者可在 manual 模式下审核报名。

**Architecture:** 数据库迁移扩展 teams 表（status 三态 + contact/phone 列）→ TeamRow 模型 + repository 方法 → eventTeamsProvider → TeamsPanel 组件 → 插入到 EventDetailScreen 的 tab 列表中。报名逻辑根据 review_mode 设置初始 status。

**Tech Stack:** Flutter / Riverpod / Supabase / Go Router

**Spec:** `docs/superpowers/specs/2026-04-23-teams-panel-design.md`

---

### Task 1: 数据库迁移 — teams 表扩展

**Files:**
- Create: `supabase/migrations/0003_teams_status_contact.sql`

- [ ] **Step 1: 创建迁移文件**

```sql
-- 0003_teams_status_contact.sql
-- 将 approved boolean 迁移为 status 三态，新增 contact/phone 列

-- 1. 新增 status 列
alter table public.teams
  add column status text default 'pending'
  check (status in ('pending', 'approved', 'rejected'));

-- 2. 迁移旧数据：approved=true → 'approved'，false → 'pending'
update public.teams set status = 'approved' where approved = true;
update public.teams set status = 'pending' where approved = false or approved is null;

-- 3. 删除旧列
alter table public.teams drop column approved;

-- 4. 新增联系方式列
alter table public.teams add column contact text;
alter table public.teams add column phone text;
```

- [ ] **Step 2: 在 Supabase Dashboard SQL Editor 执行迁移**

在 Supabase Dashboard 打开 SQL Editor，粘贴并执行上述 SQL。验证：
- `teams` 表有 `status` 列（text，默认 'pending'）
- `teams` 表有 `contact` 和 `phone` 列
- `teams` 表不再有 `approved` 列

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0003_teams_status_contact.sql
git commit -m "feat(db): migrate teams.approved to status enum, add contact/phone"
```

---

### Task 2: TeamRow 模型

**Files:**
- Modify: `lib/models/event.dart`（在文件末尾追加）

- [ ] **Step 1: 在 event.dart 末尾添加 TeamRow 类**

在 `PlayerRatingRow` 类之后追加：

```dart
class TeamRow {
  final String id;
  final String eventId;
  final String name;
  final String? captainId;
  final String? captainName;
  final String? captainAvatar;
  final String? contact;
  final String? phone;
  final String status;
  final DateTime? createdAt;

  const TeamRow({
    required this.id,
    required this.eventId,
    required this.name,
    this.captainId,
    this.captainName,
    this.captainAvatar,
    this.contact,
    this.phone,
    this.status = 'pending',
    this.createdAt,
  });

  factory TeamRow.fromMap(Map<String, dynamic> m) {
    final captain =
        (m['captain'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TeamRow(
      id: m['id'] as String,
      eventId: m['event_id'] as String,
      name: m['name'] as String,
      captainId: m['captain_id'] as String?,
      captainName: captain['display_name'] as String?,
      captainAvatar: captain['avatar_url'] as String?,
      contact: m['contact'] as String?,
      phone: m['phone'] as String?,
      status: (m['status'] as String?) ?? 'pending',
      createdAt:
          m['created_at'] != null ? DateTime.parse(m['created_at']) : null,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/event.dart
git commit -m "feat(model): add TeamRow class for teams panel"
```

---

### Task 3: Repository 方法

**Files:**
- Modify: `lib/repositories/events_repository.dart`（在 `insertTeam` 方法之前插入两个新方法）

- [ ] **Step 1: 在 events_repository.dart 的 `insertTeam` 方法之前添加 listTeams 和 updateTeamStatus**

在第 236 行（`insertTeam` 方法之前）插入：

```dart
  Future<List<TeamRow>> listTeams(String eventId) async {
    final rows = await supabase
        .from('teams')
        .select(
          '*, captain:profiles!captain_id(display_name, avatar_url)',
        )
        .eq('event_id', eventId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(TeamRow.fromMap)
        .toList();
  }

  Future<void> updateTeamStatus(String teamId, String status) async {
    await supabase
        .from('teams')
        .update({'status': status})
        .eq('id', teamId);
  }
```

注意：需要在文件顶部确认 `TeamRow` 已被导入（它在 `event.dart` 中，已通过现有 import 引入）。

- [ ] **Step 2: Commit**

```bash
git add lib/repositories/events_repository.dart
git commit -m "feat(repo): add listTeams and updateTeamStatus methods"
```

---

### Task 4: Provider

**Files:**
- Modify: `lib/providers.dart`（在 `eventTeamsCountProvider` 附近添加）

- [ ] **Step 1: 在 providers.dart 中 eventTeamsCountProvider 之后添加 eventTeamsProvider**

在 `eventTeamsCountProvider` 定义之后（约第 169 行之后）添加：

```dart
final eventTeamsProvider =
    FutureProvider.family<List<TeamRow>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).listTeams(eventId);
});
```

确认文件顶部已有 `import 'models/event.dart';`（已存在，TeamRow 在同一文件中）。

- [ ] **Step 2: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(provider): add eventTeamsProvider"
```

---

### Task 5: 国际化文案

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: 在 app_zh.arb 中 event_tab_chat 行之后添加队伍相关文案**

在 `"event_tab_chat": "讨论",` 之后添加：

```json
  "event_tab_teams": "队伍",
  "event_teams_summary": "已报名 {count}/{max} 支队伍",
  "@event_teams_summary": {
    "placeholders": {
      "count": { "type": "int" },
      "max": { "type": "int" }
    }
  },
  "event_teams_empty": "暂无队伍报名",
  "event_teams_approved": "已通过",
  "event_teams_pending": "待审核",
  "event_teams_rejected": "已拒绝",
  "event_teams_approve": "通过",
  "event_teams_reject": "拒绝",
  "event_teams_reject_confirm": "确定要拒绝该队伍的报名吗？",
  "event_teams_contact": "联系人",
```

- [ ] **Step 2: 在 app_en.arb 中 event_tab_chat 行之后添加对应英文文案**

```json
  "event_tab_teams": "Teams",
  "event_teams_summary": "{count}/{max} teams registered",
  "@event_teams_summary": {
    "placeholders": {
      "count": { "type": "int" },
      "max": { "type": "int" }
    }
  },
  "event_teams_empty": "No teams registered yet",
  "event_teams_approved": "Approved",
  "event_teams_pending": "Pending",
  "event_teams_rejected": "Rejected",
  "event_teams_approve": "Approve",
  "event_teams_reject": "Reject",
  "event_teams_reject_confirm": "Are you sure you want to reject this team?",
  "event_teams_contact": "Contact",
```

- [ ] **Step 3: 运行代码生成**

```bash
flutter gen-l10n
```

如果项目使用 `build_runner`，则运行：
```bash
dart run build_runner build
```

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add teams panel translations"
```

---

### Task 6: TeamsPanel 组件

**Files:**
- Create: `lib/features/events/panels/teams_panel.dart`

- [ ] **Step 1: 创建 teams_panel.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/toast.dart';
import '../../../widgets/typography.dart';

class TeamsPanel extends ConsumerWidget {
  final String eventId;
  final bool isCreator;
  final String? reviewMode;
  final int? teamsMax;

  const TeamsPanel({
    super.key,
    required this.eventId,
    required this.isCreator,
    this.reviewMode,
    this.teamsMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventTeamsProvider(eventId));
    return async.when(
      data: (teams) => _buildList(context, ref, teams),
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.tokens.accent)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<TeamRow> teams) {
    final l = context.l10n;
    final approved = teams.where((t) => t.status != 'rejected').length;
    final max = teamsMax ?? 0;

    if (teams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.groups_outlined, size: 40, color: context.tokens.inkDim),
              const SizedBox(height: 8),
              Text(
                l.event_teams_empty,
                style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<TeamRow>.from(teams)
      ..sort((a, b) {
        const order = {'pending': 0, 'approved': 1, 'rejected': 2};
        final cmp = (order[a.status] ?? 1).compareTo(order[b.status] ?? 1);
        if (cmp != 0) return cmp;
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.event_teams_summary(approved, max)),
          const SizedBox(height: 12),
          for (final team in sorted) _TeamTile(
            team: team,
            isCreator: isCreator,
            isManual: reviewMode == 'manual',
            onApprove: () => _updateStatus(context, ref, team.id, 'approved'),
            onReject: () => _confirmReject(context, ref, team.id),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String teamId,
    String status,
  ) async {
    try {
      await ref.read(eventsRepoProvider).updateTeamStatus(teamId, status);
      ref.invalidate(eventTeamsProvider(eventId));
      ref.invalidate(eventTeamsCountProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _confirmReject(
    BuildContext context,
    WidgetRef ref,
    String teamId,
  ) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_teams_reject),
        content: Text(l.event_teams_reject_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _updateStatus(context, ref, teamId, 'rejected');
  }
}

class _TeamTile extends StatelessWidget {
  final TeamRow team;
  final bool isCreator;
  final bool isManual;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TeamTile({
    required this.team,
    required this.isCreator,
    required this.isManual,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isRejected = team.status == 'rejected';
    return Opacity(
      opacity: isRejected ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: context.tokens.elev3,
                  backgroundImage: team.captainAvatar != null
                      ? NetworkImage(team.captainAvatar!)
                      : null,
                  child: team.captainAvatar == null
                      ? Text(
                          team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.inkSub,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                      if (team.captainName != null)
                        Text(
                          team.captainName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.tokens.inkSub,
                          ),
                        ),
                    ],
                  ),
                ),
                _StatusBadge(status: team.status),
              ],
            ),
            if (isCreator && (team.contact != null || team.phone != null)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 42),
                  if (team.contact != null) ...[
                    Icon(Icons.person_outline, size: 13, color: context.tokens.inkDim),
                    const SizedBox(width: 4),
                    Text(
                      team.contact!,
                      style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (team.phone != null) ...[
                    Icon(Icons.phone_outlined, size: 13, color: context.tokens.inkDim),
                    const SizedBox(width: 4),
                    Text(
                      team.phone!,
                      style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                    ),
                  ],
                ],
              ),
            ],
            if (isCreator && isManual && team.status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onReject,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.tokens.danger),
                        borderRadius: BorderRadius.circular(context.tokens.r1),
                      ),
                      child: Text(
                        l.event_teams_reject,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.danger,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.tokens.accent,
                        borderRadius: BorderRadius.circular(context.tokens.r1),
                      ),
                      child: Text(
                        l.event_teams_approve,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.accentInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, bg, fg) = switch (status) {
      'approved' => (l.event_teams_approved, context.tokens.accentSubtle, context.tokens.accent),
      'rejected' => (l.event_teams_rejected, context.tokens.elev3, context.tokens.inkDim),
      _ => (l.event_teams_pending, context.tokens.warnSubtle, context.tokens.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.tokens.r1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/events/panels/teams_panel.dart
git commit -m "feat(ui): add TeamsPanel component for event detail"
```

---

### Task 7: 在 EventDetailScreen 中接入队伍标签页

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart`

- [ ] **Step 1: 添加 import**

在文件顶部 import 区域（第 20-27 行附近），添加：

```dart
import 'panels/teams_panel.dart';
```

- [ ] **Step 2: 在 tabs 列表中插入 teams tab**

找到 `_buildContent` 方法中的 tabs 定义（第 124-130 行）：

```dart
    final tabs = [
      ('overview', l.event_tab_overview),
      ('bracket', l.event_tab_bracket),
      ('standings', l.event_tab_standings),
      ('scorers', l.event_tab_scorers),
      ('chat', l.event_tab_chat),
    ];
```

替换为：

```dart
    final tabs = [
      ('overview', l.event_tab_overview),
      ('teams', l.event_tab_teams),
      ('bracket', l.event_tab_bracket),
      ('standings', l.event_tab_standings),
      ('scorers', l.event_tab_scorers),
      ('chat', l.event_tab_chat),
    ];
```

- [ ] **Step 3: 在 switch 分支中添加 teams 面板**

找到 switch 表达式（第 163-169 行）：

```dart
                    child: switch (_tab) {
                      'overview' => OverviewPanel(event: event),
                      'bracket' => BracketPanel(eventId: event.id),
                      'standings' => StandingsPanel(eventId: event.id),
                      'scorers' => ScorersPanel(eventId: event.id),
                      _ => ChatPanel(eventId: event.id),
                    },
```

替换为：

```dart
                    child: switch (_tab) {
                      'overview' => OverviewPanel(event: event),
                      'teams' => TeamsPanel(
                        eventId: event.id,
                        isCreator: event.creatorId != null &&
                            event.creatorId == currentUserId,
                        reviewMode: event.reviewMode,
                        teamsMax: event.teamsMax,
                      ),
                      'bracket' => BracketPanel(eventId: event.id),
                      'standings' => StandingsPanel(eventId: event.id),
                      'scorers' => ScorersPanel(eventId: event.id),
                      _ => ChatPanel(eventId: event.id),
                    },
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(ui): wire teams tab into event detail screen"
```

---

### Task 8: 报名时根据 review_mode 设置 status

**Files:**
- Modify: `lib/features/events/widgets/bottom_cta.dart`

- [ ] **Step 1: 在 insertTeam payload 中加入 status 字段**

找到 `showRegisterSheet` 中的 insertTeam 调用（约第 259 行）：

```dart
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': contactC.text.trim(),
                      'phone': phoneC.text.trim(),
                    });
```

替换为：

```dart
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': contactC.text.trim(),
                      'phone': phoneC.text.trim(),
                      'status': event.reviewMode == 'manual'
                          ? 'pending'
                          : 'approved',
                    });
```

- [ ] **Step 2: 在报名成功后也 invalidate eventTeamsProvider**

在同一方法中，找到 invalidate 调用（约第 278 行）：

```dart
                    ref.invalidate(eventTeamsCountProvider(event.id));
                    ref.invalidate(isUserRegisteredProvider(event.id));
```

在其后添加一行：

```dart
                    ref.invalidate(eventTeamsCountProvider(event.id));
                    ref.invalidate(isUserRegisteredProvider(event.id));
                    ref.invalidate(eventTeamsProvider(event.id));
```

需要在文件顶部确认已导入 `providers.dart`（`eventTeamsProvider` 在其中定义，现有代码已使用 `eventTeamsCountProvider`，所以 import 已存在）。

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/widgets/bottom_cta.dart
git commit -m "feat: set team status based on event review_mode on registration"
```

---

### Task 9: 冒烟验证

- [ ] **Step 1: 启动开发服务器**

```bash
flutter run -d chrome
```

- [ ] **Step 2: 验证队伍标签页**

1. 打开任意赛事详情页，确认"队伍"标签页出现在"概览"和"赛程"之间
2. 如果没有队伍报名，应显示空状态（图标 + "暂无队伍报名"）
3. 尝试报名一个队伍，报名后切回"队伍"标签页，确认新队伍出现在列表中
4. 以创建者身份查看，确认能看到联系人和电话信息

- [ ] **Step 3: 验证审核功能（需 review_mode = 'manual' 的赛事）**

1. 创建一个 review_mode = 'manual' 的赛事
2. 用另一个账号报名
3. 以创建者身份查看队伍列表，确认显示"通过"和"拒绝"按钮
4. 点击"通过"，确认状态变为"已通过"
5. 再报名一个队伍，点击"拒绝"，确认弹出确认对话框，确认后状态变为"已拒绝"且显示灰色

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: add teams panel to event detail with review workflow"
```
