import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'avatar.dart';
import 'preset_avatars.dart';

class NetworkAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  /// 方形（圆角矩形）代替圆形。用于球员剧照 / 评分榜 / 射手榜 / 球员详情
  /// sheet —— 参考世界杯 flag chip 的方形卡片风格。
  final bool square;

  const NetworkAvatar(
    this.name, {
    super.key,
    this.url,
    this.size = 32,
    this.square = false,
  });

  @override
  Widget build(BuildContext context) {
    var u = url;

    // Resolve preset: protocol to actual image URL
    final resolved = presetImageUrl(u);
    if (resolved != null) u = resolved;

    if (u == null || u.isEmpty) {
      if (!square) return Avatar(name, size: size);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 6),
        child: _SquareMonogram(name: name, size: size),
      );
    }
    final image = SizedBox(
      width: size,
      height: size,
      child: CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.cover,
        placeholder: (_, _) => Avatar(name, size: size),
        errorWidget: (_, _, _) => Avatar(name, size: size),
        fadeInDuration: const Duration(milliseconds: 120),
        memCacheWidth: (size * 2).toInt(),
      ),
    );
    return square
        ? ClipRRect(borderRadius: BorderRadius.circular(size / 6), child: image)
        : ClipOval(child: image);
  }

  /// Optional bordered variant to match the bordered `Avatar`.
  factory NetworkAvatar.bordered(
    String name, {
    Key? key,
    String? url,
    double size = 32,
    bool square = false,
  }) {
    return NetworkAvatar(
      name,
      key: key,
      url: url,
      size: size,
      square: square,
    );
  }
}

class _SquareMonogram extends StatelessWidget {
  final String name;
  final double size;
  const _SquareMonogram({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final ch = name.isEmpty ? '?' : String.fromCharCode(name.runes.first);
    final hue = (ch.codeUnitAt(0) * 37) % 360;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightness = isDark ? 0.28 : 0.72;
    final bg = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, lightness).toColor();
    return Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: Text(
        ch,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: context.tokens.ink,
        ),
      ),
    );
  }
}

/// Drop-in convenience wrapping an image url with a circular border like the
/// existing monogram Avatar has, so layouts don't shift.
class CircleNetworkImage extends StatelessWidget {
  final String url;
  final double size;
  final Color? borderColor;
  final String fallbackName;

  const CircleNetworkImage({
    super.key,
    required this.url,
    this.size = 32,
    this.borderColor,
    this.fallbackName = '',
  });

  @override
  Widget build(BuildContext context) {
    final c = borderColor ?? context.tokens.line;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Avatar(fallbackName, size: size),
      ),
    );
  }
}
