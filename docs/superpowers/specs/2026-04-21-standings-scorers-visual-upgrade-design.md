# 积分榜 & 射手榜视觉升级 设计文档

**Status:** Draft
**Date:** 2026-04-21
**Owner:** am6737

> **更新 (2026-04-21)**：本 spec 原先在"不做 (YAGNI)"里写过不把**评分榜**(`ratings` Tab) 移到比赛详情。该结论已被推翻——ratings Tab 已整体搬到比赛详情子页 `/event/:eventId/match/:matchId/ratings`（文件 `lib/features/events/match_ratings_screen.dart`），赛事详情 Tab 从 6 个减为 5 个（`overview / bracket / standings / scorers / chat`）。本 spec 继续聚焦 standings + scorers 的视觉升级，和 ratings 搬迁互不干涉。

## 一、目标

提升赛事详情页 (`event_detail_screen.dart`) 里**积分榜**和**射手榜**两个 tab 的视觉表现：

1. 把现在偏小的队徽（32×32 纯色方块）和球员头像（48×48 Unsplash 随机人像）换成**真实足坛豪门的队徽**和**真实球星照片**，让 demo 数据更有感染力。
2. 参照"世界杯"专区 (`world_cup_screen.dart`) 的仪式感，为榜单顶部加入 **hero 卡**：
   - 积分榜：Top 1 vs Top 2 的"榜首之争"双雄对决卡
   - 射手榜：Top 1 的金靴独立大卡 + Top 2/3 的银/铜堆叠卡
3. 整体上加大 logo / 头像尺寸，拉齐视觉层次。

**队名和球员名保留原样**（"龙岗狼队"、"陈子睿" 等），只替换图片资源。名字和图片不匹配是已知取舍，可接受。

## 二、约束与不做的事

**做:**

- 新增 `lib/data/demo_team_assets.dart`：稳定哈希地把 demo 队名映射到真实豪门（logo URL + 主色）
- 改 `lib/data/demo_images.dart` 的 `playerAvatarByName`：把现有 9 位 demo 球员的 Unsplash URL 替换为真实球星的 Wikipedia Commons 照片 URL
- 在 `_StandingsTable` 顶部插入 Top 2 hero 卡；列表行队徽从 32 放大到 44
- 把 `_ScorersPanel` 拆成 Top 1 Hero / Top 2-3 stacked / 第 4 名起列表 三段
- hero 卡的点击行为复用现有 `_showTeamSheet` / `_showScorerSheet`

**不做 (YAGNI):**

- 不新建数据模型、不改数据库 schema（仅 demo 层面替换 URL）
- 不把图片打包进 `assets/`（Wikipedia 直链 + CachedNetworkImage 已足够）
- 不做队名 → 真实队名的渲染替换（名字保留，只换图）
- 不做主题色深浅自适应以外的动效（比如 hero 卡渐变动画、金靴粒子效果）
- 不改 `TeamBadge` / `NetworkAvatar` 两个底层 widget 的 API，只在调用点传入新的 url
- 不改世界杯屏（虽然那边也是色块 chip，但本次不扩大范围）
- 不改球员详情页 `_ScorerSheet` 内部布局（里面的头像尺寸维持现状）

## 三、架构总览

```
event_detail_screen.dart
 ├── _StandingsTable   （已存在，改造）
 │    ├── _StandingsHero (new)           ← Top 1 vs Top 2，双雄对决
 │    └── 紧凑列表行（现有，队徽 32 → 44，logoUrl 从 demoClubFor() 拿）
 │
 └── _ScorersPanel     （已存在，改造）
      ├── _GoldenBootHero (new)          ← Top 1
      ├── _MedalCard(silver) (new)       ← Top 2
      ├── _MedalCard(bronze) (new)       ← Top 3
      └── 紧凑列表卡（现有 _ScorerCard，rank >= 4）

lib/data/
 ├── demo_team_assets.dart (new)         ← 队名 → {logoUrl, primaryColor}
 └── demo_images.dart (updated)          ← playerAvatarByName 换 9 个球星照片

lib/widgets/
 ├── team_badge.dart                     ← 不动，调用点传 logoUrl
 └── network_avatar.dart                 ← 不动，调用点传 size / url
```

## 四、积分榜视觉方案

### 4.1 Hero 卡（Top 1 vs Top 2，双雄对决）

当 `rows.length >= 2` 时在表头之前渲染；`rows.length < 2` 时退化为不显示 hero、直接进列表。

**尺寸与结构**

- 卡片高度约 **170**，外 margin `EdgeInsets.fromLTRB(16, 14, 16, 10)`
- 背景：`context.tokens.elev2` 纯色（不走两队主色渐变 — 简化实现，`DemoClub.primaryArgb` 本次仅保留作为 follow-up 扩展字段，不参与渲染）
- 边框：1pt accent 40% 透明度（世界杯焦点战卡一致思路）
- 圆角：`context.tokens.r3`
- 内部 padding：`EdgeInsets.symmetric(horizontal: 16, vertical: 16)`

**结构（外层 Column，自上而下两行）**

**第 1 行**：`Row` → `Label('榜首之争')` + `Spacer()` + 小字 `剩 N 轮` (N = 剩余未开打场次，若计算不出来就省略整段小字)

**第 2 行**：`Row`（`crossAxisAlignment: center`），三块：

- **左块（`Expanded`，Top 1）**：`Column(mainAxisAlignment: center)`
  - `TeamBadge(size: 72, logoUrl: demoClubFor(rank1.team).logoUrl)`
  - 6pt
  - `Text(rank1.team, 14pt, w600)`
  - 2pt
  - `Label('榜首', color: accent)`
- **中块（固定宽度 ~110，不用 Expanded）**：`Column(mainAxisAlignment: center)`
  - `Row`：`N('${rank1.pts}', 40, w800, accent)` · `Text(' - ', inkDim, 18)` · `N('${rank2.pts}', 40, w800, ink)`
  - 4pt
  - `Label('积分差 ${rank1.pts - rank2.pts}')`（inkSub）
- **右块（`Expanded`，Top 2）**：结构对称于左块，`Label` 改为 `'次席'`

**交互**

- 左列 tap 区域 → `_showTeamSheet(context, standing: rank1, ...)`
- 右列 tap 区域 → `_showTeamSheet(context, standing: rank2, ...)`
- 用 `InkWell` + 自身圆角裁剪，不整卡 tap（中间数字区不响应，避免歧义）

### 4.2 紧凑列表行（第 3 名起 / 退化时全部）

保持现有表格结构。唯一改动：

- 队徽容器 `width: 32, height: 32` → `width: 44, height: 44`
- 把原来裸 `Container` 的颜色方块**换成 `TeamBadge(name, logoUrl: demoClubFor(team).logoUrl, size: 44)`**
- 因 logo 变大，行垂直 padding 从 `vertical: 12` 调到 `vertical: 14`
- 行左右内容的其他 Sized（rank 24，W/D/L 各 32，pts 40）**保持不变**

**表头行**保持不变。

## 五、射手榜视觉方案

设 `rows = 前 N 名`：

- `rows.length == 0` → 空态文案，不变
- `rows.length == 1` → 只渲染金靴 Hero
- `rows.length == 2` → 金靴 Hero + 银牌卡
- `rows.length == 3` → 金靴 + 银 + 铜
- `rows.length >= 4` → 金靴 + 银 + 铜 + 列表（第 4 名起）

整体外层 padding：`EdgeInsets.fromLTRB(16, 14, 16, 0)`（不变）；各段之间 `SizedBox(height: 10)`。

### 5.1 金靴 Hero 卡（Top 1）

- 高约 **120**，圆角 `r3`
- 背景：金色 tint `Color(0x14FFD700)`（深浅模式同一值，金色在深浅下都能读）；边框 1pt 金色 `Color(0x66FFD700)`
- 内部 `Padding(horizontal: 16, vertical: 14)`，Row:
  - 左：`NetworkAvatar(row.name, url: avatarUrl, size: 96, square: true)`，外层 2pt 金色边框（通过 `Container` + `BoxDecoration.border` 实现）
  - `SizedBox(width: 14)`
  - 中（Expanded，crossAxisAlignment.start）：
    - `Label('金靴得主 · GOLDEN BOOT', color: accent)`
    - 4pt
    - `Text(row.name, 18pt, w700, ink)`
    - 4pt
    - `Text('${row.matches} 场 · 场均 ${(row.goals / row.matches).toStringAsFixed(2)} 球', 11pt, inkSub)`（`row.matches == 0` 时省略场均）
  - 右：`Column`
    - `N('${row.goals}', size: 32, weight: w800, color: accent)`
    - `Label('球')`

整卡外层 `Material + InkWell` 覆盖整卡 tap → `_showScorerSheet(...)` （和现在列表行一致）。

### 5.2 银 / 铜卡（Top 2、Top 3，上下堆叠）

每张卡结构类似但稍小：

- 高约 **88**，圆角 `r2`
- 背景：`context.tokens.elev2`，边框 1pt 对应奖牌色（银 `Color(0x66C0C0C0)`，铜 `Color(0x66CD7F32)`）
- 内部 Row:
  - 左：奖牌圈标 `width: 24` 容器，数字 2 / 3 写在奖牌色圆里（银/铜），12pt w800
  - `SizedBox(width: 10)`
  - `NetworkAvatar(row.name, url, size: 72, square: true)`，外层 2pt 奖牌色边框
  - `SizedBox(width: 12)`
  - Expanded 文本列：球员名 (15pt w600) + `Label(matches + 场均)` (如上)
  - 右：`N(goals, 24, w700, accent)` + `Label('球')`

点击整卡 → `_showScorerSheet(...)`。

### 5.3 列表（第 4 名起）

完全沿用现有 `_ScorerCard` 的布局。唯一改动：

- rank > 3 走这里，所以原有的 `_medal` 奖牌圈渲染分支**永远走不到**。但 `_ScorerCard` 内部保持现样本兼容逻辑（rank <= 3 的分支留着不删，因为参数是通用的，改起来涉及类型迁移；简单起见保留死代码路径）。

**小补记：** `_ScorerCard` 的 `_medal` 分支如果在 review 时觉得碍眼再做清理；本次实现允许保留。

## 六、图片资源方案

### 6.1 队徽 — `lib/data/demo_team_assets.dart`（新增）

```dart
class DemoClub {
  final String realName;   // "Real Madrid" / "Barcelona" ... 仅用于注释和调试
  final String logoUrl;    // Wikipedia Commons 的 upload.wikimedia.org 直链
  final int primaryArgb;   // 主色（HEX），供 hero 卡渐变用
  const DemoClub(this.realName, this.logoUrl, this.primaryArgb);
}

class DemoTeamAssets {
  static const List<DemoClub> _pool = [
    DemoClub('Real Madrid',   '<wiki svg url>', 0xFFFEBE10),
    DemoClub('FC Barcelona',  '<wiki svg url>', 0xFFA50044),
    DemoClub('Man United',    '<wiki svg url>', 0xFFDA291C),
    DemoClub('Man City',      '<wiki svg url>', 0xFF6CABDD),
    DemoClub('Liverpool',     '<wiki svg url>', 0xFFC8102E),
    DemoClub('Bayern Munich', '<wiki svg url>', 0xFFDC052D),
    DemoClub('Paris SG',      '<wiki svg url>', 0xFF004170),
    DemoClub('Juventus',      '<wiki svg url>', 0xFF000000),
    DemoClub('AC Milan',      '<wiki svg url>', 0xFFFB090B),
    DemoClub('Inter Milan',   '<wiki svg url>', 0xFF0068A8),
    DemoClub('Chelsea',       '<wiki svg url>', 0xFF034694),
    DemoClub('Arsenal',       '<wiki svg url>', 0xFFEF0107),
  ];

  /// 按队名稳定哈希选豪门：同一个 teamName 永远对应同一个 club。
  static DemoClub forTeamName(String teamName) {
    final idx = _stableHash(teamName) % _pool.length;
    return _pool[idx];
  }

  static int _stableHash(String s) {
    var h = 0;
    for (final r in s.runes) {
      h = (h * 131 + r) & 0x7FFFFFFF;
    }
    return h;
  }
}
```

**URL 来源**：所有 logo 用 [Wikipedia Commons](https://commons.wikimedia.org) 的 `upload.wikimedia.org` 直链，优先 PNG 格式（Flutter 的 CachedNetworkImage 对 SVG 不原生支持，避免额外引入 `flutter_svg`）。每个俱乐部的具体 URL 在实施阶段逐个查证后填入，不在本文档里写死（URL 查证是实施 task，不是设计决定）。

> **实施要点**：每个 URL 都要做一次 `HEAD` 请求或在模拟器里验证一次加载不 404。失败的换备选（比如换另一张代表图）。

### 6.2 球星照片 — 改 `demo_images.dart`

直接替换现有 `playerAvatarByName` 这 9 条 Unsplash URL 为球星 Wikipedia Commons 照片：

| Demo 球员 | 对应球星 | 来源 |
|---|---|---|
| 陈子睿 | Lionel Messi | Wikipedia Commons |
| 老王 | Cristiano Ronaldo | Wikipedia Commons |
| 徐铮 | Kylian Mbappé | Wikipedia Commons |
| 林帅 | Erling Haaland | Wikipedia Commons |
| 江北 | Vinícius Júnior | Wikipedia Commons |
| Kevin | Jude Bellingham | Wikipedia Commons |
| 张教练 | Pep Guardiola（教练） | Wikipedia Commons |
| 小赵 | Kevin De Bruyne | Wikipedia Commons |
| 阿泽 | Mohamed Salah | Wikipedia Commons |

文件头部的注释需要同步更新：说明"URL 来自 Wikipedia Commons，对应球星仅作视觉 demo 用途"。

### 6.3 兜底

- **TeamBadge** 现有兜底：url 加载失败 → 渲染字母 chip（现成）
- **NetworkAvatar** 现有兜底：url 加载失败 → 渲染字母 monogram（现成）
- **无网**：首次连网后 `CachedNetworkImage` 会缓存到本地，离线体验无损

### 6.4 版权与风险

- Wikipedia Commons 上大多是 CC BY-SA 或公共领域，用于**本地 demo 展示**可接受。
- **真正要发布时需核查每张图的 license，必要时改用自行持有授权的素材或打包到 `assets/`**（这个风险写进文档作为 follow-up）。
- Wikipedia 直链稳定性不如专业 CDN，偶尔会重定向或变更文件名；CachedNetworkImage 的 errorWidget 兜底能保证 UX 不崩。

## 七、文件改动清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `lib/data/demo_team_assets.dart` | 新增 | 豪门池 + 稳定哈希映射 |
| `lib/data/demo_images.dart` | 修改 | 替换 `playerAvatarByName` 9 条 URL + 更新注释 |
| `lib/features/events/event_detail_screen.dart` | 修改 | `_StandingsTable` 加 `_StandingsHero`；列表行 logo 32→44；`_ScorersPanel` 拆 Hero/Medal/List 三段；新增 `_GoldenBootHero`、`_MedalCard` 私有 widget |

**不改动**：`team_badge.dart`、`network_avatar.dart`、世界杯屏、球员 / 球队 sheet 内部布局。

## 八、测试

### 8.1 手动走查清单

- [ ] 积分榜加载状态 / 空态 / 错误态：hero 卡在空态下不出现（维持原空态文案）
- [ ] 积分榜 rows.length == 1：只渲染紧凑列表，无 hero
- [ ] 积分榜 rows.length >= 2：hero 卡 Top 2 居中对称，点击左右分别进对应 team sheet
- [ ] 积分榜列表行 logo 加载失败 → 显示字母 chip（拔网复现）
- [ ] 积分榜主题：深色 / 浅色模式下 hero 卡文字对比度、边框色都正常
- [ ] 射手榜 rows 数量从 0 → 4 渐次变化：对应渲染 空 / Hero / Hero+Silver / Hero+Silver+Bronze / Hero+Silver+Bronze+List
- [ ] 射手榜 Top 1 头像金边、Top 2 银边、Top 3 铜边渲染正常；URL 失败 → 字母 monogram 兜底
- [ ] 射手榜 Top 1 `row.matches == 0` 时不渲染场均（避免除零）
- [ ] 点击 hero / medal 卡 → `_showScorerSheet` 打开；sheet 内部布局未受影响
- [ ] iOS / Android 双端字体回退：hero 卡里的 `N(...)` 大号数字在中英混排下不错位
- [ ] 离线重启 app：已缓存的 logo / 头像仍能展示（CachedNetworkImage 生效）

### 8.2 非测试回归

- 运行 `flutter analyze` 无新增告警
- 运行 `flutter test`（如项目有 widget test 覆盖这两屏则必须过；若没有，不强行新加）

## 九、Follow-ups（不在本次范围）

- 真 logo / 头像打包到 `assets/` 作为离线首发资源（避免首次加载白屏）
- 世界杯屏的色块 flag 也升级为真实国旗图（需另做 license 核查）
- 积分榜 hero 卡用 `DemoClub.primaryArgb` 两队主色做背景渐变（本次保留字段但不渲染）
- 射手榜 Top 1 hero 卡的粒子 / 光效 / 进入动画

## 十、实施提醒（非 follow-up，实施时要做到）

- 当未来 teams / profiles 从 Supabase 拿到真实 `logo_url` / `avatar_url` 时，`demoClubFor()` 和 `playerAvatarByName` 必须仅对 URL 为空时兜底，不能覆盖真实数据。调用点写 `teamLogoUrl ?? DemoTeamAssets.forTeamName(name).logoUrl` 的优先级。本次 demo 数据侧 teams 没有 `logo_url` 所以实际上总是走 demo；但代码仍需按此优先级写好，避免将来上真实数据时回归。
