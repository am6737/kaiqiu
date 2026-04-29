# Event & Pickup In-App Notifications — Design Spec

## Overview

为约球（Event）和散场（Pickup）功能实现应用内通知。当关键事件发生时，由 PostgreSQL trigger 自动往 `notifications` 表插入记录。不涉及推送通知（FCM），仅数据库层面的通知创建。

## 方案

**数据库 Trigger**：在 `teams`、`individual_registrations`、`events`、`matches`、`pickup_slots` 表上建 `AFTER INSERT/UPDATE/DELETE` trigger，由 `security definer` 函数写入 `notifications` 表。

## 辅助函数

新增一个封装函数，所有 trigger function 统一调用：

```sql
create function notify(
  p_user_id uuid,
  p_type    text,
  p_title   text,
  p_body    text,
  p_icon    text,
  p_route   text
) returns void
```

内部执行 `INSERT INTO notifications (user_id, type, title, body, icon, route)`。使用 `security definer` + `set search_path = public` 绕过 RLS。

## Trigger 清单

### 赛事模块（Event）

#### Trigger 1: `trg_notify_team_change` on `teams`

**Function**: `fn_notify_team_change()`

| 场景 | 触发时机 | 通知对象 | type | icon | title | body | route |
|------|----------|----------|------|------|-------|------|-------|
| 队伍报名 | AFTER INSERT | 赛事创建者 (`events.creator_id`) | `match` | `how_to_reg` | "有新队伍报名" | "{team.name} 报名了你的赛事" | `/events/{event_id}` |
| 审核通过 | AFTER UPDATE `status` → `approved` | 队长 (`teams.captain_id`) | `match` | `check_circle` | "队伍审核通过" | "你的队伍 {team.name} 已通过审核" | `/events/{event_id}` |
| 审核拒绝 | AFTER UPDATE `status` → `rejected` | 队长 (`teams.captain_id`) | `match` | `cancel` | "队伍未通过审核" | "你的队伍 {team.name} 未通过审核" | `/events/{event_id}` |

**跳过条件**：
- INSERT 时：如果 `events.creator_id = teams.captain_id`（自己的赛事自己报名），不通知
- UPDATE 时：`OLD.status = NEW.status` 则跳过

#### Trigger 2: `trg_notify_individual_reg` on `individual_registrations`

**Function**: `fn_notify_individual_reg()`

| 场景 | 触发时机 | 通知对象 | type | icon | title | body | route |
|------|----------|----------|------|------|-------|------|-------|
| 个人报名 | AFTER INSERT | 赛事创建者 | `match` | `how_to_reg` | "有新个人报名" | "{reg.name} 报名了你的赛事" | `/events/{event_id}` |
| 分配到队伍 | AFTER UPDATE `status` → `assigned` | 该个人 (`user_id`) | `match` | `check_circle` | "你已被分配到队伍" | "你已被分配到 {team.name}" | `/events/{event_id}` |
| 报名被拒绝 | AFTER UPDATE `status` → `rejected` | 该个人 (`user_id`) | `match` | `cancel` | "个人报名未通过" | "你在赛事中的个人报名未通过审核" | `/events/{event_id}` |

**跳过条件**：
- INSERT 时：如果 `events.creator_id = reg.user_id`（组织者自己报名），不通知
- UPDATE 时：`OLD.status = NEW.status` 则跳过

#### Trigger 3: `trg_notify_event_status` on `events`

**Function**: `fn_notify_event_status()`

| 场景 | 触发时机 | 通知对象 | type | icon | title | body | route |
|------|----------|----------|------|------|-------|------|-------|
| 赛事开赛 | AFTER UPDATE `status` → `ongoing` | 所有 approved 队伍的队员 | `match` | `sports_soccer` | "赛事已开赛" | "{event.name} 已正式开赛" | `/events/{event_id}` |
| 赛事结束 | AFTER UPDATE `status` → `completed` or `done` | 所有 approved 队伍的队员 | `match` | `emoji_events` | "赛事已结束" | "{event.name} 已结束" | `/events/{event_id}` |

**通知范围**：`team_members` WHERE `team_id IN (SELECT id FROM teams WHERE event_id = NEW.id AND status = 'approved')`

**跳过条件**：
- `OLD.status = NEW.status` 则跳过
- 不通知赛事创建者本人（`auth.uid()` 跳过）

#### Trigger 4: `trg_notify_match_result` on `matches`

**Function**: `fn_notify_match_result()`

| 场景 | 触发时机 | 通知对象 | type | icon | title | body | route |
|------|----------|----------|------|------|-------|------|-------|
| 比赛结果 | AFTER UPDATE `done` = `false` → `true` | 双方队伍的队员 | `match` | `emoji_events` | "比赛结果出炉" | "{team_a} {score_a} - {score_b} {team_b}" | `/events/{event_id}` |

**通知范围**：`team_members` WHERE `team_id IN (team_a_id, team_b_id)` 且队伍 `status = 'approved'`

**跳过条件**：
- `OLD.done = true`（已经完赛过的不重复通知）
- 不通知操作者本人

### 约球模块（Pickup）

#### Trigger 5: `trg_notify_pickup_slot_join` on `pickup_slots`

**Function**: `fn_notify_pickup_slot_join()`

触发时机：`AFTER INSERT OR UPDATE`

| 场景 | 条件 | 通知对象 | type | icon | title | body | route |
|------|------|----------|------|------|-------|------|-------|
| 有人加入 | `NEW.user_id IS NOT NULL` 且 (`TG_OP = 'INSERT'` 或 `OLD.user_id IS NULL`) | 发起者 (`pickups.host_id`) | `pickup` | `sports_soccer` | "有人加入了你的约球" | "{user.name} 加入了你的约球" | `/pickup/{pickup_id}` |
| 约球满员 | 加入后 `count(user_id IS NOT NULL)` = `pickups.total` | 发起者 | `pickup` | `check_circle` | "你的约球已满员" | "你的约球已满员（{total}/{total}）" | `/pickup/{pickup_id}` |

**跳过条件**：
- `NEW.user_id = pickups.host_id`（主办人自己加入不通知）
- 满员通知不重复（如果发了满员就不再发加入通知）

#### Trigger 6: `trg_notify_pickup_slot_leave` on `pickup_slots`

**Function**: `fn_notify_pickup_slot_leave()`

触发时机：`AFTER DELETE`

| 场景 | 条件 | 通知对象 | type | icon | title | body | route |
|------|------|----------|------|------|-------|------|-------|
| 有人退出 | `OLD.user_id IS NOT NULL` | 发起者 | `pickup` | `logout` | "有人退出了你的约球" | "{user.name} 退出了你的约球" | `/pickup/{pickup_id}` |

**跳过条件**：
- `OLD.user_id = pickups.host_id`（主办人自己退出不通知）

## RLS 策略变更

`notifications` 表当前只有 `SELECT` 和 `UPDATE` 的 RLS policy。trigger function 使用 `security definer` 直接写入，不需要新增 INSERT policy。

## 不改动的部分

- `notifications` 表结构不变
- `NotificationItem` model 不变
- `NotificationsRepository` 不变
- 前端收件箱 UI 不变（已按 type 分组展示）

## 需要调整的部分

- `seed_demo_inbox()` 函数中的 demo 通知数据应保留——它仅在用户无通知时 seed，真实用户产生通知后不会触发 seed，两者不冲突

## 实现位置

所有 trigger 和 function 写在新的 migration 文件中（如 `0002_notification_triggers.sql`），不修改 `0001_schema.sql`。

## 通知 route 格式

- 赛事通知：`/event/{event_id}`（注意是单数 `/event/`，匹配 Go Router 的 `/event/:id`）
- 约球通知：`/pickup/{pickup_id}`

前端已有按 route 导航的逻辑（`notifications_tab.dart` 中 tap 跳转，非 branch root 的 route 用 `context.push()`）。
