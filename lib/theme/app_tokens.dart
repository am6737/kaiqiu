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
  static const String _fontMono = 'JetBrainsMono';
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
