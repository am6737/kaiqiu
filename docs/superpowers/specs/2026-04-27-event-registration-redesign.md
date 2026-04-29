# 赛事报名详情重新设计

## 问题

当前赛事报名表单只收集「队伍名称」一个字段，联系人和电话从 profile 自动填充。对于正式足球赛事来说信息太少，但如果在报名时一次性收集所有信息又会让用户心智负担过大。

## 设计原则

- **报名那一刻摩擦最小化**：只收集必要信息完成报名动作
- **详细信息报名后补齐**：队伍详情页承载信息管理职责
- **组织者按需配置**：草根赛事走轻量流程，正式赛事可开启更多选项

## 整体架构

```
报名表单（轻量 Bottom Sheet）
    ↓ 提交成功
队伍详情页（信息管理中心）
    ← 补充球员名单、队伍简介等
```

组织者在创建赛事 Step 3 配置报名规则，控制报名模式和审核方式。

---

## 一、报名表单（轻量化）

### 队伍报名

以 Bottom Sheet 弹窗形式呈现，包含以下字段：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 队伍名称 | 文本输入 | 是 | 唯一必填文本 |
| 队徽 | 图片上传 | 否 | 可跳过，报名后在队伍详情补 |
| 联系人姓名 | 文本输入 | 是 | 从用户 profile 预填，允许修改 |
| 联系电话 | 文本输入 | 是 | 从用户 profile 预填，允许修改 |

交互细节：
- 联系人信息预填但可编辑（领队不一定是报名人本人）
- 底部显示引导文案：「报名后可在队伍详情中补充球员名单等信息」
- 提交成功后自动跳转到队伍详情页

### 个人报名（当组织者开启「队伍+个人」模式时）

同样以 Bottom Sheet 呈现：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 姓名 | 文本输入 | 是 | profile 预填 |
| 电话 | 文本输入 | 是 | profile 预填 |
| 擅长位置 | 单选 | 是 | 前锋/中场/后卫/门将 |

交互细节：
- 底部提示：「提交后由组委会分配队伍」
- 个人报名者在数据库中以 individual_registrations 表存储，不直接进入 teams 表
- 组织者可在后台将散客分配到已有队伍或组成新队伍

---

## 二、队伍详情/管理页（新增页面）

报名成功后的信息管理中心。分两种视角：

### 队长视角（可编辑）

页面结构从上到下：
1. **头部**：队徽 + 队名 + 报名时间 + 审核状态标签
2. **数据卡片行**：球员名单进度（如 8/11）、领队姓名
3. **提醒条**（条件显示）：球员名单未满时显示黄色警告
4. **球员名单区域**：
   - 列表展示已有球员（头像/球衣号 + 姓名 + 位置 + 角色标签）
   - 「+ 添加球员」按钮
   - 未满时显示空位占位提示
5. **队伍简介**：可编辑文本区域

### 添加球员交互

点击「+ 添加球员」弹出表单：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| 球员 | 用户搜索/手动输入 | 是 | 优先从应用内好友搜索，也可手动输入姓名 |
| 球衣号 | 数字输入 | 否 | 1-99 |
| 位置 | 单选 | 否 | 前锋/中场/后卫/门将 |

### 其他人视角（只读）

与队长视角布局一致，但：
- 不显示编辑按钮和添加按钮
- 不显示截止提醒
- 不显示空位占位

### 入口

- 报名成功后自动跳转
- 赛事详情页 → Teams Tab → 点击某支队伍进入
- 「我的赛事」→ 我报名的赛事 → 点击进入

---

## 三、组织者端配置（创建赛事 Step 3 增强）

在现有 Step 3（报名设置）中新增一个字段：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| 报名模式 | 单选 | 仅队伍报名 | 选项：「仅队伍报名」/「队伍+个人报名」 |

现有字段保持不变：
- 报名截止时间
- 审核方式（自动通过/组委会审核）
- 每队人数（默认 11）
- 队伍上限

---

## 四、数据模型变更

### events 表新增字段

```sql
registration_mode text default 'team_only'
  check (registration_mode in ('team_only', 'team_and_individual'))
```

### 新增 individual_registrations 表

```sql
create table public.individual_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events on delete cascade,
  user_id uuid references public.profiles,
  name text not null,
  phone text,
  position text check (position in ('forward', 'midfielder', 'defender', 'goalkeeper')),
  status text default 'pending' check (status in ('pending', 'assigned', 'rejected')),
  assigned_team_id uuid references public.teams,
  created_at timestamptz default now(),
  unique (event_id, user_id)
);
```

### teams 表补充使用现有字段

- `logo_url` — 队徽（现有字段，报名表单中开放上传）
- `contact` — 联系人姓名（现有字段，允许编辑而非只从 profile 读取）
- `phone` — 联系电话（现有字段，同上）
- `slogan` — 复用为队伍简介（现有字段）

### team_members 表补充

现有字段已满足：
- `jersey_number` — 球衣号
- `role` — captain/player

新增字段：
```sql
position text check (position in ('forward', 'midfielder', 'defender', 'goalkeeper'))
```

---

## 五、页面路由

| 页面 | 路由 | 说明 |
|------|------|------|
| 队伍详情页 | `/events/:eventId/teams/:teamId` | 新增页面 |
| 个人报名管理（组织者） | 赛事详情 Teams Tab 内新增 section | 在现有页面扩展 |

### 个人报名者的组织者分配流程

当赛事开启了「队伍+个人」模式时，Teams Tab 底部新增「散客报名」区域，列出所有个人报名者（姓名 + 位置）。组织者可以：
- 长按/点击某位散客 → 弹出已有队伍列表 → 选择分配到某队
- 分配后该散客自动加入对应队伍的 team_members，individual_registrations.status 变为 'assigned'
- 也可拒绝散客报名

---

## 六、不在本次范围

- 球衣颜色管理
- 球员年龄/身份验证
- 保险证明上传
- 缴费凭证上传
- 名单截止时间（独立于报名截止）
- 队伍间球员转会
