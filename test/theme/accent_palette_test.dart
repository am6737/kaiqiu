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
}
