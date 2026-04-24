# 赛事详情页"队伍"标签页设计

## 目标

在赛事详情页新增"队伍"标签页，展示参赛队伍列表。创建者可在 manual 审核模式下批准/拒绝报名。

## 数据库改动

### 迁移 `0003_teams_status_contact.sql`

1. **teams.approved** (boolean) → **teams.status** (text)
   - 取值：`'pending'` | `'approved'` | `'rejected'`
   - 默认值：`'pending'`
   - 迁移时：`approved = true` → `'approved'`，`approved = false` → `'pending'`
   - 删除旧 `approved` 列

2. **新增列：**
   - `contact text` — 报名联系人
   - `phone text` — 报名电话

### 报名逻辑调整（bottom_cta.dart）

- 报名 insertTeam 时，根据赛事的 `review_mode` 决定 status：
  - `review_mode = 'auto'`（或 null）→ `status = 'approved'`
  - `review_mode = 'manual'` → `status = 'pending'`

## 数据模型

### TeamRow（新增，lib/models/event.dart）

```dart
class TeamRow {
  final String id;
  final String eventId;
  final String name;
  final String? captainId;
  final String? captainName;    // join profiles.display_name
  final String? captainAvatar;  // join profiles.avatar_url
  final String? contact;
  final String? phone;
  final String status;          // pending / approved / rejected
  final DateTime? createdAt;
}
```

## Provider

### `eventTeamsProvider(eventId)` — `FutureProvider.family<List<TeamRow>, String>`

查询：
```sql
select t.*, p.display_name, p.avatar_url
from teams t
left join profiles p on p.id = t.captain_id
where t.event_id = :eventId
order by
  case t.status
    when 'pending' then 0
    when 'approved' then 1
    when 'rejected' then 2
  end,
  t.created_at asc
```

排序逻辑：待审核排最前，已通过居中，已拒绝排末尾。

## Repository

### `events_repository.dart` 新增方法

- `listTeams(eventId)` — 查询队伍列表，join profiles
- `updateTeamStatus(teamId, status)` — 更新队伍审核状态

## UI 设计

### 标签页位置

在 "概况(overview)" 和 "对阵(bracket)" 之间插入 "队伍(teams)" 标签页。

tab 列表变为：overview → **teams** → bracket → standings → scorers → chat

### TeamsPanel 组件（lib/features/events/panels/teams_panel.dart）

**顶部汇总行：**
- 文字："已报名 N/M 支队伍"（N = approved + pending 数量，M = teamsMax）

**队伍列表项（所有用户可见）：**
- 左侧：队长头像（CircleAvatar，24px，无头像时取首字母）
- 中间：队名（主标题）+ 队长昵称（副标题）
- 右侧：状态标签
  - `approved` → 绿色 "已通过"
  - `pending` → 黄色 "待审核"
  - `rejected` → 灰色 "已拒绝"

**创建者额外信息：**
- 队伍行下方展示：联系人、电话（可点击拨打）
- manual 模式下 pending 状态的队伍：显示"通过"和"拒绝"两个操作按钮

**已拒绝队伍：**
- 整行降低透明度（opacity 0.5）
- 排在列表底部

**空状态：**
- 图标 + "暂无队伍报名" 提示文字

### 交互流程

1. 创建者点击"通过" → 调用 `updateTeamStatus(teamId, 'approved')` → 刷新列表
2. 创建者点击"拒绝" → 弹出确认对话框 → 调用 `updateTeamStatus(teamId, 'rejected')` → 刷新列表

## 涉及文件清单

| 类型 | 文件 | 改动 |
|------|------|------|
| 迁移 | `supabase/migrations/0003_teams_status_contact.sql` | 新建 |
| 模型 | `lib/models/event.dart` | 新增 TeamRow 类 |
| 仓库 | `lib/repositories/events_repository.dart` | 新增 listTeams、updateTeamStatus |
| Provider | `lib/providers.dart` | 新增 eventTeamsProvider |
| 面板 | `lib/features/events/panels/teams_panel.dart` | 新建 |
| 详情页 | `lib/features/events/event_detail_screen.dart` | 加 teams tab |
| 报名 | `lib/features/events/widgets/bottom_cta.dart` | insertTeam 时根据 review_mode 设 status |
| 国际化 | `lib/l10n/app_zh.arb` + `app_en.arb` | 新增队伍相关文案 |

## 不做的事情

- 不做队伍详情页（点击队伍后跳转到某个页面）
- 不做批量操作（全部通过/全部拒绝）
- 不做报名通知（审核通过/拒绝后推送通知给队长）
