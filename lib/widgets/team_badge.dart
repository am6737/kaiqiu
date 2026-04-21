// team_badge.dart — 队徽方形 chip。参考世界杯的 flag chip 做法：
// 纯色方块 + 队名前 1-2 字，颜色由队名哈希派生，保证同一支队始终同色。
//
// 有 logo_url 时优先拉网络图（也按方形裁），没有就渲染 chip。demo 的 16
// 支队都走 chip（seed 里不给 logo_url，避免随机网图看起来像场景照）。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class TeamBadge extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double size;

  const TeamBadge({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 6);
    final u = logoUrl;
    if (u != null && u.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: u,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _chip(),
            placeholder: (_, _) => _chip(),
          ),
        ),
      );
    }
    return ClipRRect(borderRadius: radius, child: _chip());
  }

  Widget _chip() {
    final label = _initials(name);
    final hue = _hueFromName(name);
    final bg = HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor();
    final accent = HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg, accent],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _labelSize(label, size),
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: label.runes.length <= 2 ? 0 : -0.5,
          height: 1.05,
        ),
      ),
    );
  }

  static double _labelSize(String label, double boxSize) {
    final runes = label.runes.length;
    if (runes <= 1) return boxSize * 0.5;
    if (runes == 2) return boxSize * 0.38;
    return boxSize * 0.28;
  }

  /// 拿队名的可识别前缀作为 chip 文案：
  ///  - ASCII 前缀保留（"FC 黑马" → "FC"）
  ///  - 否则取前两个中文字（"龙岗狼队" → "龙岗"）
  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final match = RegExp(r'^[A-Za-z0-9]+').firstMatch(trimmed);
    if (match != null) return match.group(0)!.toUpperCase();
    final runes = trimmed.runes.toList();
    final take = runes.length >= 2 ? 2 : 1;
    return String.fromCharCodes(runes.take(take));
  }

  static double _hueFromName(String name) {
    var h = 0;
    for (final r in name.runes) {
      h = (h * 31 + r) & 0xFFFFFF;
    }
    return (h % 360).toDouble();
  }
}
