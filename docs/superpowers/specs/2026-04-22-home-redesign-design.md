# 首页重新设计 — 设计规格

## 概述

将当前首页从单一纵向滚动列表重构为 **Tab 分区页**，顶部 4 个 Tab（推荐 / 赛事 / 约球 / 发现）提供分类浏览体验。首页定位为各功能的**轻量发现入口**，底部导航栏保持不变，保留完整功能（Pickup Map、Events Hub）。

## 设计决策记录

| 决策项 | 选择 | 备选方案 | 理由 |
|--------|------|----------|------|
| 首页定位 | Tab 分区页 | 发现聚合页 / 信息流沉浸页 | 分类清晰，用户快速定位内容；可扩展性强 |
| 与底部导航关系 | 首页 Tab 轻量摘要，底部保留完整功能 | 精简底部 / 重新规划底部 | 避免功能丢失，两者定位不同 |
| Tab 数量与名称 | 4 个：推荐/赛事/约球/发现 | 5 个（文章独立 Tab） / 文章融入其他 Tab | "发现"合并动态+文章减少 Tab 数量，避免拥挤 |
| 推荐 Tab 布局 | 算法/时间混排信息流 | 精选聚合分区块 / 运营驱动 | 沉浸式浏览体验，统一的交互模式 |
| 发现 Tab 布局 | 混排信息流，卡片样式区分 | 二级子 Tab / 上下分区 | 与推荐 Tab 体验一致，减少认知负担 |
| 赛事 Tab 布局 | 按状态分组（直播→报名中→进行中→即将开始） | 时间线视图 / 热度排序 | 状态优先级最清晰，用户一眼看到最需关注的赛事 |
| 约球 Tab 布局 | 纯列表 + 筛选条 | 双模式切换 / 地图+列表融合 | 简洁高效，完整地图功能已在底部 Pickup Map |
| 数据加载策略 | 懒加载（切到时才加载） | 预加载相邻 Tab / 全部预加载 | 节省流量和首屏加载压力 |

## 架构

### 页面结构

```
HomeScreen (StatefulWidget + ConsumerWidget)
├── TopBar（城市选择 + 运动选择 + 搜索 + 收件箱）  ← 保持不变
├── TabBar（推荐 / 赛事 / 约球 / 发现）             ← 新增
├── TabBarView                                       ← 新增
│   ├── RecommendTab                                 ← 新增
│   ├── EventsTab                                    ← 新增
│   ├── PickupTab                                    ← 新增
│   └── DiscoverTab                                  ← 新增
└── BottomNav（首页 / 地图 / 赛事 / 我的）           ← 保持不变
```

### 各 Tab 组件结构

#### 推荐 Tab (RecommendTab)

算法/时间混排 Feed，包含以下卡片类型：

- **LiveMatchCard** — 直播赛事卡片（渐变背景，队伍 Logo + 大号比分 + 赛事信息 + 观看人数）
- **PickupFeedCard** — 约球卡片（发布者头像 + 场地名 + 时间/费用/距离 + 参与者头像 + "差N人"紧迫标签 + 加入按钮）
- **ActivityFeedCard** — 运动动态卡片（Strava 风格：头像 + 文字 + 结构化运动数据条[局数/胜负/时长] + 点赞评论）
- **EventFeedCard** — 赛事报名卡片（标签 + 赛事名 + 报名进度条 + 报名按钮）
- **ArticleFeedCard** — 文章卡片（The Athletic 风格：封面图 + 分类标签 + 标题 + 摘要 + 阅读时长）
- **PostFeedCard** — 纯文字动态卡片（头像 + 文字 + 标签 + 互动栏）

数据源：新增 `recommendFeedProvider`，聚合所有类型内容，按时间+权重排序。

#### 赛事 Tab (EventsTab)

按状态分组的赛事列表：

1. **正在直播**（置顶，带脉冲动画标记）— 渐变背景，两队对阵 + 比分 + 赛事阶段 + 观看人数
2. **报名中**（带进度条 + 报名按钮）— 赛事名 + 报名队伍数/总数 + 倒计时 + 进度条
3. **进行中**（带"查看"入口）— 赛事名 + 当前阶段 + 今日是否有赛程
4. **即将开始**（预告性质）— 赛事名 + 开始日期

每个分组有标题行带颜色编码（直播=红，报名=橙，进行中=绿，即将=紫）。

数据源：复用 `liveNowProvider`（直播）+ 扩展现有赛事查询按状态分组。

#### 约球 Tab (PickupTab)

顶部筛选条 + 列表：

**筛选条（横向滚动 ChipPill）：**
- 全部（默认选中）
- 距离排序
- 今天 / 明天 / 本周
- 难度（初级/中级/高级）
- 费用范围

**约球卡片（每条）：**
- 场地名称（大号加粗）
- 信息行：时间 + 费用 + 距离
- 底部行：参与者头像堆叠 + "N/M人" + 状态标签（"差X人"橙色 / "名额充足"绿色 / "已满"灰色）+ 加入按钮

数据源：复用 `livePickupsProvider`，新增筛选参数支持。

#### 发现 Tab (DiscoverTab)

动态与文章混排信息流：

**动态卡片（两种变体）：**

1. 结构化运动动态（Strava 风格）：
   - 头像 + 用户名 + 时间 + 场地
   - 文字内容
   - 运动数据条（局数 / 胜负 / 时长）— 紫色数字，小字标签
   - 互动栏（点赞 / 评论 / 分享）

2. 纯文字社交动态：
   - 头像 + 用户名 + 时间
   - 文字内容
   - 话题标签（#标签，紫色底色）
   - 互动栏

**文章卡片（The Athletic 风格）：**
- 左侧：分类标签（赛事解析/技术教学/...）+ 标题 + 摘要
- 右侧：封面图（80x80 圆角）
- 底部：浏览数 + 评论数 + 阅读时长

数据源：新增 `discoverFeedProvider`，合并 posts + articles 查询，按时间排序。

### 数据层变更

#### 新增 Provider

| Provider | 类型 | 数据源 | 用途 |
|----------|------|--------|------|
| `recommendFeedProvider` | FutureProvider | 聚合多表查询 | 推荐 Tab 混排 Feed |
| `discoverFeedProvider` | FutureProvider | posts + articles 表 | 发现 Tab 混排 Feed |
| `eventsByStatusProvider` | FutureProvider | events 表按状态分组 | 赛事 Tab 分组列表 |
| `filteredPickupsProvider` | FutureProvider.family | pickups 表 + 筛选参数 | 约球 Tab 带筛选列表 |

#### 新增/扩展模型

**FeedItem 扩展：** 现有的 `FeedItem` 密封类需新增以下子类型：
- `FeedPickup` — 约球信息（从 Pickup 模型映射）
- `FeedArticle` — 文章信息（新模型，区别于 FeedEvent）
- `FeedActivity` — 结构化运动动态（包含局数、胜负、时长字段）

**PickupFilter 模型（新增）：**
- `sortBy`: distance / time（排序维度）
- `dateRange`: today / tomorrow / thisWeek / all（时间筛选）
- `level`: beginner / intermediate / advanced / all（难度筛选）
- `feeRange`: (min, max)（费用区间）

#### 数据库变更

现有表结构基本满足需求，可能需要：
- `posts` 表：新增 `match_count`, `win_count`, `play_duration` 字段支持结构化运动动态
- 新增 `articles` 表（如果文章内容不复用 posts 表）：id, title, summary, body, cover_url, category, author_id, read_time_min, view_count, created_at

### 交互规范

**Tab 切换：**
- 支持点击 Tab 切换和左右滑动切换
- 使用 Flutter TabController + TabBarView 实现
- 懒加载：每个 Tab 首次切入时才发起数据请求
- Tab 切换动画：默认 TabBarView 滑动动画

**下拉刷新：**
- 每个 Tab 独立支持下拉刷新
- 刷新时 invalidate 对应 Tab 的 provider

**无限滚动：**
- 推荐 Tab、发现 Tab：支持分页加载（每次 20 条）
- 赛事 Tab：一次性加载全部（数量有限）
- 约球 Tab：支持分页加载

**筛选交互（约球 Tab）：**
- 点击筛选 Chip 切换激活状态
- 筛选变化时重新请求数据（通过 provider family 参数）
- "全部"与其他筛选互斥

**卡片点击导航：**
- 直播赛事 → `/worldcup/live/{matchId}`
- 约球 → `/pickup/{pickupId}`
- 赛事 → `/event/{eventId}`
- 文章 → `/article/{articleId}`（新路由）
- 用户动态 → `/post/{postId}`（新路由）或用户主页

### UI 规范

**Tab 栏样式：**
- 背景色：与 TopBar 一致（bg 层）
- 激活态：文字颜色 accent（#8B6CEF），底部 2.5px 指示条同色
- 非激活态：文字 inkMute（35% 不透明度）
- Tab 间距：等分宽度
- 字号：13px，激活态 font-weight 700，非激活态 500

**卡片样式：**
- 背景：elev1（#161622）
- 圆角：r3（14px）
- 内边距：12px
- 卡片间距：10px
- 统一使用现有 AppTokens 设计系统

**状态标签配色：**
- 直播 = `danger`（#FF3B6B）
- 报名中/差N人 = `warn`（#FF6B35）
- 进行中/名额充足 = 绿色（#4CAF50）
- 即将开始 = `accent`（#8B6CEF）

**运动数据条（Strava 风格）：**
- 背景：elev2（#1e1e32）
- 数据数字：accent 色，monospace 字体（fontMono）
- 标签文字：8px，inkMute

### 需要保留的现有功能

- TopBar（城市选择、运动选择、搜索、收件箱+未读红点）
- 下拉刷新（RefreshIndicator）
- 评分 CTA Banner（`_RateCtaBanner`）— 移入推荐 Tab Feed 中作为一种卡片类型
- 底部导航栏及其所有子页面

### 需要移除/替换的现有功能

- 现有的 `_LiveStrip`（直播轮播）→ 替换为推荐 Tab 中的 LiveMatchCard
- 现有的 `_LivePickupCard` 列表 → 替换为约球 Tab
- 现有的 `_ResultCard` / `_PostCard` / `_EventTeaserCard` 信息流 → 拆分到推荐 Tab 和发现 Tab
- 现有的"本地约球"分区 → 替换为约球 Tab

## 测试要点

- 四个 Tab 的懒加载是否正确（首次切入时加载，不预加载）
- Tab 滑动切换与点击切换的一致性
- 每个 Tab 的下拉刷新独立性
- 约球 Tab 筛选条的状态管理和数据刷新
- 推荐 Tab Feed 中多种卡片类型的正确渲染
- 赛事 Tab 状态分组在不同数据条件下的表现（无直播时隐藏直播组、无报名中时隐藏报名组等）
- 无限滚动分页加载的正确性
- 现有导航路由不被破坏（所有卡片点击跳转正常）
- 暗色/亮色主题适配
- 国际化文本

## 不在范围内

- 推荐算法实现 — 初期使用时间排序，算法推荐作为后续迭代
- 文章管理后台 — 文章内容暂由数据库 seed 或手动添加
- 发布动态/文章的入口 — 本次只做展示层，发布功能后续迭代
- 底部导航栏的改动 — 保持现状
