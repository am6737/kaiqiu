# 球局 Flutter — Implementation Plan

> 这份文档写给后续会话（也可能是你本人）用的：**如何把当前的基础设施填成一个真实可用的 App**。
>
> 每个 section 都可以作为一个独立 session 的任务 brief：告诉 Claude 做哪一屏，它读完对应 section 就有足够信息动手。

---

## 0. 当前状态（2026-04-20）

基础设施已完成，`flutter analyze` 零告警。

**已有的能用的东西：**
- `lib/theme/tokens.dart` — 设计令牌（颜色、字号、间距）
- `lib/services/supabase.dart` — Supabase 客户端 + 认证 helper
- `lib/repositories/` — pickups / events / ratings 的 DB 访问
- `lib/models/` — Profile / Pickup / Event / Rating / Message
- `lib/widgets/` — Avatar · N · Label · LivePill · StatusDot · ChipPill · PrimaryButton · SportIcon · BottomNavShell
- `lib/routes.dart` — go_router 配置（5 Tab + 5 个 overlay 路由）
- `lib/features/*/` — 9 个屏幕的**空壳**，只有一行占位文案

**还没做的：**
- 每个屏幕的真实 UI（本文档的主题）
- 认证入口（邮箱/手机登录屏）
- 地图 SDK 集成
- Realtime 消息订阅
- 字体资产（JetBrainsMono）下载
- 测试

---

## 1. 实现顺序（强烈建议按此顺序）

| # | 屏幕 | 为什么这个顺序 | 工时估计 |
|---|------|----------------|----------|
| 1 | **认证入口**（新增） | 没登录没法玩 | 2h |
| 2 | **Home Feed** | App 的门面，建立数据模式 | 3h |
| 3 | **Pickup Detail** | 验证阵型图 + 报名闭环 | 2h |
| 4 | **Profile** | 建立个人数据模式（雷达图、趋势图） | 3h |
| 5 | **Post-Match Rating** | 评分写入，是差异化功能 | 2h |
| 6 | **Events Hub + Detail** | 长线价值功能 | 4h |
| 7 | **Pickup Map**（真实地图） | 需要接地图 SDK，先用占位 | 3h |
| 8 | **Create Event** | 组织者工具，低频 | 2h |
| 9 | **Messages**（Realtime） | 复杂度高，放最后 | 4h |
| 10 | **World Cup** | 后期 OB 流接入再做 | 2h |

**总估 ≈ 27h**，单人 1 周内冲得完 Tab 1-5，完整 P0 两周。

---

## 2. 通用约定（每屏必读）

### 2.1 State management — Riverpod

```dart
// 在 lib/providers/ 新建 provider 文件
final pickupsRepoProvider = Provider((_) => PickupsRepository());

final upcomingPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  return ref.read(pickupsRepoProvider).listUpcoming();
});
```

**屏幕里用：**
```dart
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(upcomingPickupsProvider);
    return async.when(
      data: (list) => _Feed(items: list),
      loading: () => const _Skeleton(),
      error: (e, _) => _Error(error: e, onRetry: () => ref.invalidate(upcomingPickupsProvider)),
    );
  }
}
```

### 2.2 设计令牌永远用 `T.*`

**❌ 不要：**`Color(0xFF00FF85)` / `16.0` / hard-coded 字号
**✅ 要：**`T.live` / `T.s4` / `T.fontMono`

需要新颜色？先加到 `theme/tokens.dart`。

### 2.3 数字/比分/评分永远用 `N` 组件

```dart
N('3.2', size: 14, weight: FontWeight.w700)   // ✅
Text('3.2', style: ...)                       // ❌
```

### 2.4 小标题用 `Label`（自动大写 + tracking）

```dart
Label('正在直播')   // → "正在直播"（灰、等宽、letter-spacing 1.2）
```

### 2.5 加载态 / 空态 / 错误态三件套

每个有异步数据的屏幕都要显式处理这三种状态。不要 `isLoading ? spinner : data`。用 `AsyncValue.when`。

### 2.6 React 源参考

每个屏幕在 React 原型里都有对应实现，改 UI 前**先对照 React 版看像素**。路径：
- `/home/coder/workspaces/qiuju/src/screens/*.jsx` — Vite 版（模块化，易读）
- `/home/coder/workspaces/design_extract/morning-and-evening-sports/project/screens-*.jsx` — 原始原型

---

## 3. 每屏详细方案

---

### 3.A 认证入口（新增 · 优先级最高）

**文件：** `lib/features/auth/sign_in_screen.dart`（新建目录）

**目标：** 未登录时拦截 app，提供 Email 登录 + 匿名登录两种入口。

**UI 结构：**
- 黑底全屏
- 顶部占 40% 高，居中放 `Logo(size: 48)` + 副标题 "业余体育社交"
- 中段：`TextField`（邮箱）+ `TextField`（密码）
- `PrimaryButton("登录 / 注册", variant: primary)` full-width
- 分割线 `—— 或 ——`
- `PrimaryButton("匿名体验", variant: ghost)` → `supabase.auth.signInAnonymously()`

**数据流：**
```dart
await supabase.auth.signUp(email: ..., password: ...);  // 新注册
// 或
await supabase.auth.signInWithPassword(email: ..., password: ...);
```

**路由集成：**
- `routes.dart` 加路由 `/sign-in`
- `GoRouter.redirect` 里判断 `!isSignedIn && location != '/sign-in'` → 跳登录
- 登录成功后 `context.go('/home')`

**验收：**
- 冷启动未登录 → 跳到 `/sign-in`
- 输入错误凭证 → 底部 SnackBar 提示
- 成功 → 跳 `/home`，能看到底部 Tab

**Prompt 模板（新 session 贴这个）：**
```
参考 /home/coder/workspaces/qiuju_app/IMPLEMENTATION_PLAN.md 第 3.A 节实现
认证入口。读完后直接在 lib/features/auth/ 下动手，结束时 flutter analyze
应该无告警。
```

---

### 3.B Home Feed

**文件：** `lib/features/home/home_screen.dart` + `home_widgets.dart`

**React 源：** `qiuju/src/screens/Home.jsx`（全文 395 行）

**目标：** 4 个模块由上至下：
1. **TopBar** — 城市 + 项目切换 + 搜索/通知图标
2. **LiveStrip** — 横向滚动直播比分卡
3. **CTA 横幅** — "给昨天的比赛打个分"（渐变背景 + 9.0 圆标）
4. **Feed List** — pickup / result / post / event 四种卡片混排

**数据需求：**
```dart
final liveMatchesProvider = FutureProvider((ref) async => ...);  // 3 场直播
final homeFeedProvider = FutureProvider((ref) async => ...);     // 混合流，倒序
final upcomingPickupsProvider = FutureProvider(...);              // 用于 pickup cards
```

**Supabase 查询：**
```sql
-- live matches: matches where status = 'live'（先 mock，本阶段没 OB 流）
-- home feed: union of recent pickups + recent matches + (future: posts)
```

现阶段 `homeFeedProvider` 可以只返回 pickups + 完成的 matches 混合，按 `created_at`/`played_at` 排序取前 20 条。

**组件拆分：**
- `TopBar` — 用 `Row` + `PopupMenuButton`（项目切换）
- `LiveStripCard` — 180×90 Card，含 `LivePill` + `N` 比分
- `RateCtaBanner` — 渐变 `Container` + `N('9.0', size: 16, color: T.live)`
- `PickupCard` — 见 3.C 的复用版
- `ResultCard` — grid `1fr auto 1fr`，左右队名 + 中间大比分
- `PostCard` — avatar + 文字 + 点赞评论数
- `EventTeaserCard` — 进度条 + 报名队伍数

**验收：**
- 能看到 3 条 live strip（先假数据也行）
- CTA 横幅点击 → `context.push('/rate/<最近一场 match id>')`
- Pickup card 点击 → `context.push('/pickup/$id')`
- 下拉刷新 invalidate provider

---

### 3.C Pickup Detail（球局详情）

**文件：** `lib/features/pickup/pickup_detail_screen.dart`

**React 源：** `qiuju/src/screens/Pickup.jsx` 第 181-375 行

**核心 UI：**
1. 顶部 200px `PhotoHalftone` 占位（替换为真实场地图）
2. 场地信息（状态点、名称、时间、费用、组织者）
3. **阵型图** — 340px 高，SVG 画球场线 + 按钮定位球员点（重点）
4. 详情 grid（水平要求、人数、场地类型、停车）
5. 迷你地图占位
6. 底部固定 CTA "报名参加 / 已报名"

**阵型图实现要点：**
```dart
// 用 Stack + Positioned 放球员点
// 球场线用 CustomPainter 画（参考 React SVG 的比例 100×100）
Stack(
  children: [
    CustomPaint(painter: FieldLinesPainter()),
    for (final slot in slots)
      Positioned(
        left: slot.x.toDouble() / 100 * boxWidth - 18,
        top: slot.y.toDouble() / 100 * boxHeight - 18,
        child: _PlayerDot(slot),
      ),
  ],
)
```

`_PlayerDot` — 36×36 圆，已填 vs 空位用不同 border (solid vs dashed)，空位加脉冲动画。

**数据流：**
```dart
final pickupDetailProvider = FutureProvider.family<PickupDetail, String>(
  (ref, id) async {
    final repo = ref.read(pickupsRepoProvider);
    final pickup = await repo.fetch(id);
    final slots = await repo.slotsFor(id);
    return PickupDetail(pickup: pickup, slots: slots);
  },
);
```

**报名闭环：**
- 用户点一个空位 → 弹底 sheet 选位置（或直接用那个 slot 的 position）
- 调 `repo.join(pickupId, userId, position, x, y)`
- 成功后 `ref.invalidate(pickupDetailProvider(id))`

**验收：**
- 打开能看到 4-3-3 阵型，7 位已填 + 4 位空位
- 点空位 → 乐观更新 + 后端写入
- 拒掉（已满 / RLS 错误）→ SnackBar

---

### 3.D Profile（我的 · 战绩档案）

**文件：** `lib/features/profile/profile_screen.dart` + `profile_widgets.dart`

**React 源：** `qiuju/src/screens/Profile.jsx`（406 行）

**模块：**
1. 顶部条（头像 + 名字 + 位置 tag）
2. **3D 翻转球员卡** — 正面（综合评分 + 头像占位 + 底部 4 数据） / 背面（雷达图 + 属性条）
3. 评分胶囊（RatingBadge — 已有组件，实现一下）
4. 4 宫格数据墙
5. `TrendChart` 本赛季进球趋势（area chart）
6. 荣誉墙、队友网络、比赛历史

**翻转卡实现：**
```dart
// 用 AnimatedBuilder + Transform.flip
AnimatedBuilder(
  animation: _rotation,
  builder: (_, __) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..setEntry(3, 2, 0.001)   // perspective
      ..rotateY(_rotation.value * pi),
    child: _rotation.value < 0.5 ? CardFront(u) : CardBack(u),
  ),
)
```

**雷达图 / 趋势图：**
用 `CustomPainter` 画。雷达 6 个顶点按 `cos/sin` 算坐标；面积用 `Path.lineTo` + `Path.close()` + 填充。

**数据需求：**
```dart
final myProfileProvider = FutureProvider((ref) async {
  final uid = currentUserId!;
  final row = await supabase.from('profiles').select().eq('id', uid).single();
  return Profile.fromMap(row);
});
final myRatingSummaryProvider = FutureProvider((ref) async {
  return ref.read(ratingsRepoProvider).playerSummary(currentUserId!);
});
final myHistoryProvider = FutureProvider(...);  // 最近 5 场
```

**验收：**
- 能看到自己的综合评分 + 攻防属性雷达
- 点卡片翻转流畅（700ms cubic-bezier）
- "去评分" 按钮跳 `/rate/<最近未评场次>`

---

### 3.E Post-Match Rating（赛后评分）

**文件：** `lib/features/rating/post_match_rating_screen.dart` + `rating_slider.dart`

**React 源：** `qiuju/src/screens/Rating.jsx` 第 138-316 行

**核心交互：**
1. 顶部 header：close + 进度 "3/9"
2. 进度条 9 段（已评/当前/未评三色）
3. 比分摘要卡
4. **当前球员卡**（头像、名字、位置、highlight tag）
5. **评分滑块**（0-10，step 0.5）
   - 自定义 `GestureDetector` + `CustomPainter`
   - 拖动时实时换色：<4 红 / <6 橙 / <8 白 / ≥8 绿
   - 大数字居中显示（60pt `N`，动态色）
6. 可选评语 `TextField`
7. 他人均分参考卡（不评自己时）
8. 底部：上一位 / 跳过 / 下一位

**Slider 实现关键：**
```dart
class RatingSlider extends StatefulWidget { ... }

// GestureDetector 的 onPanUpdate 算 x → value (0-10, 0.5 step)
onPanUpdate: (d) {
  final frac = (d.localPosition.dx / width).clamp(0.0, 1.0);
  setState(() => _value = (frac * 20).round() / 2);
  widget.onChange(_value);
},
```

**提交逻辑：**
```dart
Future<void> commit(int nextIdx) async {
  if (_ratings[player.id] != null) {
    await ratingsRepo.submit(
      matchId: match.id,
      raterId: currentUserId!,
      rateeId: player.id,
      score: _ratings[player.id]!,
      comment: _comment,
    );
  }
  if (nextIdx >= allPlayers.length) setState(() => _done = true);
  else setState(() { _idx = nextIdx; _comment = ''; });
}
```

**完成页：**
- 72×72 圆绿勾
- "评分已提交" 标题 + 信用分说明
- "查看评分榜" 按钮返回 event detail 的 ratings tab

**验收：**
- 拖动滑块流畅，颜色变化正确
- 提交 9 人评分写入 `ratings` 表
- 唯一约束生效（重复提交 upsert）
- 提交完成 +5 信用（先不加，后期算 cron）

---

### 3.F Events Hub + Detail

**文件：**
- `lib/features/events/events_hub_screen.dart`
- `lib/features/events/event_detail_screen.dart` + 5 个 panel

**React 源：** `qiuju/src/screens/Events.jsx`（620 行 — 最长的一个屏）

#### 3.F.1 Events Hub

**模块：**
1. 顶部 "赛事" 大标题 + 创建按钮
2. **World Cup banner**（紫色渐变 + live pill + 数据柱）
3. 3-tab `ongoing / registering / watch`
4. 事件卡列表

**EventRow 卡片：**
- 顶部 110px `PhotoHalftone`（线性条纹变体）
- 左上角报名中/进行中 pill
- 右上角奖金 pill
- 底部：报名队伍 + 进度条 + 截止时间

#### 3.F.2 Event Detail

**顶部：**
- 180px 主视觉图
- 下渐变 overlay + 状态点 + 赛事名

**KPI strip：** 队伍 / 场次 / 奖金 / 观众（4 列）

**6 个 Tab：**
1. `OverviewPanel` — 文案 + 规则列表 + 组织方
2. `BracketPanel` — **赛程树**（最复杂，3 列 QF/SF/Final，横向滚动）
3. `StandingsPanel` — 积分榜表格（6 列）
4. `ScorersPanel` — 射手榜（金银铜奖牌）
5. `RatingsPanel` — 评分榜（复用 Rating 屏的数据）
6. `ChatPanel` — 弹幕列表（预留，Phase 2 接 Realtime）

**BracketPanel 实现：**
用 `SingleChildScrollView(scrollDirection: horizontal)` + 三列 `Column`。每场用 `_MatchCard`（已完成显示比分+胜方高亮，未完成显示 `TBD` + 时间）。SF/Final 用 `Padding(top: ...)` 对齐。

**数据流：**
```dart
final eventDetailProvider = FutureProvider.family<EventDetail, String>(...);
final eventMatchesProvider = FutureProvider.family<List<Match>, String>(...);
final eventRatingsProvider = FutureProvider.family<List<PlayerRatingSummary>, String>(...);
```

**验收：**
- 6 tab 切换流畅，状态保持（切回 bracket 还是滚到原位置）
- 射手榜前 3 名显示金银铜奖牌
- 评分榜第 1 名点击进入球员评分详情（含 histogram + 热门评论）

---

### 3.G Pickup Map（真实地图）

**文件：** `lib/features/pickup/pickup_map_screen.dart`

**建议：** 用 `flutter_map`（OpenStreetMap 免费）先把交互闭环打通，**上线前**换高德/腾讯地图。

**步骤：**
1. `pubspec.yaml` 加 `flutter_map: ^7.0.0` + `latlong2: ^0.9.1`
2. 页面布局：全屏 `FlutterMap`，顶部搜索/过滤 chip 条叠加
3. 每个 pickup 作为 `MarkerLayer` 的 marker：圆形按钮含 `SportIcon` + 状态色 border
4. 底部 sheet（`DraggableScrollableSheet`）列出同城球局
5. 点击 marker → 上浮对应的 list row

**高德迁移路径：**
- 换成 `amap_flutter_map`（高德官方 SDK，需要开发者账号 + API key）
- Marker 换成 `BitmapDescriptor`（自绘 PNG 用 Canvas + PictureRecorder）

**验收：**
- 6 个 pin 在深圳大致范围内（用 mock 经纬度）
- 点 pin 底部 sheet 滑到对应 row
- 底 sheet 可展开/收起
- 点 row 跳 `/pickup/$id`

---

### 3.H Create Event（4 步向导）

**文件：** `lib/features/create_event/create_event_screen.dart` + `bracket_mini.dart`

**React 源：** `qiuju/src/screens/Create.jsx`（295 行）

**4 步：**
1. 赛事模板（4 个 radio 卡，含 `BracketMini` SVG 缩略图）
2. 基本信息（`Field` 组件 × 6：名称、开赛、结束、场地、报名费、奖金）
3. 报名设置（截止时间、审核方式、每队人数、队伍上限）
4. 发布预览（大卡预览 + 确认绿 banner）

**`BracketMini` 4 种变体：**
`knockout16` / `group8` / `wc` / `league` — 都用 `CustomPainter`（React 里是 SVG）。

**Field 组件：**
```dart
class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final bool mono;
  ...
}
```

**提交：**
```dart
await ref.read(eventsRepoProvider).create({
  'name': nameController.text,
  'template': tpl,
  ...
});
context.pop();  // 回赛事中心
```

**验收：**
- 4 步步进条正确高亮
- 上一步/下一步按钮状态切换
- 发布后新建 event 出现在 registering tab

---

### 3.I Messages（Realtime）

**文件：** `lib/features/messages/messages_screen.dart` + `chat_screen.dart`

**两层：**
1. 会话列表（当前 messages_screen.dart 位置）
2. 单会话聊天界面（新建路由 `/chat/:convId`）

**会话列表：**
- 数据：`conversation_members` join `conversations`，按 `updated_at` 倒序
- 每行：`Avatar` + 标题 + 最后一条消息预览 + 时间 + unread 圆点

**Realtime 订阅：**
```dart
// 在 AppWidget 的 initState 订阅所有自己参与的 conv 的新消息
final channel = supabase.channel('my-messages')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'messages',
    callback: (payload) {
      ref.invalidate(conversationListProvider);
      // 如果当前在该 conv 页面，append
    },
  )
  .subscribe();
```

**聊天界面：**
- `ListView.reverse` + pagination
- 底部 `TextField` + 发送按钮
- `ref.read(messagesRepo).send(convId, body)` 后无需手动刷新（Realtime 会推）

**验收：**
- 两个用户两端开 App，A 发消息 B 立刻看到
- 未读数在会话列表正确累加
- 进会话自动清零 unread

---

### 3.J World Cup

**文件：** `lib/features/events/world_cup_screen.dart`

**React 源：** `qiuju/src/screens/Events.jsx` 第 491-618 行

**模块：**
1. 240px 顶部 Hero（紫色渐变 + svg 点阵 + 大标题）
2. 焦点之战卡（实时比分 + 观看直播/竞猜按钮）
3. 球友竞猜分布条（胜/平/负 三段彩色柱）
4. 今日赛程列表

**本阶段实现建议：** 全部 mock 数据渲染，接真实 OB 流排到后面。

---

## 4. 跨屏基础工作

### 4.1 Auth Gate（优先做）

`routes.dart` 加 `redirect`：
```dart
final router = GoRouter(
  redirect: (ctx, state) {
    if (!isSignedIn && !state.matchedLocation.startsWith('/sign-in')) {
      return '/sign-in';
    }
    return null;
  },
  refreshListenable: _AuthListenable(),  // 监听 supabase.auth.onAuthStateChange
  ...
);
```

### 4.2 错误边界 + 全局 SnackBar

`app.dart` 加全局 `ScaffoldMessengerKey`，把 RLS / network 错误统一 `showSnackBar`。

### 4.3 Loading skeleton 组件

`widgets/skeleton.dart` — 用 `AnimatedBuilder` 闪烁效果的 placeholder Box，每屏的 loading 态都用它。

### 4.4 字体资产

```bash
mkdir -p assets/fonts
cd assets/fonts
curl -LO https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/ttf/JetBrainsMono-Regular.ttf
# 同样下载 Medium / SemiBold / Bold / ExtraBold
```

然后在 `pubspec.yaml` 恢复 `fonts:` section（参见当前 pubspec 注释）。

### 4.5 测试

每屏一个 widget test（装 `patrol` 会更顺手）：
- 打开屏幕能渲染（don't throw）
- 核心交互：点按钮 → 正确 side-effect

---

## 5. 如何用这份文档开新 session

**基础模板：**

```
你好。我在实现 /home/coder/workspaces/qiuju_app 这个 Flutter 项目，
基础设施已完成（见项目根 README.md）。

请读 IMPLEMENTATION_PLAN.md 第 3.X 节（[屏幕名]），按里面的方案实现。
动手前确认：
1. 理解了 React 源在什么位置，能打开看
2. 知道用哪些 provider / repository

完成后要求：
- flutter analyze 无告警
- 至少一个 widget test 覆盖核心交互
- 不改动其他屏幕的代码
```

**例：** 做 Post-Match Rating 屏

```
按 IMPLEMENTATION_PLAN.md 第 3.E 节实现赛后评分屏。
React 源参考 /home/coder/workspaces/qiuju/src/screens/Rating.jsx 第 138-316 行。
重点：RatingSlider 手势交互 + 颜色梯度。
完成后：flutter analyze 无告警 + 至少一个测试。
```

---

## 6. 已知坑 / 决策记录

| 坑 | 处理 |
|---|---|
| `flutter_map` 在国内连 OSM 慢 | 换镜像 tile URL，或直接换高德 |
| Supabase 免费版手机短信收费 | 先只用 Email + 匿名登录 |
| 阵型图在小屏被挤变形 | 固定 `AspectRatio(aspectRatio: 1)` |
| 评分 trigger 汇总太频繁 | 后期改成 cron job / materialized view，不靠 trigger |
| `Match` 类名撞 `dart:core.Match` | 用时写 `import '...' as models` 或改名 `EventMatch`（非紧急） |
| 高德/腾讯地图 SDK 仅支持真机 | 本地开发用 flutter_map，临发布换 |

---

## 7. Phase 后的路线

**Phase 2（产品化）：**
- 推送（`firebase_messaging` / 个推）
- 本地通知（距离开赛 2 小时提醒）
- 分享到微信/朋友圈（`share_plus`）
- 图片上传 + 压缩（`image_picker` + `flutter_image_compress`）
- 支付（微信支付 SDK）

**Phase 3（增长）：**
- 邀请裂变（邀请码 + 信用奖励）
- 地推活动页（运营工具）
- CI/CD（fastlane + GitHub Actions → TestFlight / 内测版）

---

## 8. 修订记录

- 2026-04-20 · v0.1 · 初版，基础设施完成时创建
