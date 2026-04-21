// network_cover.dart — 网络封面图，带 halftone 占位兜底。
//
// 用法：给事件卡片 / 场地头图等宽幅位置用。有 url 时拉 CachedNetworkImage，
// 没 url（或加载失败）时回落到 PhotoHalftone。
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'photo_halftone.dart';

class NetworkCover extends StatelessWidget {
  final String? url;
  final String fallbackLabel;
  final double height;
  final double hue;
  final HalftoneVariant variant;

  const NetworkCover({
    super.key,
    required this.url,
    required this.fallbackLabel,
    this.height = 160,
    this.hue = 140,
    this.variant = HalftoneVariant.dots,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return PhotoHalftone(
        label: fallbackLabel,
        height: height,
        hue: hue,
        variant: variant,
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 160),
        placeholder: (_, _) => PhotoHalftone(
          label: fallbackLabel,
          height: height,
          hue: hue,
          variant: variant,
        ),
        errorWidget: (_, _, _) => PhotoHalftone(
          label: fallbackLabel,
          height: height,
          hue: hue,
          variant: variant,
        ),
      ),
    );
  }
}
