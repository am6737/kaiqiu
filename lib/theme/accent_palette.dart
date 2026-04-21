// accent_palette.dart — resolves an AccentSeed to (accent, accentInk, accentSubtle)
// per Brightness. Preset values are hand-tuned; custom values run the
// derivation algorithm in Task 3.
import 'package:flutter/material.dart';

import 'accent_seed.dart';

class ResolvedAccent {
  final Color accent;
  final Color accentInk;
  final Color accentSubtle; // ~12% alpha tint of accent

  const ResolvedAccent({
    required this.accent,
    required this.accentInk,
    required this.accentSubtle,
  });
}

class AccentPaletteResolver {
  AccentPaletteResolver._();

  // Hand-tuned preset values (spec §5.2).
  static const _presets = <PresetAccent, _PresetTuning>{
    PresetAccent.green: _PresetTuning(
      darkAccent: Color(0xFF00FF85),
      darkInk: Color(0xFF000000),
      lightAccent: Color(0xFF00A864),
      lightInk: Color(0xFFFFFFFF),
    ),
    PresetAccent.orange: _PresetTuning(
      darkAccent: Color(0xFFFF8A3D),
      darkInk: Color(0xFF000000),
      lightAccent: Color(0xFFE25A0A),
      lightInk: Color(0xFFFFFFFF),
    ),
    PresetAccent.cyan: _PresetTuning(
      darkAccent: Color(0xFF00E5FF),
      darkInk: Color(0xFF000000),
      lightAccent: Color(0xFF0090A8),
      lightInk: Color(0xFFFFFFFF),
    ),
    PresetAccent.red: _PresetTuning(
      darkAccent: Color(0xFFFF3D5A),
      darkInk: Color(0xFFFFFFFF),
      lightAccent: Color(0xFFD32647),
      lightInk: Color(0xFFFFFFFF),
    ),
  };

  static ResolvedAccent resolve(AccentSeed seed, Brightness brightness) {
    switch (seed) {
      case PresetAccentSeed(:final preset):
        final t = _presets[preset]!;
        final accent = brightness == Brightness.dark ? t.darkAccent : t.lightAccent;
        final ink = brightness == Brightness.dark ? t.darkInk : t.lightInk;
        return ResolvedAccent(
          accent: accent,
          accentInk: ink,
          accentSubtle: accent.withAlpha(0x1F),
        );
      case CustomAccentSeed():
        // Implemented in Task 3.
        throw UnimplementedError('custom seed handled in deriveCustom');
    }
  }
}

class _PresetTuning {
  final Color darkAccent, darkInk, lightAccent, lightInk;
  const _PresetTuning({
    required this.darkAccent,
    required this.darkInk,
    required this.lightAccent,
    required this.lightInk,
  });
}
