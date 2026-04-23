// random_name.dart — 随机昵称生成
import 'dart:math';

const _adjectives = [
  '闪电', '暴力', '飞天', '无敌', '黄金',
  '钢铁', '疾风', '烈焰', '影子', '极速',
  '神秘', '狂野', '不败', '超级', '传奇',
  '冰霜', '雷霆', '幻影', '旋风', '铁壁',
];

const _roles = [
  '前锋', '后卫', '门将', '中场', '边锋',
  '队长', '射手', '铁卫', '核弹头', '指挥官',
  '守护者', '突击手', '全能王', '大师', '新星',
  '猎手', '战神', '先锋', '王牌', '精灵',
];

final _rng = Random();

String generateRandomName() {
  final adj = _adjectives[_rng.nextInt(_adjectives.length)];
  final role = _roles[_rng.nextInt(_roles.length)];
  return '$adj$role';
}
