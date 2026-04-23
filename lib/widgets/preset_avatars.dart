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

const kPresetImageUrls = [
  // Adventurer — cartoon characters
  'https://api.dicebear.com/9.x/adventurer/png?seed=Felix&size=256',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Nala&size=256',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Luna&size=256',
  'https://api.dicebear.com/9.x/adventurer/png?seed=Milo&size=256',
  // Bottts — Web3 robot style
  'https://api.dicebear.com/9.x/bottts/png?seed=Rocket&size=256',
  'https://api.dicebear.com/9.x/bottts/png?seed=Nova&size=256',
  'https://api.dicebear.com/9.x/bottts/png?seed=Cyber&size=256',
  'https://api.dicebear.com/9.x/bottts/png?seed=Bolt&size=256',
  // Pixel-art — retro Web3 pixel style
  'https://api.dicebear.com/9.x/pixel-art/png?seed=Storm&size=256',
  'https://api.dicebear.com/9.x/pixel-art/png?seed=Shadow&size=256',
  'https://api.dicebear.com/9.x/pixel-art/png?seed=Flash&size=256',
  'https://api.dicebear.com/9.x/pixel-art/png?seed=Blaze&size=256',
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
