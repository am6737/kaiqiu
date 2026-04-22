// share_helper.dart — 系统分享封装
import 'package:share_plus/share_plus.dart';

import '../models/event.dart';
import '../models/pickup.dart';
import '../models/player_profile.dart';

const _host = 'https://kaiqiu.app';

Future<void> sharePickup(Pickup p) async {
  final timeStr = _fmt(p.startAt);
  final text = [
    '⚽ 开球·约球邀请',
    '场地：${p.venue}',
    if (p.level != null) '等级：${p.level}',
    '时间：$timeStr',
    '费用：¥${p.feeYuan.toStringAsFixed(0)}',
    if ((p.need ?? 0) > 0) '还缺 ${p.need} 人',
    '',
    '$_host/pickup/${p.id}',
  ].join('\n');
  await Share.share(text, subject: '来一起约球');
}

Future<void> shareEvent(Event e) async {
  final subtitle = [
    if (e.sub?.isNotEmpty ?? false) e.sub!,
    if (e.city?.isNotEmpty ?? false) e.city!,
  ].join(' · ');
  final text = [
    '🏆 ${e.name}',
    if (subtitle.isNotEmpty) subtitle,
    if (e.prizeCents != null)
      '奖金：¥${(e.prizeCents! / 1000000).toStringAsFixed(1)}万',
    '',
    '$_host/event/${e.id}',
  ].join('\n');
  await Share.share(text, subject: '开球·赛事');
}

Future<void> shareProfile(PlayerProfile u) async {
  final text = [
    '👤 ${u.name} · ${u.positionFull}',
    '综合评分：${u.rating}',
    '场次：${u.stats.matches} · 进球：${u.stats.goals} · 助攻：${u.stats.assists}',
    '',
    '$_host/player/${u.handle}',
  ].join('\n');
  await Share.share(text, subject: '开球·球员档案');
}

Future<void> shareText(String text, {String? subject}) async {
  await Share.share(text, subject: subject);
}

String _fmt(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
