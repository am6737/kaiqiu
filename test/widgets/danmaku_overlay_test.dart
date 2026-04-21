import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/theme/app_tokens.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/danmaku_overlay.dart';

Widget _wrap(Widget child) {
  // Use the project's real theme so context.tokens works.
  final ctrl = ThemeController.test();
  return MaterialApp(
    theme: ctrl.lightTheme,
    darkTheme: ctrl.darkTheme,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 240,
        child: child,
      ),
    ),
  );
}

void main() {
  group('DanmakuItem', () {
    test('stores user, text, self', () {
      const item = DanmakuItem(user: 'Alice', text: 'gg', self: true);
      expect(item.user, 'Alice');
      expect(item.text, 'gg');
      expect(item.self, true);
    });
  });

  group('DanmakuOverlay', () {
    testWidgets('renders a danmu pushed onto its stream', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      ctrl.add(const DanmakuItem(user: 'A', text: 'hello-world', self: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('hello-world'), findsOneWidget);

      // Let animations finish so the widget tree is clean on dispose.
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
