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
