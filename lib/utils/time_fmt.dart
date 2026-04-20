// time_fmt.dart — 相对时间 helper，支持 i18n
import 'package:flutter/widgets.dart';

import '../l10n/l10n_extension.dart';

/// Localized relative time. Falls back to plain Chinese if no context.
String formatRelative(DateTime t, {DateTime? now, BuildContext? context}) {
  final cur = now ?? DateTime.now();
  final diff = cur.difference(t);
  if (context != null) {
    final l = context.l10n;
    if (diff.inMinutes < 1) return l.time_just_now;
    if (diff.inMinutes < 60) return l.time_minutes_ago(diff.inMinutes);
    if (diff.inHours < 24) return l.time_hours_ago(diff.inHours);
    if (diff.inDays == 1) return l.time_yesterday;
    if (diff.inDays < 7) return l.time_days_ago(diff.inDays);
    return '${t.month}-${t.day.toString().padLeft(2, '0')}';
  }
  // Fallback (no context): Chinese defaults.
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  if (diff.inDays == 1) return '昨天';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return '${t.month}-${t.day.toString().padLeft(2, '0')}';
}

String formatHm(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

String formatMd(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.month)}-${two(t.day)}';
}
