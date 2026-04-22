// accent_palette.dart — resolves an AccentSeed to (accent, accentInk, accentSubtle)
// per Brightness. Preset values are hand-tuned; custom values run the
// derivation algorithm in Task 3.
import 'dart:math' as math;

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
      darkAccent: Color(0xFF34D399),
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
      case CustomAccentSeed(:final color):
        return _deriveCustom(color, brightness);
    }
  }

  static ResolvedAccent _deriveCustom(Color base, Brightness brightness) {
    final hsl = HSLColor.fromColor(base);
    double l;
    double s;
    if (brightness == Brightness.dark) {
      l = hsl.lightness < 0.60 ? 0.60 : hsl.lightness;
      s = hsl.saturation < 0.70 ? 0.70 : hsl.saturation;
    } else {
      l = hsl.lightness > 0.45 ? 0.45 : hsl.lightness;
      s = hsl.saturation > 0.80 ? 0.80 : hsl.saturation;
    }

    final bgRef = brightness == Brightness.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFFAF8F5);

    Color derived = HSLColor.fromAHSL(1.0, hsl.hue, s, l).toColor();
    var iters = 0;
    while (_contrast(derived, bgRef) < 3.0 && iters < 8) {
      l += brightness == Brightness.dark ? 0.05 : -0.05;
      l = l.clamp(0.0, 1.0);
      derived = HSLColor.fromAHSL(1.0, hsl.hue, s, l).toColor();
      if (l == 0.0 || l == 1.0) break;
      iters++;
    }

    // Choose ink with better contrast against derived accent.
    final contrastBlack = _contrast(derived, const Color(0xFF000000));
    final contrastWhite = _contrast(derived, const Color(0xFFFFFFFF));
    final ink = contrastBlack >= contrastWhite
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    return ResolvedAccent(
      accent: derived,
      accentInk: ink,
      accentSubtle: derived.withAlpha(0x1F),
    );
  }

  static double _relativeLuminance(Color c) {
    double channel(double v) {
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  static double _contrast(Color a, Color b) {
    final l1 = _relativeLuminance(a);
    final l2 = _relativeLuminance(b);
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
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
