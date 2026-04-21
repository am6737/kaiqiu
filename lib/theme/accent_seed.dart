// accent_seed.dart — sealed model for the user's accent-color choice.
import 'package:flutter/painting.dart';

enum PresetAccent { green, orange, cyan, red }

sealed class AccentSeed {
  const AccentSeed();

  String serialize();

  static const AccentSeed defaultSeed = PresetAccentSeed(PresetAccent.green);

  /// Parses serialized form. Falls back to [defaultSeed] on any error.
  static AccentSeed parse(String? raw) {
    if (raw == null || raw.isEmpty) return defaultSeed;
    if (raw.startsWith('preset:')) {
      final name = raw.substring('preset:'.length);
      for (final p in PresetAccent.values) {
        if (p.name == name) return PresetAccentSeed(p);
      }
      return defaultSeed;
    }
    if (raw.startsWith('custom:')) {
      final hex = raw.substring('custom:'.length);
      try {
        final v = int.parse(hex);
        return CustomAccentSeed(v);
      } catch (_) {
        return defaultSeed;
      }
    }
    return defaultSeed;
  }
}

class PresetAccentSeed extends AccentSeed {
  final PresetAccent preset;
  const PresetAccentSeed(this.preset);

  @override
  String serialize() => 'preset:${preset.name}';

  @override
  bool operator ==(Object other) =>
      other is PresetAccentSeed && other.preset == preset;
  @override
  int get hashCode => preset.hashCode;
}

class CustomAccentSeed extends AccentSeed {
  /// ARGB int (0xAARRGGBB).
  final int colorValue;
  const CustomAccentSeed(this.colorValue);

  Color get color => Color(colorValue);

  @override
  String serialize() => 'custom:0x${colorValue.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  @override
  bool operator ==(Object other) =>
      other is CustomAccentSeed && other.colorValue == colorValue;
  @override
  int get hashCode => colorValue.hashCode;
}
