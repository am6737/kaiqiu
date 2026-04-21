// network_avatar.dart — Avatar that prefers a network URL, falls back to the
// monogram rendering in `avatar.dart`.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'avatar.dart';

class NetworkAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  const NetworkAvatar(this.name, {super.key, this.url, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return Avatar(name, size: size);
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: u,
          fit: BoxFit.cover,
          placeholder: (_, _) => Avatar(name, size: size),
          errorWidget: (_, _, _) => Avatar(name, size: size),
          fadeInDuration: const Duration(milliseconds: 120),
          // Avoid flashes between placeholder and real image on repeat builds.
          memCacheWidth: (size * 2).toInt(),
        ),
      ),
    );
  }

  /// Optional bordered variant to match the bordered `Avatar`.
  factory NetworkAvatar.bordered(
    String name, {
    Key? key,
    String? url,
    double size = 32,
  }) {
    return NetworkAvatar(name, key: key, url: url, size: size);
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
