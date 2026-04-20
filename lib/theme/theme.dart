// theme.dart — ThemeData for the 开球 app
import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildAppTheme() {
  const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: T.ink,
    ),
    displayMedium: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: T.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: T.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: T.ink,
    ),
    bodyLarge: TextStyle(fontSize: 15, color: T.ink, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, color: T.inkSub, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, color: T.inkSub),
    labelSmall: TextStyle(fontSize: 10, color: T.inkDim, letterSpacing: 1.2),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: T.bg,
    colorScheme: const ColorScheme.dark(
      surface: T.bg,
      primary: T.live,
      onPrimary: Color(0xFF000000),
      secondary: T.warn,
      error: T.danger,
    ),
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
