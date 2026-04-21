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
