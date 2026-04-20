// tokens.dart — 开球 design tokens
// Minimal data-forward dark theme. Neon green as 点睛 only.
//
// Ported from the React prototype's design-system.jsx.

import 'package:flutter/material.dart';

class T {
  T._();

  // Surface layers (dark → darker)
  static const bg = Color(0xFF0A0A0A);
  static const elev1 = Color(0xFF111111);
  static const elev2 = Color(0xFF171717);
  static const elev3 = Color(0xFF1F1F1F);
  static const line = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const lineStrong = Color(0x1FFFFFFF); // 0.12

  // Text
  static const ink = Color(0xF5FFFFFF); // 0.96
  static const inkSub = Color(0x9EFFFFFF); // 0.62
  static const inkDim = Color(0x61FFFFFF); // 0.38
  static const inkMute = Color(0x38FFFFFF); // 0.22

  // Accents — 点睛 only
  // Note: accent can be switched at runtime (green/orange/cyan/red).
  // For simplicity at MVP we hardcode green; wire AccentController later.
  static const live = Color(0xFF00FF85);
  static const liveDim = Color(0x1F00FF85); // 0.12
  static const warn = Color(0xFFFF6B35);
  static const warnDim = Color(0x24FF6B35); // 0.14

  static const danger = Color(0xFFFF3B6B);

  // Radii
  static const r1 = 6.0;
  static const r2 = 10.0;
  static const r3 = 14.0;
  static const r4 = 20.0;

  // Spacing scale
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;

  // Fonts — system fonts for Chinese + JetBrainsMono for numbers
  // When we add the font asset, change to 'JetBrainsMono'. For now fall back
  // to system monospace (iOS: SF Mono, Android: Roboto Mono).
  static const fontUi = null; // null = system default
  static const fontMono = 'JetBrainsMono';
  // Fallbacks if JetBrainsMono asset is not yet bundled:
  static const monoFallbacks = ['SF Mono', 'Menlo', 'Consolas', 'monospace'];
}

class AccentPalette {
  final Color live;
  final Color liveDim;
  const AccentPalette(this.live, this.liveDim);
}

const accents = {
  'green': AccentPalette(Color(0xFF00FF85), Color(0x1F00FF85)),
  'orange': AccentPalette(Color(0xFFFF6B35), Color(0x24FF6B35)),
  'cyan': AccentPalette(Color(0xFF00E5FF), Color(0x2100E5FF)),
  'red': AccentPalette(Color(0xFFFF3B6B), Color(0x24FF3B6B)),
};
