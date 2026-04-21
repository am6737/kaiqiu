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
