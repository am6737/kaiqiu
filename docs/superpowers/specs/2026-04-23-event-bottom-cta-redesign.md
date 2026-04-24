# 赛事详情页底部按钮精简设计

**日期**: 2026-04-23
**状态**: 已确认

## 问题

赛事详情页底部 CTA 区域最多同时显示 5 个按钮（3 行），对创建者视角尤其拥挤：
- 第 1 行：关闭报名（状态主操作）
- 第 2 行：编辑赛事 + 取消赛事
- 第 3 行：观看直播 + 报名参赛

## 方案

精简底部为固定一行（最多 2 个按钮），将低频的"编辑赛事"和"取消赛事"收入右上角更多菜单。

## 设计详情

### 底部按钮区域（BottomCta）

固定一行，最多两个按钮并排：

| 角色 | 赛事状态 | 左侧按钮 | 右侧按钮 |
|------|---------|----------|----------|
| 创建者 | registering | 观看直播（置灰） | 关闭报名（primary） |
| 创建者 | scheduling | 观看直播（置灰） | 编排赛程（primary） |
| 创建者 | ongoing | 观看直播（可点击） | 完成赛事（warn） |
| 创建者 | completed/cancelled | 观看直播（置灰） | — |
| 普通用户 | registering | 观看直播（置灰） | 报名参赛（primary） |
| 普通用户 | 其他状态 | 观看直播（对应状态） | — |

观看直播按钮行为：
- `ongoing` 状态：可点击，导航到 `/worldcup/live/{eventId}`
- 其他状态：置灰禁用，保持可见

当只有一个按钮时（无右侧按钮），该按钮 full width。

创建者也可以报名参赛，但当创建者处于 registering 状态时，右侧优先展示"关闭报名"（管理操作优先于参赛操作）。

### 右上角更多菜单（EventHeader）

在分享按钮左侧增加 `⋮` (more_vert) 图标按钮：
- 仅创建者可见
- 仅赛事状态为 `draft`、`registering`、`scheduling` 时显示
- 使用 `PopupMenuButton` 实现

菜单项：
1. **编辑赛事** — 导航到 `/event/{eventId}/edit`
2. **报名参赛** — 仅 `registering` 状态且创建者未报名时显示，打开报名表单 Sheet
3. **取消赛事** — 红色文字，点击弹出确认对话框，确认后调用 `cancelEvent()`

### 样式

更多菜单按钮与返回/分享按钮保持一致的圆形半透明背景样式（`Color(0x66000000)`，36x36）。

## 改动文件

1. **`lib/features/events/widgets/bottom_cta.dart`**
   - 移除"编辑赛事 + 取消赛事"按钮行
   - 观看直播按钮增加置灰逻辑（非 ongoing 时 `onPressed: null`）
   - 调整创建者 registering 状态：右侧显示"关闭报名"而非"报名参赛"

2. **`lib/features/events/widgets/event_header.dart`**
   - 新增参数：`isCreator`（bool）、`eventStatus`（EventStatus）
   - 新增回调：`onEdit`、`onCancel`
   - 在分享按钮左侧渲染更多菜单按钮

3. **`lib/features/events/event_detail_screen.dart`**
   - 给 `EventHeader` 传入 `isCreator`、`event.status`、`onEdit`、`onCancel` 回调
   - `onCancel` 回调包含确认对话框逻辑（从 bottom_cta 迁移）
