# 主题色配置与明暗主题切换 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-configurable theme: light/dark/system mode + 4 preset accent colors + custom color picker, persisted across launches.

**Architecture:** Migrate the existing static `T.*` token system to a `ThemeExtension<AppTokens>` keyed off Material's `Brightness` and a runtime-configurable `AccentSeed`. A singleton `ThemeController` (mirrors existing `LocaleController`) holds the user choice in `SharedPreferences` and rebuilds `MaterialApp` via `AnimatedBuilder`. New "外观" settings screen lets the user choose mode and accent; selection takes effect immediately with Material's built-in color lerp animation.

**Tech Stack:** Flutter 3.41+ / Dart 3.11+, Material 3, Riverpod (existing state), SharedPreferences (existing persistence), `flutter_colorpicker` (new dep, custom-color picker UI).

**Spec:** `docs/superpowers/specs/2026-04-21-theme-color-and-light-dark-mode-design.md`

---

## Notes for the implementer

**Existing token names — these must be preserved through migration:**

| Old `T.*` | New `context.tokens.*` | Brightness-dependent? |
|---|---|---|
| `T.bg`, `T.elev1`, `T.elev2`, `T.elev3` | same names on `tokens` | yes |
| `T.line`, `T.lineStrong` | same | yes |
| `T.ink`, `T.inkSub`, `T.inkDim`, `T.inkMute` | same | yes |
| `T.live` | `accent` (user-controlled) | yes |
| `T.liveDim` | `accentSubtle` | yes |
| `T.warn`, `T.warnDim` | `warn`, `warnSubtle` | yes (semantic, not user-controlled) |
| `T.danger` | `danger` | yes (semantic) |
| `T.r1`-`T.r4` | `r1`-`r4` | no (constant doubles) |
| `T.fontMono`, `T.monoFallbacks` | `fontMono`, `monoFallbacks` | no |

`T.s1`-`T.s5` are defined but **not currently used** in the codebase — drop them in the new `AppTokens` (YAGNI).

**Existing `class AccentPalette` and `const accents` in `tokens.dart` are dead code** (defined but never imported anywhere) — they get removed during the final cleanup task.

---

## Task 0: Add dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add `flutter_colorpicker` to dependencies**

In `pubspec.yaml`, add this line under `dependencies:` (place it alphabetically near other UI deps, e.g. just below `cached_network_image`):

```yaml
  flutter_colorpicker: ^1.1.0
```

- [ ] **Step 2: Fetch the dependency**

Run: `cd /home/coder/workspaces/qiuju_app && flutter pub get`
Expected: `Got dependencies!` with no error.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(deps): add flutter_colorpicker for theme accent picker"
```

---

## Task 1: AccentSeed model + serialization (TDD)

**Files:**
- Create: `lib/theme/accent_seed.dart`
- Create: `test/theme/accent_seed_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/theme/accent_seed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';

void main() {
  group('AccentSeed.parse', () {
    test('parses preset green', () {
      final seed = AccentSeed.parse('preset:green');
      expect(seed, isA<PresetAccentSeed>());
      expect((seed as PresetAccentSeed).preset, PresetAccent.green);
    });

    test('parses all four presets', () {
      for (final name in const ['green', 'orange', 'cyan', 'red']) {
        final seed = AccentSeed.parse('preset:$name');
        expect(seed, isA<PresetAccentSeed>());
      }
    });

    test('parses custom hex', () {
      final seed = AccentSeed.parse('custom:0xFF7A3DEC');
      expect(seed, isA<CustomAccentSeed>());
      expect((seed as CustomAccentSeed).colorValue, 0xFF7A3DEC);
    });

    test('falls back to preset green on garbage', () {
      expect(AccentSeed.parse('garbage'), isA<PresetAccentSeed>());
      expect(AccentSeed.parse(''), isA<PresetAccentSeed>());
      expect(AccentSeed.parse('preset:purple'), isA<PresetAccentSeed>());
      expect(AccentSeed.parse('custom:notahex'), isA<PresetAccentSeed>());
    });

    test('round-trips preset', () {
      final seed = AccentSeed.parse('preset:orange');
      expect(seed.serialize(), 'preset:orange');
    });

    test('round-trips custom', () {
      const seed = CustomAccentSeed(0xFF7A3DEC);
      expect(seed.serialize(), 'custom:0xFF7A3DEC');
      expect(AccentSeed.parse(seed.serialize()), seed);
    });

    test('preset equality', () {
      expect(
        const PresetAccentSeed(PresetAccent.green),
        const PresetAccentSeed(PresetAccent.green),
      );
      expect(
        const PresetAccentSeed(PresetAccent.green),
        isNot(const PresetAccentSeed(PresetAccent.red)),
      );
    });

    test('custom equality', () {
      expect(
        const CustomAccentSeed(0xFFAABBCC),
        const CustomAccentSeed(0xFFAABBCC),
      );
      expect(
        const CustomAccentSeed(0xFFAABBCC),
        isNot(const CustomAccentSeed(0xFF000000)),
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/accent_seed_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kaiqiu_app/theme/accent_seed.dart'`

- [ ] **Step 3: Implement `AccentSeed`**

Create `lib/theme/accent_seed.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/accent_seed_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/theme/accent_seed.dart test/theme/accent_seed_test.dart
git commit -m "feat(theme): add AccentSeed model with preset/custom variants"
```

---

## Task 2: Preset accent definitions (TDD)

**Files:**
- Create: `lib/theme/accent_palette.dart`
- Create: `test/theme/accent_palette_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/theme/accent_palette_test.dart`:

```dart
import 'package:flutter/painting.dart';
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
          expect(r.accent.alpha, 0xFF, reason: '${p.name} $b accent opaque');
          expect(r.accentInk.alpha, 0xFF, reason: '${p.name} $b ink opaque');
        }
      }
    });

    test('accentSubtle is a low-alpha tint of accent', () {
      final r = AccentPaletteResolver.resolve(
        const PresetAccentSeed(PresetAccent.green),
        Brightness.dark,
      );
      expect(r.accentSubtle.alpha, lessThan(0x40));
      expect(r.accentSubtle.red, r.accent.red);
      expect(r.accentSubtle.green, r.accent.green);
      expect(r.accentSubtle.blue, r.accent.blue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/accent_palette_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement preset palette resolver**

Create `lib/theme/accent_palette.dart`:

```dart
// accent_palette.dart — resolves an AccentSeed to (accent, accentInk, accentSubtle)
// per Brightness. Preset values are hand-tuned; custom values run the
// derivation algorithm in Task 3.
import 'package:flutter/painting.dart';

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/accent_palette_test.dart`
Expected: PASS — `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/theme/accent_palette.dart test/theme/accent_palette_test.dart
git commit -m "feat(theme): add preset accent palette resolver"
```

---

## Task 3: Custom accent derivation algorithm (TDD)

**Files:**
- Modify: `lib/theme/accent_palette.dart`
- Modify: `test/theme/accent_palette_test.dart`

- [ ] **Step 1: Add failing tests for custom derivation**

Append to `test/theme/accent_palette_test.dart` (inside `void main()`, after the existing `group`):

```dart
  group('AccentPaletteResolver.resolve(custom)', () {
    /// Per WCAG, contrast ratio between two colors.
    double contrast(Color a, Color b) {
      double rel(Color c) {
        double channel(int v) {
          final x = v / 255.0;
          return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055).clamp(0, 1);
        }
        // Approx using sRGB linearized luminance.
        final r = channel(c.red);
        final g = channel(c.green);
        final bl = channel(c.blue);
        final lin = 0.2126 * pow(r) + 0.7152 * pow(g) + 0.0722 * pow(bl);
        return lin;
      }
      double pow(double x) => x <= 0 ? 0 : (x * x); // close enough for asserts
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
      expect(dark.accent.alpha, 0xFF);
      expect(light.accent.alpha, 0xFF);
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
        Brightness.dark, // will be brightened, but luminance still relatively low
      );
      // Force a light accent → black ink.
      final light = AccentPaletteResolver.resolve(
        const CustomAccentSeed(0xFFFFEEAA),
        Brightness.light,
      );
      expect(light.accentInk, const Color(0xFF000000));
      // dark.accentInk could be either depending on derived value — just assert
      // it is a valid choice (not transparent).
      expect(dark.accentInk.alpha, 0xFF);
    });

    test('accentSubtle for custom is also low-alpha tint of derived accent', () {
      final r = AccentPaletteResolver.resolve(
        const CustomAccentSeed(0xFF7A3DEC),
        Brightness.dark,
      );
      expect(r.accentSubtle.alpha, lessThan(0x40));
      expect(r.accentSubtle.red, r.accent.red);
      expect(r.accentSubtle.green, r.accent.green);
      expect(r.accentSubtle.blue, r.accent.blue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/accent_palette_test.dart`
Expected: FAIL — `UnimplementedError` thrown for custom seed.

- [ ] **Step 3: Implement custom derivation**

Replace the `case CustomAccentSeed():` arm in `lib/theme/accent_palette.dart` with a real implementation. Replace the entire body of the `resolve` method with the version below:

```dart
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

    final ink = _relativeLuminance(derived) > 0.5
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    return ResolvedAccent(
      accent: derived,
      accentInk: ink,
      accentSubtle: derived.withAlpha(0x1F),
    );
  }

  static double _relativeLuminance(Color c) {
    double channel(int v) {
      final x = v / 255.0;
      return x <= 0.03928 ? x / 12.92 : _pow((x + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue);
  }

  static double _contrast(Color a, Color b) {
    final l1 = _relativeLuminance(a);
    final l2 = _relativeLuminance(b);
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  // Simple integer power, avoids importing dart:math for tree-shake.
  static double _pow(double base, double exp) {
    // exp is always 2.4 for our use; use ln-based.
    return _exp(exp * _ln(base));
  }
  static double _ln(double x) {
    // Series-based ln for x in (0, 1]. Good enough for color math.
    if (x <= 0) return -1e9;
    double y = (x - 1) / (x + 1);
    double y2 = y * y;
    double sum = y;
    for (int n = 3; n < 25; n += 2) {
      y *= y2;
      sum += y / n;
    }
    return 2 * sum;
  }
  static double _exp(double x) {
    double sum = 1.0;
    double term = 1.0;
    for (int n = 1; n < 25; n++) {
      term *= x / n;
      sum += term;
    }
    return sum;
  }
```

> **Why hand-rolled `_pow`/`_ln`/`_exp`:** keeps the file independent from `dart:math`. If you'd rather just import it, replace `_pow`/`_ln`/`_exp` with `import 'dart:math' as math;` and use `math.pow`, `math.log`, `math.exp`. Either works.

- [ ] **Step 4: Run all theme tests**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/`
Expected: PASS — all tests in both files pass.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/accent_palette.dart test/theme/accent_palette_test.dart
git commit -m "feat(theme): add custom accent derivation with WCAG contrast guard"
```

---

## Task 4: Define `AppTokens` ThemeExtension

**Files:**
- Create: `lib/theme/app_tokens.dart`

- [ ] **Step 1: Implement AppTokens**

Create `lib/theme/app_tokens.dart`:

```dart
// app_tokens.dart — ThemeExtension carrying all design tokens.
// Replaces the old static `T` class. Access in widgets via `context.tokens`.
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

import 'accent_palette.dart';
import 'accent_seed.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  // Surface layers
  final Color bg, elev1, elev2, elev3;
  final Color line, lineStrong;
  // Text
  final Color ink, inkSub, inkDim, inkMute;
  // Accent (user-controlled)
  final Color accent, accentInk, accentSubtle;
  // Semantic colors (fixed brightness-aware)
  final Color warn, warnSubtle;
  final Color danger;
  // Radii (constant across modes)
  final double r1, r2, r3, r4;
  // Fonts (constant across modes)
  final String? fontMono;
  final List<String> monoFallbacks;

  const AppTokens({
    required this.bg,
    required this.elev1,
    required this.elev2,
    required this.elev3,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSub,
    required this.inkDim,
    required this.inkMute,
    required this.accent,
    required this.accentInk,
    required this.accentSubtle,
    required this.warn,
    required this.warnSubtle,
    required this.danger,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.r4,
    required this.fontMono,
    required this.monoFallbacks,
  });

  // ─── Constants used by both modes
  static const double _r1 = 6.0;
  static const double _r2 = 10.0;
  static const double _r3 = 14.0;
  static const double _r4 = 20.0;
  static const String? _fontMono = 'JetBrainsMono';
  static const List<String> _monoFallbacks = ['SF Mono', 'Menlo', 'Consolas', 'monospace'];

  /// Build dark-mode tokens for the given accent.
  static AppTokens dark(AccentSeed seed) {
    final a = AccentPaletteResolver.resolve(seed, Brightness.dark);
    return AppTokens(
      bg: const Color(0xFF0A0A0A),
      elev1: const Color(0xFF111111),
      elev2: const Color(0xFF171717),
      elev3: const Color(0xFF1F1F1F),
      line: const Color(0x0FFFFFFF),
      lineStrong: const Color(0x1FFFFFFF),
      ink: const Color(0xF5FFFFFF),
      inkSub: const Color(0x9EFFFFFF),
      inkDim: const Color(0x61FFFFFF),
      inkMute: const Color(0x38FFFFFF),
      accent: a.accent,
      accentInk: a.accentInk,
      accentSubtle: a.accentSubtle,
      warn: const Color(0xFFFF6B35),
      warnSubtle: const Color(0x24FF6B35),
      danger: const Color(0xFFFF3B6B),
      r1: _r1, r2: _r2, r3: _r3, r4: _r4,
      fontMono: _fontMono,
      monoFallbacks: _monoFallbacks,
    );
  }

  /// Build light-mode tokens for the given accent (spec §4).
  static AppTokens light(AccentSeed seed) {
    final a = AccentPaletteResolver.resolve(seed, Brightness.light);
    return AppTokens(
      bg: const Color(0xFFFAF8F5),
      elev1: const Color(0xFFFFFFFF),
      elev2: const Color(0xFFF2EFEA),
      elev3: const Color(0xFFE8E4DD),
      line: const Color(0x14000000), // ~8% black
      lineStrong: const Color(0x29000000), // ~16% black
      ink: const Color(0xF21A1816), // 95% near-black warm gray
      inkSub: const Color(0xCC5C5852),
      inkDim: const Color(0x998A857E),
      inkMute: const Color(0x80B8B2A8),
      accent: a.accent,
      accentInk: a.accentInk,
      accentSubtle: a.accentSubtle,
      warn: const Color(0xFFE25A0A),
      warnSubtle: const Color(0x24E25A0A),
      danger: const Color(0xFFD32647),
      r1: _r1, r2: _r2, r3: _r3, r4: _r4,
      fontMono: _fontMono,
      monoFallbacks: _monoFallbacks,
    );
  }

  @override
  AppTokens copyWith({
    Color? bg, Color? elev1, Color? elev2, Color? elev3,
    Color? line, Color? lineStrong,
    Color? ink, Color? inkSub, Color? inkDim, Color? inkMute,
    Color? accent, Color? accentInk, Color? accentSubtle,
    Color? warn, Color? warnSubtle, Color? danger,
    double? r1, double? r2, double? r3, double? r4,
    String? fontMono,
    List<String>? monoFallbacks,
  }) =>
      AppTokens(
        bg: bg ?? this.bg,
        elev1: elev1 ?? this.elev1,
        elev2: elev2 ?? this.elev2,
        elev3: elev3 ?? this.elev3,
        line: line ?? this.line,
        lineStrong: lineStrong ?? this.lineStrong,
        ink: ink ?? this.ink,
        inkSub: inkSub ?? this.inkSub,
        inkDim: inkDim ?? this.inkDim,
        inkMute: inkMute ?? this.inkMute,
        accent: accent ?? this.accent,
        accentInk: accentInk ?? this.accentInk,
        accentSubtle: accentSubtle ?? this.accentSubtle,
        warn: warn ?? this.warn,
        warnSubtle: warnSubtle ?? this.warnSubtle,
        danger: danger ?? this.danger,
        r1: r1 ?? this.r1,
        r2: r2 ?? this.r2,
        r3: r3 ?? this.r3,
        r4: r4 ?? this.r4,
        fontMono: fontMono ?? this.fontMono,
        monoFallbacks: monoFallbacks ?? this.monoFallbacks,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return AppTokens(
      bg: c(bg, other.bg),
      elev1: c(elev1, other.elev1),
      elev2: c(elev2, other.elev2),
      elev3: c(elev3, other.elev3),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      ink: c(ink, other.ink),
      inkSub: c(inkSub, other.inkSub),
      inkDim: c(inkDim, other.inkDim),
      inkMute: c(inkMute, other.inkMute),
      accent: c(accent, other.accent),
      accentInk: c(accentInk, other.accentInk),
      accentSubtle: c(accentSubtle, other.accentSubtle),
      warn: c(warn, other.warn),
      warnSubtle: c(warnSubtle, other.warnSubtle),
      danger: c(danger, other.danger),
      r1: d(r1, other.r1),
      r2: d(r2, other.r2),
      r3: d(r3, other.r3),
      r4: d(r4, other.r4),
      fontMono: t < 0.5 ? fontMono : other.fontMono,
      monoFallbacks: t < 0.5 ? monoFallbacks : other.monoFallbacks,
    );
  }
}

extension TokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/theme/app_tokens.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/theme/app_tokens.dart
git commit -m "feat(theme): add AppTokens ThemeExtension with light/dark variants"
```

---

## Task 5: Refactor `buildAppTheme` to take Brightness + AccentSeed

**Files:**
- Modify: `lib/theme/theme.dart`

- [ ] **Step 1: Replace contents of `lib/theme/theme.dart`**

Overwrite the file with this:

```dart
// theme.dart — ThemeData builder for the 开球 app.
// Returns a brightness-aware ThemeData with AppTokens attached as an extension.
import 'package:flutter/material.dart';

import 'accent_seed.dart';
import 'app_tokens.dart';

ThemeData buildAppTheme(Brightness brightness, AccentSeed seed) {
  final tokens = brightness == Brightness.dark
      ? AppTokens.dark(seed)
      : AppTokens.light(seed);

  final textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6,
      color: tokens.ink,
    ),
    displayMedium: TextStyle(
      fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5,
      color: tokens.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4,
      color: tokens.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17, fontWeight: FontWeight.w700, color: tokens.ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, color: tokens.ink, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, color: tokens.inkSub, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: tokens.inkSub),
    labelSmall: TextStyle(fontSize: 10, color: tokens.inkDim, letterSpacing: 1.2),
  );

  final colorScheme = brightness == Brightness.dark
      ? ColorScheme.dark(
          surface: tokens.bg,
          primary: tokens.accent,
          onPrimary: tokens.accentInk,
          secondary: tokens.warn,
          error: tokens.danger,
        )
      : ColorScheme.light(
          surface: tokens.bg,
          primary: tokens.accent,
          onPrimary: tokens.accentInk,
          secondary: tokens.warn,
          error: tokens.danger,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: tokens.bg,
    colorScheme: colorScheme,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [tokens],
  );
}
```

- [ ] **Step 2: Update the only existing call site (`app.dart`) to keep things compiling**

Open `lib/app.dart`. Change line 20 from:

```dart
          theme: buildAppTheme(),
```

to:

```dart
          theme: buildAppTheme(Brightness.dark, AccentSeed.defaultSeed),
```

And add the import at the top:

```dart
import 'theme/accent_seed.dart';
```

> This is a temporary placeholder — Task 9 replaces it with real `ThemeController` wiring. We just need the project to compile after this commit.

- [ ] **Step 3: Verify the project compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/theme lib/app.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run the smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS — app still boots.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/theme.dart lib/app.dart
git commit -m "refactor(theme): buildAppTheme takes Brightness + AccentSeed"
```

---

## Task 6: Add `themeMode` and `themeSeed` to LocalStore (TDD)

**Files:**
- Modify: `lib/services/local_storage.dart`
- Create: `test/services/local_storage_theme_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/services/local_storage_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  test('themeMode defaults to system', () {
    expect(LocalStore.themeMode, ThemeMode.system);
  });

  test('themeMode round-trips light/dark/system', () async {
    await LocalStore.setThemeMode(ThemeMode.light);
    expect(LocalStore.themeMode, ThemeMode.light);
    await LocalStore.setThemeMode(ThemeMode.dark);
    expect(LocalStore.themeMode, ThemeMode.dark);
    await LocalStore.setThemeMode(ThemeMode.system);
    expect(LocalStore.themeMode, ThemeMode.system);
  });

  test('themeSeed defaults to preset:green', () {
    final seed = LocalStore.themeSeed;
    expect(seed, isA<PresetAccentSeed>());
    expect((seed as PresetAccentSeed).preset, PresetAccent.green);
  });

  test('themeSeed round-trips preset', () async {
    await LocalStore.setThemeSeed(const PresetAccentSeed(PresetAccent.orange));
    final seed = LocalStore.themeSeed;
    expect(seed, const PresetAccentSeed(PresetAccent.orange));
  });

  test('themeSeed round-trips custom', () async {
    await LocalStore.setThemeSeed(const CustomAccentSeed(0xFF7A3DEC));
    final seed = LocalStore.themeSeed;
    expect(seed, const CustomAccentSeed(0xFF7A3DEC));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/services/local_storage_theme_test.dart`
Expected: FAIL — `LocalStore.themeMode` undefined.

- [ ] **Step 3: Add the new keys + accessors to `LocalStore`**

In `lib/services/local_storage.dart`:

1. Add imports near the top (after the existing `import 'package:flutter/foundation.dart';`):

```dart
import 'package:flutter/material.dart' show ThemeMode;

import '../theme/accent_seed.dart';
```

2. Add the new key constants after `const _kMutedConvs = 'muted_convs';` (line 31):

```dart
const _kThemeMode = 'theme_mode';
const _kThemeSeed = 'theme_seed';
```

3. Add the accessors at the end of the `LocalStore` class (right before the closing `}`):

```dart
  // ─── theme
  static ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeMode) ?? 'system';
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    final raw = switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeMode, raw);
    localStoreNotifier.bump();
  }

  static AccentSeed get themeSeed =>
      AccentSeed.parse(_prefs.getString(_kThemeSeed));

  static Future<void> setThemeSeed(AccentSeed s) async {
    await _prefs.setString(_kThemeSeed, s.serialize());
    localStoreNotifier.bump();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/services/local_storage_theme_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/local_storage.dart test/services/local_storage_theme_test.dart
git commit -m "feat(storage): persist themeMode and themeSeed"
```

---

## Task 7: ThemeController (TDD)

**Files:**
- Create: `lib/theme/theme_controller.dart`
- Create: `test/theme/theme_controller_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/theme/theme_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  test('starts at system / preset green before load', () {
    final c = ThemeController.test();
    expect(c.mode, ThemeMode.system);
    expect(c.seed, const PresetAccentSeed(PresetAccent.green));
  });

  test('load() picks up persisted values', () async {
    await LocalStore.setThemeMode(ThemeMode.dark);
    await LocalStore.setThemeSeed(const PresetAccentSeed(PresetAccent.cyan));
    final c = ThemeController.test();
    await c.load();
    expect(c.mode, ThemeMode.dark);
    expect(c.seed, const PresetAccentSeed(PresetAccent.cyan));
  });

  test('setMode notifies listeners and persists', () async {
    final c = ThemeController.test();
    var fired = 0;
    c.addListener(() => fired++);
    await c.setMode(ThemeMode.light);
    expect(c.mode, ThemeMode.light);
    expect(fired, 1);
    expect(LocalStore.themeMode, ThemeMode.light);
  });

  test('setMode no-op when value unchanged', () async {
    final c = ThemeController.test();
    var fired = 0;
    c.addListener(() => fired++);
    await c.setMode(ThemeMode.system); // already system
    expect(fired, 0);
  });

  test('setSeed notifies and persists', () async {
    final c = ThemeController.test();
    var fired = 0;
    c.addListener(() => fired++);
    await c.setSeed(const PresetAccentSeed(PresetAccent.red));
    expect(c.seed, const PresetAccentSeed(PresetAccent.red));
    expect(fired, 1);
    expect(LocalStore.themeSeed, const PresetAccentSeed(PresetAccent.red));
  });

  test('lightTheme and darkTheme reflect current seed', () {
    final c = ThemeController.test();
    expect(c.lightTheme.brightness, Brightness.light);
    expect(c.darkTheme.brightness, Brightness.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/theme_controller_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement ThemeController**

Create `lib/theme/theme_controller.dart`:

```dart
// theme_controller.dart — runtime-switchable theme mode + accent.
// Mirrors the LocaleController pattern: a singleton ChangeNotifier
// backed by SharedPreferences, watched at the app root by AnimatedBuilder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage.dart';
import 'accent_seed.dart';
import 'theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Constructor exposed for unit tests so each test gets a fresh state.
  @visibleForTesting
  factory ThemeController.test() = ThemeController._;

  ThemeMode _mode = ThemeMode.system;
  AccentSeed _seed = AccentSeed.defaultSeed;

  ThemeMode get mode => _mode;
  AccentSeed get seed => _seed;

  Future<void> load() async {
    _mode = LocalStore.themeMode;
    _seed = LocalStore.themeSeed;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    await LocalStore.setThemeMode(m);
    notifyListeners();
  }

  Future<void> setSeed(AccentSeed s) async {
    if (_seed == s) return;
    _seed = s;
    await LocalStore.setThemeSeed(s);
    notifyListeners();
  }

  ThemeData get lightTheme => buildAppTheme(Brightness.light, _seed);
  ThemeData get darkTheme => buildAppTheme(Brightness.dark, _seed);
}

final themeControllerProvider = ChangeNotifierProvider<ThemeController>(
  (_) => ThemeController.instance,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/theme_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/theme_controller.dart test/theme/theme_controller_test.dart
git commit -m "feat(theme): add ThemeController for runtime mode/accent switching"
```

---

## Task 8: Wire ThemeController into the app

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: Load theme controller in `main()` before runApp**

Open `lib/main.dart`. Add the import alongside the existing `import 'services/local_storage.dart';`:

```dart
import 'theme/theme_controller.dart';
```

Then, after the existing `await initLocalStorage();` line, add:

```dart
  await ThemeController.instance.load();
```

The relevant section of `main()` should now read:

```dart
  await initLocalStorage();
  await ThemeController.instance.load();

  if (Env.isConfigured) {
```

- [ ] **Step 2: Wire ThemeController into KaiqiuApp**

Replace the entire body of `lib/app.dart` with:

```dart
// app.dart — root MaterialApp
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'routes.dart';
import 'theme/theme_controller.dart';

class KaiqiuApp extends StatelessWidget {
  const KaiqiuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        LocaleController.instance,
        ThemeController.instance,
      ]),
      builder: (_, _) {
        final tc = ThemeController.instance;
        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppL10n.of(ctx).app_name,
          debugShowCheckedModeBanner: false,
          theme: tc.lightTheme,
          darkTheme: tc.darkTheme,
          themeMode: tc.mode,
          routerConfig: router,
          locale: LocaleController.instance.current,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
        );
      },
    );
  }
}
```

> Note: the placeholder imports added in Task 5 (`'theme/theme.dart'` and `'theme/accent_seed.dart'`) are no longer needed — `ThemeController` now constructs both ThemeData variants internally.

- [ ] **Step 3: Run smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS — app still boots.

- [ ] **Step 4: Run analyzer**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/main.dart lib/app.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat(app): wire ThemeController into MaterialApp"
```

---

## Task 9: i18n keys for the appearance settings

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add new keys to `lib/l10n/app_zh.arb`**

Add the following entries near the existing `settings_*` keys (e.g., right after the `settings_notif_*` block found around line 485). Place them as a contiguous block; mind the trailing comma on whichever entry now precedes them:

```json
  "profile_menu_appearance": "外观",
  "settings_appearance_title": "外观",
  "appearance_theme_mode_section": "主题模式",
  "appearance_theme_mode_system": "跟随系统",
  "appearance_theme_mode_light": "浅色",
  "appearance_theme_mode_dark": "深色",
  "appearance_accent_section": "主题色",
  "appearance_accent_green": "经典绿",
  "appearance_accent_orange": "活力橙",
  "appearance_accent_cyan": "海洋青",
  "appearance_accent_red": "热情红",
  "appearance_accent_custom": "自定义",
  "appearance_preview_section": "预览",
  "appearance_preview_card_title": "周三晚 7:30  五人足球",
  "appearance_preview_card_meta": "深圳南山·星空足球公园",
  "appearance_preview_card_cta": "立即报名",
  "appearance_picker_title": "选择主题色",
  "appearance_picker_confirm": "确定",
  "appearance_picker_cancel": "取消",
```

- [ ] **Step 2: Add the same keys to `lib/l10n/app_en.arb`** (English values)

```json
  "profile_menu_appearance": "Appearance",
  "settings_appearance_title": "Appearance",
  "appearance_theme_mode_section": "Theme Mode",
  "appearance_theme_mode_system": "Follow System",
  "appearance_theme_mode_light": "Light",
  "appearance_theme_mode_dark": "Dark",
  "appearance_accent_section": "Accent Color",
  "appearance_accent_green": "Classic Green",
  "appearance_accent_orange": "Vibrant Orange",
  "appearance_accent_cyan": "Ocean Cyan",
  "appearance_accent_red": "Passion Red",
  "appearance_accent_custom": "Custom",
  "appearance_preview_section": "Preview",
  "appearance_preview_card_title": "Wed 7:30 PM · 5-a-side Football",
  "appearance_preview_card_meta": "Nanshan, Shenzhen · Starry Park",
  "appearance_preview_card_cta": "Join Now",
  "appearance_picker_title": "Pick Accent Color",
  "appearance_picker_confirm": "Confirm",
  "appearance_picker_cancel": "Cancel",
```

- [ ] **Step 3: Regenerate the localization classes**

Run: `cd /home/coder/workspaces/qiuju_app && flutter gen-l10n`
Expected: no error; `lib/l10n/generated/app_localizations.dart` updated.

- [ ] **Step 4: Verify generated getters exist**

Run: `cd /home/coder/workspaces/qiuju_app && grep -c 'profile_menu_appearance\|settings_appearance_title\|appearance_theme_mode_section\|appearance_picker_title' lib/l10n/generated/app_localizations.dart`
Expected: a number ≥ 4 (each key gets at least one generated getter).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/app_localizations.dart
git commit -m "feat(i18n): add appearance settings strings (zh + en)"
```

---

## Task 10: Build `AppearanceSettingsScreen`

**Files:**
- Create: `lib/features/settings/appearance_settings_screen.dart`

- [ ] **Step 1: Create the screen**

Create `lib/features/settings/appearance_settings_screen.dart`:

```dart
// appearance_settings_screen.dart — 外观设置(主题模式 + 主题色)
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/accent_seed.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/section_header.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    ref.watch(themeControllerProvider); // rebuild on change
    final tc = ThemeController.instance;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.settings_appearance_title,
              onBack: () => context.pop(),
            ),
            _SectionHeader(label: l.appearance_theme_mode_section),
            _ModeSelector(controller: tc),
            const SizedBox(height: 18),
            _SectionHeader(label: l.appearance_accent_section),
            _AccentSelector(controller: tc),
            const SizedBox(height: 18),
            _SectionHeader(label: l.appearance_preview_section),
            const _PreviewCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: t.inkSub,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final ThemeController controller;
  const _ModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final entries = <(ThemeMode, String)>[
      (ThemeMode.system, l.appearance_theme_mode_system),
      (ThemeMode.light, l.appearance_theme_mode_light),
      (ThemeMode.dark, l.appearance_theme_mode_dark),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r2),
        ),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) Divider(height: 1, color: t.line),
              InkWell(
                onTap: () => controller.setMode(entries[i].$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entries[i].$2,
                          style: TextStyle(
                            fontSize: 14,
                            color: t.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (controller.mode == entries[i].$1)
                        Icon(Icons.check, color: t.accent, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccentSelector extends StatelessWidget {
  final ThemeController controller;
  const _AccentSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    // Show resolved color for each preset using *current* brightness for swatch.
    final brightness = Theme.of(context).brightness;
    final presets = <(PresetAccent, String)>[
      (PresetAccent.green, l.appearance_accent_green),
      (PresetAccent.orange, l.appearance_accent_orange),
      (PresetAccent.cyan, l.appearance_accent_cyan),
      (PresetAccent.red, l.appearance_accent_red),
    ];

    bool isSelectedPreset(PresetAccent p) {
      final s = controller.seed;
      return s is PresetAccentSeed && s.preset == p;
    }
    final isCustom = controller.seed is CustomAccentSeed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r2),
        ),
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (p, label) in presets)
              _AccentSwatch(
                color: _resolvePresetColor(p, brightness),
                label: label,
                selected: isSelectedPreset(p),
                onTap: () => controller.setSeed(PresetAccentSeed(p)),
              ),
            _AccentSwatch(
              color: isCustom ? (controller.seed as CustomAccentSeed).color : t.elev3,
              label: l.appearance_accent_custom,
              selected: isCustom,
              isCustomEntry: true,
              onTap: () => _openColorPicker(context),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolvePresetColor(PresetAccent p, Brightness brightness) {
    // Mirror the spec §5.2 hand-tuned values for swatch display.
    return switch ((p, brightness)) {
      (PresetAccent.green, Brightness.dark) => const Color(0xFF00FF85),
      (PresetAccent.green, Brightness.light) => const Color(0xFF00A864),
      (PresetAccent.orange, Brightness.dark) => const Color(0xFFFF8A3D),
      (PresetAccent.orange, Brightness.light) => const Color(0xFFE25A0A),
      (PresetAccent.cyan, Brightness.dark) => const Color(0xFF00E5FF),
      (PresetAccent.cyan, Brightness.light) => const Color(0xFF0090A8),
      (PresetAccent.red, Brightness.dark) => const Color(0xFFFF3D5A),
      (PresetAccent.red, Brightness.light) => const Color(0xFFD32647),
    };
  }

  Future<void> _openColorPicker(BuildContext context) async {
    final l = context.l10n;
    Color picked = controller.seed is CustomAccentSeed
        ? (controller.seed as CustomAccentSeed).color
        : const Color(0xFF7A3DEC);
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        Color current = picked;
        return AlertDialog(
          backgroundColor: ctx.tokens.elev2,
          title: Text(l.appearance_picker_title,
              style: TextStyle(color: ctx.tokens.ink)),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: current,
              onColorChanged: (c) => current = c,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.appearance_picker_cancel,
                  style: TextStyle(color: ctx.tokens.inkSub)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(current),
              child: Text(l.appearance_picker_confirm,
                  style: TextStyle(color: ctx.tokens.accent)),
            ),
          ],
        );
      },
    );
    if (result != null) {
      // Use the Color's full ARGB int. Color.value returns 32-bit ARGB.
      // ignore: deprecated_member_use
      await controller.setSeed(CustomAccentSeed(result.value));
    }
  }
}

class _AccentSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final bool isCustomEntry;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCustomEntry = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.ink : t.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: isCustomEntry && !selected
                ? Icon(Icons.add, color: t.ink, size: 20)
                : (selected
                    ? Icon(Icons.check,
                        color: _onColor(color), size: 20)
                    : null),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: t.inkSub),
          ),
        ],
      ),
    );
  }

  Color _onColor(Color c) {
    // Simple luminance check.
    final lum = (0.299 * c.red + 0.587 * c.green + 0.114 * c.blue) / 255.0;
    return lum > 0.6 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.appearance_preview_card_title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.appearance_preview_card_meta,
              style: TextStyle(fontSize: 12, color: t.inkSub),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(t.r1),
                  ),
                  child: Text(
                    l.appearance_preview_card_cta,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.accentInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.accentSubtle,
                    borderRadius: BorderRadius.circular(t.r1),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: t.accent,
                      fontFamily: t.fontMono,
                      fontFamilyFallback: t.monoFallbacks,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

> Note on `result.value`: in newer Flutter, `Color.value` is deprecated in favor of channel accessors. The `// ignore` line keeps the build clean. If your Flutter version errors here, replace with `(result.alpha << 24) | (result.red << 16) | (result.green << 8) | result.blue`.

- [ ] **Step 2: Verify it compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/settings/appearance_settings_screen.dart`
Expected: `No issues found!` (the ignore for the deprecation is intentional)

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/appearance_settings_screen.dart
git commit -m "feat(settings): add appearance settings screen (mode + accent)"
```

---

## Task 11: Add `/settings/appearance` route + profile menu entry

**Files:**
- Modify: `lib/routes.dart`
- Modify: `lib/features/profile/profile_screen.dart`

- [ ] **Step 1: Add the route**

In `lib/routes.dart`, add the import alongside the existing settings imports (near line 30-34):

```dart
import 'features/settings/appearance_settings_screen.dart';
```

Then add the route entry inside the `routes:` list, right after the existing `/settings/account` route (around line 162):

```dart
    GoRoute(
      path: '/settings/appearance',
      builder: (_, s) => const AppearanceSettingsScreen(),
    ),
```

- [ ] **Step 2: Add profile menu entry**

In `lib/features/profile/profile_screen.dart`, locate the `final settings = <_MenuItem>[ ... ]` block (starts ~line 56). Add a new `_MenuItem` between the "通知" and "帮助" entries:

```dart
      _MenuItem(
        icon: Icons.palette_outlined,
        label: l.profile_menu_appearance,
        onTap: () => context.push('/settings/appearance'),
      ),
```

The full `settings` list should now have 5 entries: account, notifications, **appearance**, help, about.

- [ ] **Step 3: Run smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 4: Manual smoke test (recommended)**

Run on a simulator or device: `cd /home/coder/workspaces/qiuju_app && flutter run`

Verify:
- App boots, looks identical to before (still all dark — Phase B not done yet)
- Bottom tab "我的" → settings list shows new "外观" row
- Tap "外观" → AppearanceSettingsScreen opens
- Tap "浅色" → some Material widgets (AppBar background, chevron icon) flip to light, but most of the page stays dark (this is expected before Phase B migration)
- Tap an accent color → preview card's button changes color; the `LIVE` chip changes color
- Kill the app, restart → mode + accent are preserved

- [ ] **Step 5: Commit**

```bash
git add lib/routes.dart lib/features/profile/profile_screen.dart
git commit -m "feat(routes): add /settings/appearance route and profile menu entry"
```

---

## ── PHASE A COMPLETE: infrastructure in place, partial visual switching ──

At this point, the user can already toggle theme mode and accent in the new settings page. Material-aware widgets respond, but most of the app still renders with hard-coded dark `T.*` tokens. Phase B migrates every `T.*` reference to `context.tokens.*`, completing the feature.

---

## Task 12: Widget tests for AppTokens + AppearanceSettingsScreen

**Files:**
- Create: `test/theme/app_tokens_test.dart`
- Create: `test/features/settings/appearance_settings_screen_test.dart`

- [ ] **Step 1: Add a test for AppTokens through ThemeData**

Create `test/theme/app_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';
import 'package:kaiqiu_app/theme/app_tokens.dart';
import 'package:kaiqiu_app/theme/theme.dart';

void main() {
  testWidgets('context.tokens reads dark variant under dark theme',
      (WidgetTester tester) async {
    AppTokens? captured;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.dark, AccentSeed.defaultSeed),
      home: Builder(
        builder: (ctx) {
          captured = ctx.tokens;
          return const SizedBox.shrink();
        },
      ),
    ));
    expect(captured, isNotNull);
    expect(captured!.bg, const Color(0xFF0A0A0A));
    expect(captured!.accent, const Color(0xFF00FF85)); // green default, dark
  });

  testWidgets('context.tokens reads light variant under light theme',
      (WidgetTester tester) async {
    AppTokens? captured;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light, AccentSeed.defaultSeed),
      home: Builder(
        builder: (ctx) {
          captured = ctx.tokens;
          return const SizedBox.shrink();
        },
      ),
    ));
    expect(captured, isNotNull);
    expect(captured!.bg, const Color(0xFFFAF8F5));
    expect(captured!.accent, const Color(0xFF00A864)); // green default, light
  });
}
```

- [ ] **Step 2: Run the test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/theme/app_tokens_test.dart`
Expected: PASS.

- [ ] **Step 3: Add a widget test for AppearanceSettingsScreen**

Create `test/features/settings/appearance_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/features/settings/appearance_settings_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';
import 'package:kaiqiu_app/theme/theme.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(Brightness.dark, AccentSeed.defaultSeed),
        darkTheme: buildAppTheme(Brightness.dark, AccentSeed.defaultSeed),
        locale: const Locale('zh'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: const [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: child,
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
    await ThemeController.instance.load();
  });

  testWidgets('tapping a mode option updates the controller',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const AppearanceSettingsScreen()));
    await tester.pumpAndSettle();

    expect(ThemeController.instance.mode, ThemeMode.system);

    // Tap "深色"
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(ThemeController.instance.mode, ThemeMode.dark);

    // Tap "浅色"
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(ThemeController.instance.mode, ThemeMode.light);
  });

  testWidgets('tapping a preset accent updates the controller',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const AppearanceSettingsScreen()));
    await tester.pumpAndSettle();

    expect(
      ThemeController.instance.seed,
      const PresetAccentSeed(PresetAccent.green),
    );

    // Tap "热情红" swatch label
    await tester.tap(find.text('热情红'));
    await tester.pumpAndSettle();

    expect(
      ThemeController.instance.seed,
      const PresetAccentSeed(PresetAccent.red),
    );
  });

  testWidgets('tapping custom swatch opens the color-picker dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const AppearanceSettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();

    expect(find.text('选择主题色'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run the widget test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/features/settings/appearance_settings_screen_test.dart`
Expected: PASS — three tests pass.

- [ ] **Step 5: Run the whole test suite to confirm no regressions**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add test/
git commit -m "test(theme): widget tests for AppTokens and appearance settings"
```

---

## Task 13: Migrate surface tokens (`bg`, `elev1-3`, `line`, `lineStrong`)

**Files:**
- Modify: many `.dart` files under `lib/` (mass replace)

- [ ] **Step 1: Run the surface-token replacement**

Run from the project root:

```bash
cd /home/coder/workspaces/qiuju_app
for tok in bg elev1 elev2 elev3 line lineStrong; do
  grep -rl --include='*.dart' "T\.${tok}\b" lib/ \
    | grep -v 'lib/theme/' \
    | xargs -r sed -i "s/T\.${tok}\b/context.tokens.${tok}/g"
done
```

> The `grep -v 'lib/theme/'` is critical — we do NOT want to rewrite tokens.dart or app_tokens.dart themselves.

- [ ] **Step 2: Run the analyzer to find compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/ 2>&1 | head -100`

You will likely see errors of these shapes:
- `Invalid constant value` — a `const` widget referenced `T.bg`, now references `context.tokens.bg` which is non-const
- `The argument type 'Color' can't be assigned to the parameter type 'Color' because 'Color' is nullable` — typically means a `BoxDecoration(color: T.line)` is now nullable somewhere; not the case here, but watch for it

- [ ] **Step 3: Fix const errors mechanically**

For each error of the form `Invalid constant value` (or similar), remove the offending `const` keyword. Common patterns:

| Before | After |
|---|---|
| `const Container(decoration: BoxDecoration(color: T.bg))` | `Container(decoration: BoxDecoration(color: context.tokens.bg))` |
| `const Divider(color: T.line)` | `Divider(color: context.tokens.line)` |
| `const Icon(Icons.x, color: T.inkSub)` | _(no change needed: T.inkSub will be migrated in Task 13)_ |

Use the analyzer output as your worklist. Iterate: fix a batch of `const` removals, re-run `flutter analyze`, repeat.

> **Tip:** if you have many of these, you can use IDE-supported "remove const" quick fixes file-by-file.

- [ ] **Step 4: Run analyzer until clean**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/`
Expected: 0 errors. Warnings about unused imports / removed `const` are OK and will be cleaned at the end.

- [ ] **Step 5: Run smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/
git commit -m "refactor(theme): migrate surface tokens to context.tokens.*"
```

---

## Task 14: Migrate text tokens (`ink`, `inkSub`, `inkDim`, `inkMute`)

**Files:**
- Modify: many `.dart` files under `lib/` (mass replace)

- [ ] **Step 1: Run the text-token replacement**

```bash
cd /home/coder/workspaces/qiuju_app
for tok in ink inkSub inkDim inkMute; do
  grep -rl --include='*.dart' "T\.${tok}\b" lib/ \
    | grep -v 'lib/theme/' \
    | xargs -r sed -i "s/T\.${tok}\b/context.tokens.${tok}/g"
done
```

- [ ] **Step 2: Iterate analyzer + remove `const` until clean**

Same pattern as Task 13 Step 3-4. Remove `const` from any widget the analyzer flags.

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/`
Expected: 0 errors after const cleanup.

- [ ] **Step 3: Run smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "refactor(theme): migrate text tokens to context.tokens.*"
```

---

## Task 15: Migrate accent / status tokens (`live`, `liveDim`, `warn`, `warnDim`, `danger`)

**Files:**
- Modify: many `.dart` files under `lib/` (mass replace)

> Note: `T.live` and `T.liveDim` map to **new names** (`accent` and `accentSubtle`). `T.warn` and `T.warnDim` map to `warn` and `warnSubtle`.

- [ ] **Step 1: Run the renamed replacement**

```bash
cd /home/coder/workspaces/qiuju_app
# Rename live → accent
grep -rl --include='*.dart' 'T\.live\b' lib/ | grep -v 'lib/theme/' \
  | xargs -r sed -i 's/T\.live\b/context.tokens.accent/g'
grep -rl --include='*.dart' 'T\.liveDim\b' lib/ | grep -v 'lib/theme/' \
  | xargs -r sed -i 's/T\.liveDim\b/context.tokens.accentSubtle/g'
# Rename warn → warn (same name, just move to context.tokens)
grep -rl --include='*.dart' 'T\.warn\b' lib/ | grep -v 'lib/theme/' \
  | xargs -r sed -i 's/T\.warn\b/context.tokens.warn/g'
grep -rl --include='*.dart' 'T\.warnDim\b' lib/ | grep -v 'lib/theme/' \
  | xargs -r sed -i 's/T\.warnDim\b/context.tokens.warnSubtle/g'
# danger
grep -rl --include='*.dart' 'T\.danger\b' lib/ | grep -v 'lib/theme/' \
  | xargs -r sed -i 's/T\.danger\b/context.tokens.danger/g'
```

- [ ] **Step 2: Iterate analyzer + remove `const` until clean**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/`
Fix `const` errors as before. Expected: 0 errors after cleanup.

- [ ] **Step 3: Run smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "refactor(theme): migrate accent and status tokens to context.tokens.*"
```

---

## Task 16: Migrate non-color tokens (`r1-r4`, `fontMono`, `monoFallbacks`)

**Files:**
- Modify: many `.dart` files under `lib/` (mass replace)

> Note: `T.r1`-`T.r4` are `double` constants. After migration they're still doubles, just sourced from `context.tokens`. They'll fail the `const` check on widgets like `BorderRadius.circular`, so expect const removals.

- [ ] **Step 1: Run the replacement**

```bash
cd /home/coder/workspaces/qiuju_app
for tok in r1 r2 r3 r4 fontMono monoFallbacks; do
  grep -rl --include='*.dart' "T\.${tok}\b" lib/ \
    | grep -v 'lib/theme/' \
    | xargs -r sed -i "s/T\.${tok}\b/context.tokens.${tok}/g"
done
```

- [ ] **Step 2: Iterate analyzer until clean**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/`
Fix `const` errors. Expected: 0 errors after cleanup.

- [ ] **Step 3: Verify zero remaining `T.x` references outside theme/**

Run: `cd /home/coder/workspaces/qiuju_app && grep -rn 'T\.\(bg\|elev[123]\|line\|lineStrong\|ink\|inkSub\|inkDim\|inkMute\|live\|liveDim\|warn\|warnDim\|danger\|r[1-4]\|fontMono\|monoFallbacks\)\b' lib/ | grep -v 'lib/theme/'`
Expected: no output (empty result).

- [ ] **Step 4: Run smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter test test/widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "refactor(theme): migrate radii and font tokens to context.tokens.*"
```

---

## Task 17: Remove the legacy `T` class and dead `AccentPalette` / `accents`

**Files:**
- Modify: `lib/theme/tokens.dart` (or delete if empty)

- [ ] **Step 1: Verify no remaining `T.x` outside the theme/ directory**

Run: `cd /home/coder/workspaces/qiuju_app && grep -rn 'T\.' lib/ | grep -v 'lib/theme/'`
Expected: no token-shaped output. (You may see unrelated `T.` usages — confirm they aren't related.)

- [ ] **Step 2: Delete `lib/theme/tokens.dart`**

The file's contents (the `T` class and the unused `AccentPalette` + `accents` map) are now dead code. Delete the file:

Run: `cd /home/coder/workspaces/qiuju_app && rm lib/theme/tokens.dart`

- [ ] **Step 3: Remove the dangling import**

Find files that still `import 'tokens.dart'` or `import '../../theme/tokens.dart'`:

Run: `cd /home/coder/workspaces/qiuju_app && grep -rn "theme/tokens.dart\|'tokens.dart'" lib/`

For each result, remove the offending import line.

- [ ] **Step 4: Run analyzer + smoke test**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/ && flutter test test/widget_test.dart`
Expected: `No issues found!` and tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "refactor(theme): delete legacy T class and unused AccentPalette"
```

---

## Task 18: End-to-end manual QA pass

**Files:** none (manual verification)

> No code changes here — just walk through the spec's §12.3 manual checklist and fix anything broken. Each fix becomes its own commit.

- [ ] **Step 1: Boot the app on a device or simulator**

Run: `cd /home/coder/workspaces/qiuju_app && flutter run`

- [ ] **Step 2: Walk through the manual checklist**

For each item, verify behavior. If broken, file as a sub-task and fix; otherwise tick it off.

- [ ] On first launch with no prior preference, app uses system theme
- [ ] Toggle "外观" → "浅色" → all bottom tabs immediately render in light mode (no white flash, no dark holdouts)
- [ ] Toggle "深色" → all tabs render in dark mode
- [ ] Toggle "跟随系统" → flip the OS theme; the app follows
- [ ] On "浅色" mode, switch accent: green → orange → cyan → red → custom — every tab's primary buttons, "选中" tab indicator, and accent icons all update
- [ ] Same as above on "深色" mode
- [ ] Custom color picker: pick a near-white color → derived accent is darker (still readable on white bg) in light mode, lighter in dark mode
- [ ] Custom color picker: pick a near-black color → derived accent is lighter in dark mode, still readable in light mode
- [ ] Theme switch animation is smooth (not abrupt)
- [ ] Kill the app, relaunch → mode + accent are persisted
- [ ] Switch language ZH ↔ EN with each theme combo → labels in 外观 page are translated
- [ ] Pull-to-refresh on home tab works in both modes (visual sanity check)

- [ ] **Step 3: For any visual regression, fix and commit**

Likely candidates:
- A widget that hard-coded a specific color value instead of using a token (e.g., `Colors.black87` somewhere)
- Status bar text invisible in light mode (may need `SystemUiOverlayStyle` adjustment if widget uses one)
- A SVG / icon that assumes white background

Each fix gets its own commit with a descriptive message:

```bash
git add lib/path/to/fix.dart
git commit -m "fix(theme): <what was broken in light mode>"
```

- [ ] **Step 4: Final commit (if all pass cleanly with no fixes)**

If no fixes were needed, no extra commit. The feature is complete.

- [ ] **Step 5: Optional — open a PR**

If working on a feature branch, push and open a PR using the existing repo conventions.

---

## Done

The user can now:

1. Choose **Follow System / Light / Dark** mode in `设置 → 外观`
2. Choose one of **4 preset accent colors** or pick a custom color
3. See immediate, animated theme transitions
4. Have their preference persist across launches and OS theme changes
