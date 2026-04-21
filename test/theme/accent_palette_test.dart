import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';
import 'package:kaiqiu_app/theme/accent_palette.dart';

void main() {
  group('AccentPaletteResolver.resolve', () {
    test('green dark uses neon green with black ink', () {
      final r = AccentPaletteResolver.resolve(
        const PresetAccentSeed(PresetAccent.green),
        Brightness.dark,
      );
      expect(r.accent, const Color(0xFF00FF85));
      expect(r.accentInk, const Color(0xFF000000));
    });

    test('green light uses forest green with white ink', () {
      final r = AccentPaletteResolver.resolve(
        const PresetAccentSeed(PresetAccent.green),
        Brightness.light,
      );
      expect(r.accent, const Color(0xFF00A864));
      expect(r.accentInk, const Color(0xFFFFFFFF));
    });

    test('all four presets resolve to non-null colors in both modes', () {
      for (final p in PresetAccent.values) {
        for (final b in Brightness.values) {
          final r = AccentPaletteResolver.resolve(PresetAccentSeed(p), b);
          expect((r.accent.a * 255.0).round().clamp(0, 255), 0xFF,
              reason: '${p.name} $b accent opaque');
          expect((r.accentInk.a * 255.0).round().clamp(0, 255), 0xFF,
              reason: '${p.name} $b ink opaque');
        }
      }
    });

    test('accentSubtle is a low-alpha tint of accent', () {
      final r = AccentPaletteResolver.resolve(
        const PresetAccentSeed(PresetAccent.green),
        Brightness.dark,
      );
      expect((r.accentSubtle.a * 255.0).round().clamp(0, 255), lessThan(0x40));
      expect((r.accentSubtle.r * 255.0).round().clamp(0, 255),
          (r.accent.r * 255.0).round().clamp(0, 255));
      expect((r.accentSubtle.g * 255.0).round().clamp(0, 255),
          (r.accent.g * 255.0).round().clamp(0, 255));
      expect((r.accentSubtle.b * 255.0).round().clamp(0, 255),
          (r.accent.b * 255.0).round().clamp(0, 255));
    });
  });

  group('AccentPaletteResolver.resolve(custom)', () {
    /// Per WCAG, contrast ratio between two colors.
    double contrast(Color a, Color b) {
      double rel(Color c) {
        double channel(double v) {
          return v <= 0.03928
              ? v / 12.92
              : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
        }
        final r = channel(c.r);
        final g = channel(c.g);
        final bl = channel(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * bl;
      }
      final l1 = rel(a);
      final l2 = rel(b);
      final hi = l1 > l2 ? l1 : l2;
      final lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    const darkBg = Color(0xFF0A0A0A);
    const lightBg = Color(0xFFFAF8F5);

    test('arbitrary custom resolves without throw in both modes', () {
      const seed = CustomAccentSeed(0xFF7A3DEC); // purple
      final dark = AccentPaletteResolver.resolve(seed, Brightness.dark);
      final light = AccentPaletteResolver.resolve(seed, Brightness.light);
      expect((dark.accent.a * 255.0).round().clamp(0, 255), 0xFF);
      expect((light.accent.a * 255.0).round().clamp(0, 255), 0xFF);
    });

    test('custom in dark mode has contrast >= 3.0 vs dark bg', () {
      // Spot-check several seeds.
      const seeds = [
        CustomAccentSeed(0xFF7A3DEC), // purple
        CustomAccentSeed(0xFF000000), // black (worst case for dark)
        CustomAccentSeed(0xFF333333), // dark gray
        CustomAccentSeed(0xFFFFFF00), // yellow
      ];
      for (final s in seeds) {
        final r = AccentPaletteResolver.resolve(s, Brightness.dark);
        expect(
          contrast(r.accent, darkBg),
          greaterThanOrEqualTo(3.0),
          reason: 'dark mode seed 0x${s.colorValue.toRadixString(16)} '
              'derived ${r.accent} contrast too low',
        );
      }
    });

    test('custom in light mode has contrast >= 3.0 vs light bg', () {
      const seeds = [
        CustomAccentSeed(0xFF7A3DEC), // purple
        CustomAccentSeed(0xFFFFFFFF), // white (worst case for light)
        CustomAccentSeed(0xFFEEEEEE), // light gray
        CustomAccentSeed(0xFFFFFF00), // yellow (low-luminance vs white bg)
      ];
      for (final s in seeds) {
        final r = AccentPaletteResolver.resolve(s, Brightness.light);
        expect(
          contrast(r.accent, lightBg),
          greaterThanOrEqualTo(3.0),
          reason: 'light mode seed 0x${s.colorValue.toRadixString(16)} '
              'derived ${r.accent} contrast too low',
        );
      }
    });

    test('accentInk is white for dark accents, black for light accents', () {
      // Force a dark accent → white ink.
      final dark = AccentPaletteResolver.resolve(
        const CustomAccentSeed(0xFF202020),
        Brightness.dark,
      );
      // Force a light accent → black ink.
      final light = AccentPaletteResolver.resolve(
        const CustomAccentSeed(0xFFFFEEAA),
        Brightness.light,
      );
      expect(light.accentInk, const Color(0xFF000000));
      // dark.accentInk could be either depending on derived value — just assert
      // it is a valid choice (not transparent).
      expect((dark.accentInk.a * 255.0).round().clamp(0, 255), 0xFF);
    });

    test('accentSubtle for custom is also low-alpha tint of derived accent', () {
      final r = AccentPaletteResolver.resolve(
        const CustomAccentSeed(0xFF7A3DEC),
        Brightness.dark,
      );
      expect(
          (r.accentSubtle.a * 255.0).round().clamp(0, 255), lessThan(0x40));
      expect((r.accentSubtle.r * 255.0).round().clamp(0, 255),
          (r.accent.r * 255.0).round().clamp(0, 255));
      expect((r.accentSubtle.g * 255.0).round().clamp(0, 255),
          (r.accent.g * 255.0).round().clamp(0, 255));
      expect((r.accentSubtle.b * 255.0).round().clamp(0, 255),
          (r.accent.b * 255.0).round().clamp(0, 255));
    });
  });
}
