# 积分榜 & 射手榜视觉升级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在赛事详情页的积分榜 tab 顶部加一张 Top-2 "榜首之争" hero 卡、列表行队徽从 32→44；在射手榜 tab 顶部加金靴 hero 卡 + 银 / 铜堆叠卡，第 4 名起保留列表；同时把 demo 队伍对应的队徽换成真实豪门 logo，把 demo 球员对应的头像换成真实球星照片（名字不变）。

**Architecture:** 纯客户端改造，不动 schema。新增一个 `DemoTeamAssets` 数据文件承载稳定哈希的"队名→豪门"映射；更新 `demo_images.dart` 的 `playerAvatarByName` URL；在 `event_detail_screen.dart` 内新增三个私有 widget (`_StandingsHero` / `_GoldenBootHero` / `_MedalCard`) 并把 `_StandingsTable` 和 `_ScorersPanel.build` 的渲染拆段。底层的 `TeamBadge` / `NetworkAvatar` widget 不修改。

**Tech Stack:** Flutter 3.x, Dart 3.11.5, `flutter_riverpod`, `cached_network_image`, 项目自有 `AppTokens`(`context.tokens.*`) / `TeamBadge` / `NetworkAvatar` / `N` / `Label`, Wikipedia Commons 直链作为图片源。

**Spec:** `docs/superpowers/specs/2026-04-21-standings-scorers-visual-upgrade-design.md`

---

## File Structure

**新增文件:**

| 路径 | 职责 |
|---|---|
| `lib/data/demo_team_assets.dart` | `DemoClub` 数据类、12 支豪门池、`DemoTeamAssets.forTeamName()` 稳定哈希映射 |
| `test/data/demo_team_assets_test.dart` | 稳定哈希单元测试（幂等、覆盖均匀、不同输入不总是同一个 index） |

**修改文件:**

| 路径 | 变更 |
|---|---|
| `lib/l10n/app_zh.arb` | 新增 8 个 key（榜首之争相关 6 个 + 射手榜奖章相关 2 个） |
| `lib/l10n/app_en.arb` | 同上，英文翻译 |
| `lib/data/demo_images.dart` | 替换 `playerAvatarByName` 9 条 URL 为球星 Wikipedia Commons 照片；更新文件头注释 |
| `lib/features/events/event_detail_screen.dart` | `_StandingsTable`：头部插 `_StandingsHero`，列表行队徽 32→44 且用 `TeamBadge`；`_ScorersPanel.build`：data 分支拆成 hero/medal/list 三段；新增 3 个私有 widget |

**不修改:** `lib/widgets/team_badge.dart`、`lib/widgets/network_avatar.dart`、世界杯屏、`_ScorerCard` 和 `_ScorerSheet` 内部布局。

---

## Task 1: 新增 l10n 文案

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

这些 key 在后续 Task 5 / 6 / 7 里要用到。先加上，避免 UI 任务卡住。

- [ ] **Step 1: 给 `lib/l10n/app_zh.arb` 加 key**

在文件末尾的 `"match_not_found"` 后面（闭合 `}` 之前）追加 key。注意 `"match_not_found": "未找到该比赛"` 后面原本没有逗号，现在要补上逗号。

```json
  "match_not_found": "未找到该比赛",
  "event_standings_leaders_label": "榜首之争",
  "event_standings_leader_top": "榜首",
  "event_standings_leader_runner": "次席",
  "event_standings_points_diff": "积分差 {n}",
  "@event_standings_points_diff": { "placeholders": { "n": { "type": "int" } } },
  "event_scorers_golden_boot": "金靴得主",
  "event_scorers_per_match": "场均 {avg} 球",
  "@event_scorers_per_match": { "placeholders": { "avg": { "type": "String" } } }
```

- [ ] **Step 2: 给 `lib/l10n/app_en.arb` 加相同 key**

在同一位置追加：

```json
  "match_not_found": "Match not found",
  "event_standings_leaders_label": "League Leaders",
  "event_standings_leader_top": "1st",
  "event_standings_leader_runner": "2nd",
  "event_standings_points_diff": "{n, plural, =1{1 point apart} other{{n} points apart}}",
  "@event_standings_points_diff": { "placeholders": { "n": { "type": "int" } } },
  "event_scorers_golden_boot": "Golden Boot",
  "event_scorers_per_match": "{avg} / match",
  "@event_scorers_per_match": { "placeholders": { "avg": { "type": "String" } } }
```

注意 `"match_not_found"` 这一行之前是最后一条，后面要加逗号。

- [ ] **Step 3: 重新生成 l10n 代码**

Run: `flutter gen-l10n`
Expected: 成功（无输出或 "No untranslated messages"），`lib/l10n/generated/app_localizations.dart` 被刷新。

如果 `flutter gen-l10n` 报缺 key 翻译，对照两份 arb 检查是否漏了。

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze lib/l10n`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "i18n: add leaders hero and medal boot strings"
```

---

## Task 2: 新增 `DemoTeamAssets` 队徽映射 + 单元测试

**Files:**
- Create: `lib/data/demo_team_assets.dart`
- Create: `test/data/demo_team_assets_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/data/demo_team_assets_test.dart`:

```dart
// demo_team_assets_test.dart — 队名 → 豪门稳定映射测试
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/data/demo_team_assets.dart';

void main() {
  group('DemoTeamAssets.forTeamName', () {
    test('same name always maps to the same club', () {
      for (final name in const ['龙岗狼队', '坪山蓝鲨', 'FC 黑马', '']) {
        final a = DemoTeamAssets.forTeamName(name);
        final b = DemoTeamAssets.forTeamName(name);
        expect(a.realName, b.realName);
        expect(a.logoUrl, b.logoUrl);
      }
    });

    test('different names can map to different clubs', () {
      // 不一定每两个名字都映射到不同 club（池只有 12 个），
      // 但整个集合至少应覆盖 >=3 个 club，否则哈希有偏
      final names = const [
        '龙岗狼队', '坪山蓝鲨', 'FC 黑马', '华强北射手',
        '宝安蓝鲸', '罗湖猛虎', '南山豹', '福田雨燕',
        '大鹏海鹰', '布吉飞龙',
      ];
      final clubs = names
          .map((n) => DemoTeamAssets.forTeamName(n).realName)
          .toSet();
      expect(clubs.length, greaterThanOrEqualTo(3));
    });

    test('non-empty team name returns a non-empty logoUrl', () {
      final club = DemoTeamAssets.forTeamName('龙岗狼队');
      expect(club.logoUrl, isNotEmpty);
      expect(club.logoUrl, startsWith('https://upload.wikimedia.org/'));
    });

    test('empty string does not throw', () {
      expect(() => DemoTeamAssets.forTeamName(''), returnsNormally);
    });
  });
}
```

- [ ] **Step 2: Run the test — should fail with "file not found"**

Run: `flutter test test/data/demo_team_assets_test.dart`
Expected: Fails — `Error: Couldn't resolve the package 'kaiqiu_app' in 'package:kaiqiu_app/data/demo_team_assets.dart'` 或 import 解析失败。

- [ ] **Step 3: 查证 12 个豪门 logo URL（用 curl 实际验证）**

在本地运行下面的脚本（不要提交到仓库），验证每个 URL 返回 HTTP 200。如果某个失败，去 `https://commons.wikimedia.org` 或 `https://en.wikipedia.org` 找同队的替代图（注意选 png/jpg，**不要选 svg**，因为 `CachedNetworkImage` 不原生支持 SVG）。

```bash
for url in \
  "https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/240px-Real_Madrid_CF.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/240px-FC_Barcelona_%28crest%29.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/7/7a/Manchester_United_FC_crest.svg/240px-Manchester_United_FC_crest.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/240px-Manchester_City_FC_badge.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/240px-Liverpool_FC.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg/240px-FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/240px-Paris_Saint-Germain_F.C..svg.png" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Juventus_FC_2017_logo.svg/240px-Juventus_FC_2017_logo.svg.png" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Logo_of_AC_Milan.svg/240px-Logo_of_AC_Milan.svg.png" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/FC_Internazionale_Milano_2021.svg/240px-FC_Internazionale_Milano_2021.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/240px-Chelsea_FC.svg.png" \
  "https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/240px-Arsenal_FC.svg.png"; do
  code=$(curl -o /dev/null -s -w "%{http_code}" -I -L -A "Mozilla/5.0" "$url")
  echo "$code  $url"
done
```

Expected: 所有行 code 都是 `200`。任何非 200 的，用对应队的替代 logo 覆盖（Wikipedia 搜索该队的条目，拿 infobox 里的 logo 文件名，按 `upload.wikimedia.org/wikipedia/en/thumb/<hash>/<hash>/FILE.svg/240px-FILE.svg.png` 构造）。

**把最终验证通过的 12 条 URL 记下来**，Step 4 里要用。

- [ ] **Step 4: 写 `lib/data/demo_team_assets.dart`**

用上一步验证通过的 URL 填入下面的 `_pool`（文档里给的是起始 URL，若 Step 3 换了就相应改）。

```dart
// demo_team_assets.dart — demo 队名 → 真实豪门资源（logo/主色）稳定映射。
//
// 用途：积分榜 hero 卡 / 列表行的队徽展示。demo 的业余球队是虚构的
// （"龙岗狼队" 等），本映射仅为视觉增色；真实数据上线后应优先用
// teams.logo_url，仅在空时回退到本映射（调用点自己判断优先级）。
//
// URL 来源：Wikipedia Commons / English Wikipedia 的 upload.wikimedia.org
// 直链（PNG 光栅，避免 SVG 依赖）。如某条失效，换 Wikipedia 上该队
// 条目里 infobox 的 logo 文件名即可。
//
// 映射策略：按 teamName 的稳定哈希选池中的一支。同一个名字永远对到
// 同一支豪门，不会每次乱跳。

class DemoClub {
  /// 仅作调试和注释，不参与渲染
  final String realName;

  /// Wikipedia PNG 直链，CachedNetworkImage 可直接加载
  final String logoUrl;

  /// 主色（ARGB）。本次不参与渲染，保留为将来 hero 卡渐变等扩展字段
  final int primaryArgb;

  const DemoClub(this.realName, this.logoUrl, this.primaryArgb);
}

class DemoTeamAssets {
  DemoTeamAssets._();

  static const List<DemoClub> _pool = [
    DemoClub(
      'Real Madrid',
      'https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/240px-Real_Madrid_CF.svg.png',
      0xFFFEBE10,
    ),
    DemoClub(
      'FC Barcelona',
      'https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/240px-FC_Barcelona_%28crest%29.svg.png',
      0xFFA50044,
    ),
    DemoClub(
      'Manchester United',
      'https://upload.wikimedia.org/wikipedia/en/thumb/7/7a/Manchester_United_FC_crest.svg/240px-Manchester_United_FC_crest.svg.png',
      0xFFDA291C,
    ),
    DemoClub(
      'Manchester City',
      'https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/240px-Manchester_City_FC_badge.svg.png',
      0xFF6CABDD,
    ),
    DemoClub(
      'Liverpool',
      'https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/240px-Liverpool_FC.svg.png',
      0xFFC8102E,
    ),
    DemoClub(
      'Bayern Munich',
      'https://upload.wikimedia.org/wikipedia/en/thumb/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg/240px-FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg.png',
      0xFFDC052D,
    ),
    DemoClub(
      'Paris Saint-Germain',
      'https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/240px-Paris_Saint-Germain_F.C..svg.png',
      0xFF004170,
    ),
    DemoClub(
      'Juventus',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Juventus_FC_2017_logo.svg/240px-Juventus_FC_2017_logo.svg.png',
      0xFF000000,
    ),
    DemoClub(
      'AC Milan',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Logo_of_AC_Milan.svg/240px-Logo_of_AC_Milan.svg.png',
      0xFFFB090B,
    ),
    DemoClub(
      'Inter Milan',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/FC_Internazionale_Milano_2021.svg/240px-FC_Internazionale_Milano_2021.svg.png',
      0xFF0068A8,
    ),
    DemoClub(
      'Chelsea',
      'https://upload.wikimedia.org/wikipedia/en/thumb/c/cc/Chelsea_FC.svg/240px-Chelsea_FC.svg.png',
      0xFF034694,
    ),
    DemoClub(
      'Arsenal',
      'https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/240px-Arsenal_FC.svg.png',
      0xFFEF0107,
    ),
  ];

  /// 同一个 teamName 永远对到同一支豪门
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

- [ ] **Step 5: Run test — should pass**

Run: `flutter test test/data/demo_team_assets_test.dart`
Expected: `All tests passed!`（4 个 test 全绿）

- [ ] **Step 6: Run analyzer**

Run: `flutter analyze lib/data/demo_team_assets.dart test/data/demo_team_assets_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/data/demo_team_assets.dart test/data/demo_team_assets_test.dart
git commit -m "feat(data): add DemoTeamAssets for stable team-name to club mapping"
```

---

## Task 3: 替换球员头像 URL 为真实球星

**Files:**
- Modify: `lib/data/demo_images.dart:44-65`

- [ ] **Step 1: 查证 9 条球星头像 URL**

运行下面脚本验证（curl 跟上面一样格式）。如果某条返回非 200，用该球星的另一张 Wikipedia Commons 头像替代（搜索维基百科该球员条目的 infobox 图片）。

```bash
for url in \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Lionel_Messi_20180626.jpg/400px-Lionel_Messi_20180626.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Cristiano_Ronaldo_2018.jpg/400px-Cristiano_Ronaldo_2018.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Kylian_Mbapp%C3%A9_2018.jpg/400px-Kylian_Mbapp%C3%A9_2018.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/2023-09-12_Fussball%2C_M%C3%A4nner%2C_L%C3%A4nderspiel%2C_Deutschland-Frankreich_1DX_4186_by_Stepro.jpg/400px-2023-09-12_Fussball%2C_M%C3%A4nner%2C_L%C3%A4nderspiel%2C_Deutschland-Frankreich_1DX_4186_by_Stepro.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Vinicius_Junior_2018.jpg/400px-Vinicius_Junior_2018.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Jude_Bellingham_2023.jpg/400px-Jude_Bellingham_2023.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Pep_Guardiola.jpg/400px-Pep_Guardiola.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Kevin_De_Bruyne_2018.jpg/400px-Kevin_De_Bruyne_2018.jpg" \
  "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Mohamed_Salah_2018.jpg/400px-Mohamed_Salah_2018.jpg"; do
  code=$(curl -o /dev/null -s -w "%{http_code}" -I -L -A "Mozilla/5.0" "$url")
  echo "$code  $url"
done
```

Expected: 9 行全是 200。若某张不在，去 `commons.wikimedia.org` 搜对应人名，拿另一张 CC 图。

- [ ] **Step 2: 改 `lib/data/demo_images.dart` 的头部注释**

把 44 行开始的 `// ── 球员头像` 注释块替换为说明新来源（区分 venue/event 仍然 Unsplash，头像改 Wikipedia）：

```dart
  // ── 球员头像（profiles.avatar_url）─────────────────────────
  /// demo 名字 → 真实球星头像 URL（Wikipedia Commons）。与 seed.sql 里
  /// auth.users 插入的 9 位 demo 球员一致。
  ///
  /// 说明：球员名字保留（"陈子睿"/"老王"等），但头像借用真实球星的
  /// 公开照片，让 demo 射手榜 / 评分榜有可看性。名字与头像不匹配是已
  /// 知取舍，仅为 demo 展示用。真实球员注册后走 profiles.avatar_url。
  ///
  /// 版权：Wikipedia Commons 大多 CC BY-SA / 公共领域，demo 可用；
  /// 若要用于正式产品需单独核查 license。
```

- [ ] **Step 3: 替换 `playerAvatarByName` 9 条 URL**

把 46-65 行整块 map 替换成上一步查证通过的 URL（下面是起始版本，若 Step 1 换了某条就改对应的一行）：

```dart
  static const Map<String, String> playerAvatarByName = {
    '陈子睿': // Lionel Messi
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Lionel_Messi_20180626.jpg/400px-Lionel_Messi_20180626.jpg',
    '老王': // Cristiano Ronaldo
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Cristiano_Ronaldo_2018.jpg/400px-Cristiano_Ronaldo_2018.jpg',
    '徐铮': // Kylian Mbappé
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Kylian_Mbapp%C3%A9_2018.jpg/400px-Kylian_Mbapp%C3%A9_2018.jpg',
    '林帅': // Erling Haaland
        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/2023-09-12_Fussball%2C_M%C3%A4nner%2C_L%C3%A4nderspiel%2C_Deutschland-Frankreich_1DX_4186_by_Stepro.jpg/400px-2023-09-12_Fussball%2C_M%C3%A4nner%2C_L%C3%A4nderspiel%2C_Deutschland-Frankreich_1DX_4186_by_Stepro.jpg',
    '江北': // Vinícius Júnior
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Vinicius_Junior_2018.jpg/400px-Vinicius_Junior_2018.jpg',
    'Kevin': // Jude Bellingham
        'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Jude_Bellingham_2023.jpg/400px-Jude_Bellingham_2023.jpg',
    '张教练': // Pep Guardiola
        'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f5/Pep_Guardiola.jpg/400px-Pep_Guardiola.jpg',
    '小赵': // Kevin De Bruyne
        'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Kevin_De_Bruyne_2018.jpg/400px-Kevin_De_Bruyne_2018.jpg',
    '阿泽': // Mohamed Salah
        'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Mohamed_Salah_2018.jpg/400px-Mohamed_Salah_2018.jpg',
  };
```

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze lib/data/demo_images.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/data/demo_images.dart
git commit -m "feat(data): swap demo player avatars to real football stars"
```

---

## Task 4: 积分榜列表行队徽 32 → 44（先做简单胜利）

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart:955-985` (字段行内队徽块)
- Modify: `lib/features/events/event_detail_screen.dart:25-30` (imports)

本任务只改列表行队徽，不碰 hero 卡逻辑；保证一次编译即可见效果。

- [ ] **Step 1: 加 imports**

在 `lib/features/events/event_detail_screen.dart` 顶部 imports 里（约 25-30 行）补充：

```dart
import '../../data/demo_team_assets.dart';
import '../../widgets/team_badge.dart';
```

按字母序插到合适位置（`data/mock.dart` 之后、`widgets/avatar.dart` 之前；`widgets/team_badge.dart` 放在 `widgets/` 分组里按字母序）。

- [ ] **Step 2: 替换列表行队徽的裸 Container**

当前 `lib/features/events/event_detail_screen.dart:955-985` 的结构是：

```dart
                      SizedBox(
                        width: 24,
                        child: N('${s.rank}', ...),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: HSLColor.fromAHSL(
                                  1,
                                  (s.rank * 50).toDouble() % 360,
                                  0.35,
                                  0.3,
                                ).toColor(),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.team,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.tokens.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
```

把 `Container(width: 32, height: 32, decoration: ...)` 整块替换为：

```dart
                            TeamBadge(
                              name: s.team,
                              logoUrl: DemoTeamAssets.forTeamName(s.team).logoUrl,
                              size: 44,
                            ),
```

- [ ] **Step 3: 调整行垂直 padding**

同一 `Container` 外层 `padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)` 里，把 `vertical: 12` 改为 `vertical: 14`（logo 变大后给点呼吸）。

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: 手动走查**

Run: `flutter run -d <device>`（任选一个模拟器或设备；项目已在跑就热重载）

打开任一赛事详情页 → 切到 "积分榜" tab。预期：
- 行高略增
- 每行左侧出现真实豪门 logo（皇马/巴萨/曼联…按队名哈希映射，同一队始终同一 logo）
- logo 在深色和浅色模式下都清晰
- 断网时 → TeamBadge 走字母 chip 兜底（断网验证可选：`adb shell svc wifi disable`，也可以跳过）

若某支队的 logo URL 失效或加载很慢 → 确认走了字母 chip 兜底就行（不是 bug）。

- [ ] **Step 6: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(standings): enlarge row badge to 44 and use real club logos"
```

---

## Task 5: 加 `_StandingsHero` widget + 在 `_StandingsTable` 头部挂载

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart` （`_StandingsTable.build` 内加 hero；文件末尾新增 `_StandingsHero`）

- [ ] **Step 1: 在 `_StandingsTable.build` 里插入 hero**

找到 `_StandingsTable.build` 方法（`lib/features/events/event_detail_screen.dart:894` 起）。现在是：

```dart
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 24, child: Label(l.event_standings_rank)),
                // ... 表头其余
              ],
            ),
          ),
          for (final s in rows)
            Material(
              // ... 行
            ),
        ],
      ),
    );
  }
```

把 `child: Column(children: [` 内的第一个元素前面（即 `Padding` 表头前）插入：

```dart
          if (rows.length >= 2)
            _StandingsHero(top: rows[0], runner: rows[1], allMatches: matches),
```

- [ ] **Step 2: 在文件末尾新增 `_StandingsHero` widget**

在 `_StandingsTable` 之后（`_showTeamSheet` 之前，约 1025 行后插入新类，或者直接放文件末尾；建议紧跟 `_StandingsTable` 逻辑相关的位置）。

```dart
class _StandingsHero extends StatelessWidget {
  final StandingRow top;
  final StandingRow runner;
  final List<Match> allMatches;

  const _StandingsHero({
    required this.top,
    required this.runner,
    required this.allMatches,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final diff = top.pts - runner.pts;
    final accent = context.tokens.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: accent.withAlpha(0x66)),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Label(l.event_standings_leaders_label),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _StandingsHeroSide(
                  standing: top,
                  subLabel: l.event_standings_leader_top,
                  subLabelColor: accent,
                  allMatches: allMatches,
                ),
              ),
              SizedBox(
                width: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        N(
                          '${top.pts}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: accent,
                        ),
                        Text(
                          ' - ',
                          style: TextStyle(
                            color: context.tokens.inkDim,
                            fontSize: 18,
                          ),
                        ),
                        N(
                          '${runner.pts}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: context.tokens.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Label(l.event_standings_points_diff(diff)),
                  ],
                ),
              ),
              Expanded(
                child: _StandingsHeroSide(
                  standing: runner,
                  subLabel: l.event_standings_leader_runner,
                  subLabelColor: context.tokens.inkSub,
                  allMatches: allMatches,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandingsHeroSide extends StatelessWidget {
  final StandingRow standing;
  final String subLabel;
  final Color subLabelColor;
  final List<Match> allMatches;

  const _StandingsHeroSide({
    required this.standing,
    required this.subLabel,
    required this.subLabelColor,
    required this.allMatches,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.r2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _showTeamSheet(
          context,
          standing: standing,
          allMatches: allMatches,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamBadge(
                name: standing.team,
                logoUrl: DemoTeamAssets.forTeamName(standing.team).logoUrl,
                size: 72,
              ),
              const SizedBox(height: 6),
              Text(
                standing.team,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Label(subLabel, color: subLabelColor),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: 手动走查**

热重载赛事详情页 → 积分榜 tab。预期：
- 顶部出现 hero 卡，左右两队对称，中间大号比分 "42 - 38"（具体数字随 demo 数据）
- 两侧 TeamBadge 72×72 清晰
- 底部 "积分差 N" 小字
- 左右两侧各自可点：点左侧进 top 队 sheet，点右侧进 runner 队 sheet；点中间数字区不响应
- 深浅模式切换正常；边框带 accent 色淡化
- `rows.length == 1` 时 hero 不出现（可用只有一支队的赛事验证；无法造的话看代码 `if (rows.length >= 2)` 的分支）

- [ ] **Step 5: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(standings): add top-2 league leaders hero card"
```

---

## Task 6: 加 `_GoldenBootHero` widget

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart` （在 `_ScorerCard` 附近新增 widget；尚未接入 `_ScorersPanel`）

本任务只写 widget。接入在 Task 8。

- [ ] **Step 1: 新增 `_GoldenBootHero` widget**

在 `_ScorerCard` 类前面（`class _ScorerCard` 声明前，约 1383 行）插入：

```dart
class _GoldenBootHero extends ConsumerWidget {
  final ScorerRow row;
  final VoidCallback? onTap;

  const _GoldenBootHero({required this.row, this.onTap});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final radius = BorderRadius.circular(context.tokens.r3);
    final perMatch = row.matches > 0
        ? (row.goals / row.matches).toStringAsFixed(2)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0x14FFD700),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x66FFD700)),
              borderRadius: radius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _gold, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatar(
                    row.name,
                    url: avatarUrl,
                    size: 96,
                    square: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(
                        l.event_scorers_golden_boot,
                        color: context.tokens.accent,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (perMatch != null)
                        Label(l.event_scorers_per_match(perMatch))
                      else
                        Label(l.archive_teammates_matches(row.matches)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    N(
                      '${row.goals}',
                      size: 32,
                      weight: FontWeight.w800,
                      color: context.tokens.accent,
                    ),
                    Label(l.event_scorers_goals),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: `No issues found!`

（因为还没接入，界面还看不到，等 Task 8 一次性验证。）

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(scorers): add GoldenBootHero widget"
```

---

## Task 7: 加 `_MedalCard` widget（银 / 铜通用）

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart`

- [ ] **Step 1: 新增 `_MedalCard` widget**

在刚才 `_GoldenBootHero` 之后紧接着加：

```dart
enum _MedalKind { silver, bronze }

class _MedalCard extends ConsumerWidget {
  final ScorerRow row;
  final int rank;
  final _MedalKind kind;
  final VoidCallback? onTap;

  const _MedalCard({
    required this.row,
    required this.rank,
    required this.kind,
    this.onTap,
  });

  Color get _medalColor => kind == _MedalKind.silver
      ? const Color(0xFFC0C0C0)
      : const Color(0xFFCD7F32);

  Color get _medalBorder => kind == _MedalKind.silver
      ? const Color(0x66C0C0C0)
      : const Color(0x66CD7F32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final radius = BorderRadius.circular(context.tokens.r2);
    final perMatch = row.matches > 0
        ? (row.goals / row.matches).toStringAsFixed(2)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.tokens.elev2,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _medalBorder),
              borderRadius: radius,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _medalColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontFamily: context.tokens.fontMono,
                      fontFamilyFallback: context.tokens.monoFallbacks,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _medalColor, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatar(
                    row.name,
                    url: avatarUrl,
                    size: 72,
                    square: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (perMatch != null)
                        Label(l.event_scorers_per_match(perMatch))
                      else
                        Label(l.archive_teammates_matches(row.matches)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    N(
                      '${row.goals}',
                      size: 24,
                      weight: FontWeight.w700,
                      color: context.tokens.accent,
                    ),
                    Label(l.event_scorers_goals),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(scorers): add MedalCard widget for silver/bronze ranks"
```

---

## Task 8: 接入射手榜 — 拆分 hero / medal / list 三段渲染

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart` (`_ScorersPanel.build` 的 data 分支，约 1351-1377 行)

- [ ] **Step 1: 改 `_ScorersPanel.build` 的 data 分支**

当前 `_ScorersPanel.build` 的 data 分支（1351-1377 行）是：

```dart
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                context.l10n.event_scorers_goals,
                style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++)
                _ScorerCard(
                  rank: i + 1,
                  row: rows[i],
                  medal: _medal,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[i]),
                ),
            ],
          ),
        );
      },
```

改为：

```dart
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                context.l10n.event_scorers_goals,
                style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              _GoldenBootHero(
                row: rows[0],
                onTap: () =>
                    _showScorerSheet(context, eventId: eventId, row: rows[0]),
              ),
              if (rows.length >= 2)
                _MedalCard(
                  rank: 2,
                  row: rows[1],
                  kind: _MedalKind.silver,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[1]),
                ),
              if (rows.length >= 3)
                _MedalCard(
                  rank: 3,
                  row: rows[2],
                  kind: _MedalKind.bronze,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[2]),
                ),
              for (int i = 3; i < rows.length; i++)
                _ScorerCard(
                  rank: i + 1,
                  row: rows[i],
                  medal: _medal,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[i]),
                ),
            ],
          ),
        );
      },
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: 手动走查**

热重载赛事详情页 → "射手榜" tab。预期：
- Top 1 独立大卡：金色 tint 背景 + 金色边框，96×96 头像带金边，"金靴得主" label，右边大号进球数
- Top 2 卡：银色边框、72×72 头像带银边，标 "2" 奖章
- Top 3 卡：铜色边框、72×72 头像带铜边，标 "3" 奖章
- 第 4 名起：沿用原来的 `_ScorerCard`（头像 48，rank 数字不带奖章圆圈——因为 `_ScorerCard` 本来有 `rank<=3` 奖章分支，但现在 rank 都 `>=4`，走 N 数字分支）
- 点击 Hero / Medal / List 任何一张 → 正常打开 scorer sheet
- 头像 URL 失败（比如 Wikipedia 偶发跳错）→ 兜底字母头像正常显示
- `rows.length == 1/2/3` 的渐变渲染：只 hero / hero+silver / hero+silver+bronze（无多的卡）

- [ ] **Step 4: 运行所有单元测试确认没有回归**

Run: `flutter test`
Expected: 全绿，包括 Task 2 的 `demo_team_assets_test.dart`。

- [ ] **Step 5: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(scorers): top 3 use hero/medal layout, rest keep list"
```

---

## Task 9: 收尾 — 整体 analyze + build 验证

**Files:** 无新改动。只做最终检查。

- [ ] **Step 1: 全量 analyze**

Run: `flutter analyze`
Expected: `No issues found!`（若有，修掉再提交；常见问题：未使用的 import、未使用的变量。）

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全绿。

- [ ] **Step 3: Debug build 冒烟**

Run: `flutter build apk --debug`（或 `--target-platform android-arm64`，按项目既有习惯；iOS 用 `flutter build ios --debug --no-codesign`）
Expected: 构建成功，无编译错误。

- [ ] **Step 4: 手动端到端走查**

在真机或模拟器上跑最新 debug build，按下列清单逐项确认：

- [ ] 进入任一赛事详情页 → "积分榜" tab
- [ ] hero 卡显示 Top 1 vs Top 2，logo 清晰，"榜首之争" / "积分差 N" / "榜首" / "次席" 中文正常
- [ ] 点 hero 卡左右两侧 → 分别进入对应队 sheet
- [ ] 滚动列表 → 每行 44×44 logo，真豪门（皇马/曼联/…），行高舒适
- [ ] 切到 "射手榜" tab
- [ ] Top 1 金靴大卡、Top 2 银卡、Top 3 铜卡依次出现
- [ ] 第 4 名起回到紧凑列表（48×48 头像，无奖章）
- [ ] 点各层卡片 → 都能打开 scorer sheet
- [ ] 切主题（浅色 / 深色）→ 文字对比度、边框色正常
- [ ] 切语言（zh / en）→ 所有新 key 翻译正确显示

- [ ] **Step 5: 如果一切 OK，无需额外 commit；最后一次 push 前记得看一眼 `git status` 干净**

Run: `git status`
Expected: `working tree clean`。
