import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

const _kPrefix = 'preset:';

bool isPresetAvatar(String? url) => url != null && url.startsWith(_kPrefix);

int? presetIndexOf(String? url) {
  if (url == null || !url.startsWith(_kPrefix)) return null;
  return int.tryParse(url.substring(_kPrefix.length));
}

String presetUrl(int index) => '$_kPrefix$index';

String? presetImageUrl(String? url) {
  final idx = presetIndexOf(url);
  if (idx == null || idx < 0 || idx >= kPresetImageUrls.length) return null;
  return kPresetImageUrls[idx];
}

// Memo 3D avatars from alohe/avatars (MIT license)
// https://github.com/alohe/avatars
const _cdn = 'https://cdn.jsdelivr.net/gh/alohe/avatars@main/png';

const kPresetImageUrls = [
  '$_cdn/memo_2.png',
  '$_cdn/memo_5.png',
  '$_cdn/memo_15.png',
  '$_cdn/memo_30.png',
  '$_cdn/memo_33.png',
  '$_cdn/memo_35.png',
  '$_cdn/memo_1.png',
  '$_cdn/memo_10.png',
  '$_cdn/memo_18.png',
  '$_cdn/memo_22.png',
  '$_cdn/memo_3.png',
  '$_cdn/memo_28.png',
];

class PresetAvatar extends StatelessWidget {
  final int index;
  final double size;

  const PresetAvatar(this.index, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final imgUrl = kPresetImageUrls[index % kPresetImageUrls.length];
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: imgUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => _FallbackIcon(size: size),
          errorWidget: (_, _, _) => _FallbackIcon(size: size),
          memCacheWidth: (size * 2).toInt(),
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final double size;
  const _FallbackIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: context.tokens.elev2,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.5,
        color: context.tokens.inkDim,
      ),
    );
  }
}
