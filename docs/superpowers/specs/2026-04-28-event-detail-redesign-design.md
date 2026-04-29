# 赛事详情页重构设计

## 背景

当前 `EventDetailScreen` 存在以下问题：

1. **组织者管理入口分散** — 编辑/取消在头部"更多"菜单，关闭报名/生成赛程/结束赛事在底部 CTA，审核队伍内嵌在 TeamsPanel，没有统一入口。
2. **Tab 层级过深** — "赛事"Tab 下嵌套了对阵图/积分榜/射手榜三个子 Tab，用户需要点两次才能到达目标内容。
3. **概览 Tab 内容稀薄** — 只有简介、规则、场馆、组织者，单独占一个 Tab 利用率低。
4. **BottomCta 逻辑过于复杂** — 同时处理组织者和普通用户的操作，大量 if-else 分支，难以维护。
5. **两种角色混合渲染** — 组织者和普通用户在同一页面通过条件判断显示/隐藏不同元素，代码耦合严重。

## 设计目标

- 组织者的管理操作集中到一个独立区域，入口清晰
- 普通用户的浏览和报名体验简洁直观
- 消除 Tab 嵌套，所有内容一步直达
- 大幅简化 BottomCta 逻辑
- 保持现有数据层（models、repositories、providers）不变

## 页面整体结构

```
┌─────────────────────────────────┐
│  封面图 (240px)                  │
│  ← 返回              分享 →     │
│  ● 状态标签                      │
│  📍 场馆名                       │
│  赛事标题                        │
├─────────────────────────────────┤
│  ▼ 赛事信息（可展开/收起）        │
│  简介 / 规则 / 场馆导航 / 组织者  │
├─────────────────────────────────┤
│  KPI 数据条：队伍 | 比赛 | 奖金   │
├─────────────────────────────────┤
│  Tab 栏（横向滚动）               │
│  队伍 / 对阵 / 积分 / 射手 / 聊天 [/ 管理]  │
├─────────────────────────────────┤
│                                 │
│  Tab 内容区                      │
│                                 │
├─────────────────────────────────┤
│  底部 CTA（仅普通用户可见）        │
└─────────────────────────────────┘
```

## 详细设计

### 1. 头部区域 — 融合概览信息

**EventHeader** 保持现有封面图+标题+状态的布局不变。

在 KPI 数据条上方新增一个**可展开/收起的"赛事信息"区域**：

- **默认状态**：收起，显示一行赛事简介摘要（截断），右侧有展开箭头图标
- **展开后**显示完整内容：
  - 赛事简介文字（多行）
  - 比赛规则列表（赛制格式、上下半场时长、换人规则、牌规）
  - 场馆信息卡：场馆名 + 详细地址 + "导航"按钮（调用 MapLauncher）
  - 组织者卡片：头像 + 名字，点击跳转 `/user/:creatorId`

**头部操作栏简化**：
- 左上：返回按钮（保持不变）
- 右上：分享按钮（保持不变）
- **删除组织者的 `_MoreMenu`**（编辑/代报名/取消赛事全部移到管理 Tab）

**涉及文件**：
- `lib/features/events/widgets/event_header.dart` — 删除 `_MoreMenu`
- `lib/features/events/event_detail_screen.dart` — 在 EventHeader 和 KpiStrip 之间插入新的 `_EventInfoSection` 可展开组件

### 2. Tab 结构

#### 角色与 Tab 映射

| 角色 | Tab 列表 |
|------|----------|
| 普通用户 | 队伍 · 对阵 · 积分 · 射手 · 聊天 |
| 组织者（`event.creatorId == currentUserId`） | 队伍 · 对阵 · 积分 · 射手 · 聊天 · **管理** |

#### 默认 Tab 根据赛事状态智能切换

| 赛事状态 | 默认 Tab | 理由 |
|---------|---------|------|
| `draft` / `registering` | 队伍 | 报名期最关心谁报了名 |
| `scheduling` / `ongoing` | 对阵 | 比赛期最关心赛程和比分 |
| `completed` | 积分 | 结束后最关心最终排名 |
| `cancelled` | 队伍 | 展示已有信息 |

#### Tab 栏实现

使用横向滚动式 Tab 栏（`isScrollable: true`），5-6 个 Tab 在手机端显示无压力。

**涉及文件**：
- `lib/features/events/event_detail_screen.dart` — 重写 `_Tabs` 组件和 tab 切换逻辑

### 3. 各 Tab 内容

#### 队伍 Tab

原 `TeamsPanel`，做以下简化：
- **删除内嵌的审核按钮**（批准/拒绝）— 移到管理 Tab
- **删除 `_IndividualRegistrationsSection`** — 移到管理 Tab
- 保留：队伍列表、状态徽章、队名、队长信息
- 点击队伍行 → 跳转 `/event/:eventId/team/:teamId`

**涉及文件**：`lib/features/events/panels/teams_panel.dart`

#### 对阵 Tab

原 `BracketPanel`，**不变**。从 CompetitionPanel 中解耦为独立 Tab。

**涉及文件**：`lib/features/events/panels/bracket_panel.dart`（无需修改内容）

#### 积分 Tab

原 `StandingsPanel`，**不变**。从 CompetitionPanel 中解耦为独立 Tab。

**涉及文件**：`lib/features/events/panels/standings_panel.dart`（无需修改内容）

#### 射手 Tab

原 `ScorersPanel`，**不变**。从 CompetitionPanel 中解耦为独立 Tab。

**涉及文件**：`lib/features/events/panels/scorers_panel.dart`（无需修改内容）

#### 聊天 Tab

原 `ChatPanel` + `ChatInput`，**不变**。

**涉及文件**：`lib/features/events/panels/chat_panel.dart`（无需修改内容）

### 4. 管理 Tab（新增，组织者专属）

新建 `lib/features/events/panels/manage_panel.dart`。

分为三个区域，纵向排列：

#### a) 赛事状态卡

显示当前赛事状态，附带一个醒目的下一步操作按钮：

| 当前状态 | 按钮文字 | 操作 |
|---------|---------|------|
| `registering` | 关闭报名 | `updateEventStatus(eventId, 'scheduling')` |
| `scheduling` | 生成赛程 | 跳转 `/event/:id/schedule` |
| `ongoing` | 结束赛事 | `updateEventStatus(eventId, 'completed')` |
| `completed` | 无按钮 | 显示"赛事已结束"完成标识 |
| `cancelled` | 无按钮 | 显示"赛事已取消"标识 |

所有状态变更操作需二次确认弹窗。

#### b) 报名审核区

- 顶部统计行：待审核 x · 已通过 x · 已拒绝 x
- 待审核队伍列表（`status == 'pending'` 的 TeamRow）：
  - 每行：队名 + 队长头像 + 联系人 + 电话
  - 操作按钮：「批准」/「拒绝」
  - 调用 `eventsRepo.updateTeamStatus(teamId, status)`
- 当 `registrationMode == 'team_and_individual'` 时，额外显示个人报名列表：
  - 每行：姓名 + 位置 + 联系电话
  - 操作：分配到队伍（`assignIndividualToTeam`）/ 拒绝（`rejectIndividualRegistration`）

数据来源：复用 `eventTeamsProvider(eventId)` 和 `individualRegistrationsProvider(eventId)`。

#### c) 赛事设置区

三个操作入口，列表样式：

| 操作 | 行为 |
|------|------|
| 编辑赛事信息 | 跳转 `/event/:id/edit`（进入 CreateEventScreen 编辑模式） |
| 代队报名 | 弹出 `showRegisterSheet`（与当前逻辑一致） |
| 取消赛事 | 二次确认弹窗 → `eventsRepo.cancelEvent(eventId)` → 跳转 `/events` |

"取消赛事"仅在 `draft` / `registering` / `scheduling` 状态可用，其他状态置灰。

### 5. 底部 CTA — 大幅简化

仅对**非组织者的普通用户**可见。单按钮设计，不再使用双按钮布局：

| 条件 | 按钮 | 样式 |
|------|------|------|
| `registering` + 未报名 + 未满员 + 未截止 | 立即报名 | 主色 filled |
| `registering` + 已报名 | 取消报名 | outlined 次要样式 |
| `ongoing` + 有直播比赛 | 观看直播 | 主色 filled |
| 其他所有情况 | **隐藏整个底部区域** | — |

点击"立即报名"：
- 若 `registrationMode == 'team_and_individual'` → 先弹出模式选择（团队/个人），再进入对应 sheet
- 若 `registrationMode == 'team_only'` → 直接弹出团队报名 sheet

报名 Sheet 的内容和逻辑保持不变。

**涉及文件**：`lib/features/events/widgets/bottom_cta.dart` — 重写，删除全部组织者逻辑

### 6. 删除的文件/组件

| 文件/组件 | 处理方式 |
|----------|---------|
| `lib/features/events/panels/overview_panel.dart` | 删除文件，内容迁移到 `_EventInfoSection` |
| `lib/features/events/panels/competition_panel.dart` | 删除文件，子 Tab 各自独立为主 Tab |
| `EventHeader._MoreMenu` | 删除组件，功能移到 ManagePanel |
| `TeamsPanel` 中的审核按钮和 `_IndividualRegistrationsSection` | 删除，移到 ManagePanel |
| `BottomCta` 中的组织者相关逻辑 | 删除 |

### 7. 新增的文件

| 文件 | 用途 |
|------|------|
| `lib/features/events/panels/manage_panel.dart` | 管理 Tab 面板 |

### 8. 不变的部分

- 数据模型（`lib/models/event.dart`）— 不修改
- 数据仓库（`lib/repositories/events_repository.dart`）— 不修改
- Providers（`lib/providers.dart`）— 不修改，复用现有 provider
- KpiStrip — 不修改
- BracketPanel / StandingsPanel / ScorersPanel / ChatPanel — 内容不修改，仅解耦引用方式
- TeamDetailScreen — 不修改
- 创建赛事流程 — 不修改
- 路由 — 不新增路由，仅调整 EventDetailScreen 内部 Tab 切换

## 导航流向（重构后）

```
EventDetailScreen (/event/:id)
│
├── 头部
│   ├── [返回] → pop
│   ├── [分享] → share sheet
│   └── [赛事信息展开] → 内嵌展开
│       ├── [导航] → MapLauncher
│       └── [组织者] → /user/:creatorId
│
├── 队伍 Tab
│   └── [点击队伍] → /event/:id/team/:teamId
│
├── 对阵 Tab
│   ├── [点击比赛] → /event/:id/match/:matchId
│   └── [点击直播] → /event/:id/match/:matchId/live
│
├── 积分 Tab
│   └── [点击队伍行] → TeamSheet (bottomSheet)
│
├── 射手 Tab
│   └── [点击射手] → ScorerSheet (bottomSheet)
│
├── 聊天 Tab
│   └── 发送消息/图片
│
├── 管理 Tab (组织者)
│   ├── [关闭报名] → 确认弹窗 → updateStatus
│   ├── [生成赛程] → /event/:id/schedule
│   ├── [结束赛事] → 确认弹窗 → updateStatus
│   ├── [批准/拒绝队伍] → updateTeamStatus
│   ├── [编辑赛事] → /event/:id/edit
│   ├── [代队报名] → RegisterSheet
│   └── [取消赛事] → 确认弹窗 → cancelEvent → /events
│
└── 底部 CTA (普通用户)
    ├── [立即报名] → RegisterSheet → /event/:id/team/:teamId
    ├── [取消报名] → 确认弹窗 → cancelRegistration
    └── [观看直播] → /worldcup/live/:id
```
