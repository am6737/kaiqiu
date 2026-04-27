import 'profile.dart';

class PlayerProfile {
  final Profile profile;
  final PlayerStats stats;
  final Map<String, int> attrs;
  final List<PlayerHonor> honors;

  const PlayerProfile({
    required this.profile,
    required this.stats,
    required this.attrs,
    required this.honors,
  });

  String get name => profile.name;
  String get handle => profile.handle ?? '@${profile.id.substring(0, 6)}';
  String get city => profile.city ?? '';
  String get district => profile.district ?? '';
  String? get phone => profile.phone;
  String get position => profile.position ?? '';
  int get height => profile.height ?? 0;
  String get foot => profile.foot ?? '';
  String? get avatarUrl => profile.avatarUrl;
  String? get bannerUrl => profile.bannerUrl;

  int get rating {
    if (attrs.isEmpty) return 0;
    final sum = attrs.values.fold(0, (a, b) => a + b);
    return (sum / attrs.length).round();
  }

  String get positionFull => _positionMap[position] ?? position;

  static final empty = PlayerProfile(
    profile: Profile(id: '', name: '新球友', createdAt: DateTime(2020)),
    stats: const PlayerStats(),
    attrs: const {},
    honors: const [],
  );

  static const _positionMap = {
    'GK': '守门员',
    'CB': '中后卫',
    'LB': '左后卫',
    'RB': '右后卫',
    'CDM': '后腰',
    'CM': '中场',
    'CAM': '前腰',
    'LW': '左边锋',
    'RW': '右边锋',
    'CF': '前锋',
    'ST': '前锋',
  };
}

class PlayerStats {
  final int matches;
  final int goals;
  final int assists;

  const PlayerStats({
    this.matches = 0,
    this.goals = 0,
    this.assists = 0,
  });

  factory PlayerStats.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const PlayerStats();
    return PlayerStats(
      matches: (m['matches'] as num?)?.toInt() ?? 0,
      goals: (m['goals'] as num?)?.toInt() ?? 0,
      assists: (m['assists'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerHonor {
  final String year;
  final String title;
  final String? meta;

  const PlayerHonor({
    required this.year,
    required this.title,
    this.meta,
  });

  factory PlayerHonor.fromMap(Map<String, dynamic> m) => PlayerHonor(
    year: m['year'] as String,
    title: m['title'] as String,
    meta: m['meta'] as String?,
  );
}
