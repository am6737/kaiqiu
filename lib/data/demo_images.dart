// demo_images.dart — demo 图片 URL 常量，所有 URL 与 supabase/seed/demo.sql 保持同步。
//
// 来源：场地 / 赛事封面走 Unsplash（手选稳定 photo-id + query string 规范化尺寸
// 质量），球员头像走 Wikipedia Commons（直链固定尺寸）。如需替换直接改这里 +
// 对应 seed.sql。
//
// Fallback 策略：运行时 CachedNetworkImage 的 errorWidget 会兜到 PhotoHalftone /
// 字母 Avatar，所以单张 URL 失效不会崩。

class DemoImages {
  DemoImages._();

  static const _landscape =
      '?auto=format&fit=crop&w=1200&h=600&q=70';

  // ── 赛事海报（events.cover_url）─────────────────────────────
  /// 2026 龙岗村超 — 慕尼黑奥林匹克球场空场绿茵,World Cup hero 兜底用
  static const eventCoverLonggang =
      'https://images.unsplash.com/photo-1654462977797-a349656aadcf$_landscape';

  /// 通用赛事备选海报池（无 cover_url 时按 id 哈希挑选,确保每个赛事都有海报）。
  /// 全部是真实绿茵场俯拍/空场特写,跟 World Cup hero 风格保持一致。
  static const eventCoverPool = <String>[
    eventCoverLonggang, // 慕尼黑奥林匹克球场绿茵
    venueLonggang,
    venueDayun,
    venueBantian,
    venueHuanancheng,
    venueDapeng,
  ];

  /// 根据稳定的字符串 (event id) 从 [eventCoverPool] 里挑一张图。
  static String pickCoverFor(String stableKey) {
    if (stableKey.isEmpty) return eventCoverPool.first;
    final h = stableKey.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xFFFF);
    return eventCoverPool[h % eventCoverPool.length];
  }

  // ── 场地照片（pickups.venue_photo_url）──────────────────────
  // 全部换成真实绿茵场照片（俯拍/空场),事件海报池 eventCoverPool 复用这批。
  // venuePinghu 未进 pool,保留原图(有白线草皮特写,场地详情页仍合适)。
  static const venueLonggang =
      'https://images.unsplash.com/photo-1709495034740-f6e6c22f1d1f$_landscape';
  static const venueDayun =
      'https://images.unsplash.com/photo-1461175905877-4c544d68b675$_landscape';
  static const venuePinghu =
      'https://images.unsplash.com/photo-1579952363873-27f3bade9f55$_landscape';
  static const venueBantian =
      'https://images.unsplash.com/photo-1510526292299-20af3f62d453$_landscape';
  static const venueHuanancheng =
      'https://images.unsplash.com/photo-1520692764874-270b6fe97fb3$_landscape';
  static const venueDapeng =
      'https://images.unsplash.com/photo-1546717003-caee5f93a9db$_landscape';

  static const Map<String, String> venueByName = {
    '龙岗体育中心 3号场': venueLonggang,
    '大运公园足球场': venueDayun,
    '平湖体育公园': venuePinghu,
    '坂田足球场': venueBantian,
    '华南城五人制': venueHuanancheng,
    '大鹏海滨球场': venueDapeng,
  };

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
  static const Map<String, String> playerAvatarByName = {
    '陈子睿': // Lionel Messi
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Lionel_Messi_20180626.jpg/400px-Lionel_Messi_20180626.jpg',
    '老王': // Cristiano Ronaldo
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Cristiano_Ronaldo_2018.jpg/400px-Cristiano_Ronaldo_2018.jpg',
    '徐铮': // Kylian Mbappé
        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Picture_with_Mbapp%C3%A9_%28cropped_and_rotated%29.jpg/400px-Picture_with_Mbapp%C3%A9_%28cropped_and_rotated%29.jpg',
    '林帅': // Erling Haaland
        'https://upload.wikimedia.org/wikipedia/commons/thumb/7/71/Erling_Haaland_June_2025.jpg/400px-Erling_Haaland_June_2025.jpg',
    '江北': // Vinícius Júnior
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/2023_05_06_Final_de_la_Copa_del_Rey_-_52879242230_%28cropped%29.jpg/400px-2023_05_06_Final_de_la_Copa_del_Rey_-_52879242230_%28cropped%29.jpg',
    'Kevin': // Jude Bellingham
        'https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Jude_Bellingham_2020_%28cropped2%29.jpg/400px-Jude_Bellingham_2020_%28cropped2%29.jpg',
    '张教练': // Pep Guardiola
        'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b9/2023-10-04_Fu%C3%9Fball%2C_M%C3%A4nner%2C_UEFA_Champions_League%2C_RB_Leipzig_-_Manchester_City_FC_1DX_2797_%28cropped%29.jpg/400px-2023-10-04_Fu%C3%9Fball%2C_M%C3%A4nner%2C_UEFA_Champions_League%2C_RB_Leipzig_-_Manchester_City_FC_1DX_2797_%28cropped%29.jpg',
    '小赵': // Kevin De Bruyne
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Kevin_De_Bruyne_USMNT_v_Belgium_Mar_28_2026-64_%28cropped%29.jpg/400px-Kevin_De_Bruyne_USMNT_v_Belgium_Mar_28_2026-64_%28cropped%29.jpg',
    '阿泽': // Mohamed Salah
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Mohamed_Salah_2018.jpg/400px-Mohamed_Salah_2018.jpg',
  };

  // ── 队徽 ────────────────────────────────────────────────
  // 不提供 URL：demo 球队是虚构的（"龙岗狼队" 等），强行套 Unsplash 随机
  // 场景照反而不像队徽。改由 widgets/team_badge.dart 的 TeamBadge 按名字
  // 哈希生成方形 chip（色 + 首字母），风格对齐世界杯 flag chip。
  // 真实球队注册后 teams.logo_url 才会被填，TeamBadge 优先走 URL。
}
