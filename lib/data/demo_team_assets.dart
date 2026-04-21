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
// 版权：Wikipedia 光栅件 demo 可用；生产发布前必须核查各俱乐部徽章的
// 商标 / 版权政策（俱乐部队徽通常比 Commons 上的自然照片更严格）。
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
    // 替换：原 2017 版 logo 链接（en/1/1b/..._2017...）已失效 (404)，
    // 改用 commons 上的 2024 版 logo。
    DemoClub(
      'Bayern Munich',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/FC_Bayern_M%C3%BCnchen_logo_%282024%29.svg/240px-FC_Bayern_M%C3%BCnchen_logo_%282024%29.svg.png',
      0xFFDC052D,
    ),
    DemoClub(
      'Paris Saint-Germain',
      'https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/240px-Paris_Saint-Germain_F.C..svg.png',
      0xFF004170,
    ),
    // 替换：原 2017 版 logo (commons/1/15/Juventus_FC_2017_logo.svg) 已失效 (404)，
    // 改用 Wikipedia infobox 当前的 2020 黑色 J logo。
    DemoClub(
      'Juventus',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Juventus_FC_-_logo_black_%28Italy%2C_2020%29.svg/240px-Juventus_FC_-_logo_black_%28Italy%2C_2020%29.svg.png',
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
