// demo_images.dart — demo 图片 URL 常量，所有 URL 与 supabase/seed/demo.sql 保持同步。
//
// 来源：Unsplash（手选稳定 photo-id）。URL 走统一 query string 规范化尺寸/质量，
// 避免拉原图浪费流量。如需替换直接改这里 + 对应 seed.sql。
//
// Fallback 策略：运行时 CachedNetworkImage 的 errorWidget 会兜到 PhotoHalftone /
// 字母 Avatar，所以单张 URL 失效不会崩。

class DemoImages {
  DemoImages._();

  static const _landscape =
      '?auto=format&fit=crop&w=1200&h=600&q=70';
  static const _square = '?auto=format&fit=crop&w=400&h=400&q=70';

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
  /// demo 名字 → 头像 URL。与 seed.sql 里 auth.users 插入的 9 位 demo 球员一致。
  static const Map<String, String> playerAvatarByName = {
    '陈子睿':
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d$_square',
    '老王':
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e$_square',
    '徐铮':
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2$_square',
    '林帅':
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6$_square',
    '江北':
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7$_square',
    'Kevin':
        'https://images.unsplash.com/photo-1552058544-f2b08422138a$_square',
    '张教练':
        'https://images.unsplash.com/photo-1531123897727-8f129e1688ce$_square',
    '小赵':
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce$_square',
    '阿泽':
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e$_square',
  };

  // ── 队徽 ────────────────────────────────────────────────
  // 不提供 URL：demo 球队是虚构的（"龙岗狼队" 等），强行套 Unsplash 随机
  // 场景照反而不像队徽。改由 widgets/team_badge.dart 的 TeamBadge 按名字
  // 哈希生成方形 chip（色 + 首字母），风格对齐世界杯 flag chip。
  // 真实球队注册后 teams.logo_url 才会被填，TeamBadge 优先走 URL。
}
