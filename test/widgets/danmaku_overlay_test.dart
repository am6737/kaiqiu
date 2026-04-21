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

    testWidgets('renders a self-authored danmu with accent pill', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      ctrl.add(const DanmakuItem(user: 'Me', text: 'mine', self: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('mine'), findsOneWidget);
      // Confirm the pill container exists: find a DecoratedBox ancestor of the text.
      final decorated = find.ancestor(
        of: find.text('mine'),
        matching: find.byType(DecoratedBox),
      );
      expect(decorated, findsWidgets);

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('4 danmus land on 4 distinct tracks', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        ctrl.add(DanmakuItem(user: 'U$i', text: 'msg$i', self: false));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      final positions = <double>{};
      for (var i = 0; i < 4; i++) {
        final f = find.text('msg$i');
        expect(f, findsOneWidget);
        final rect = tester.getRect(f);
        positions.add(rect.top.roundToDouble());
      }
      expect(positions.length, 4, reason: 'each danmu on its own track');

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('5th danmu is dropped when all tracks busy', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        ctrl.add(DanmakuItem(user: 'U$i', text: 'msg$i', self: false));
        await tester.pump();
      }
      // Immediately push a 5th; no track has freed up yet.
      ctrl.add(const DanmakuItem(user: 'X', text: 'dropped', self: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('dropped'), findsNothing);

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('enabled: false drops incoming danmus', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(
        DanmakuOverlay(stream: ctrl.stream, enabled: false),
      ));
      await tester.pump();

      ctrl.add(const DanmakuItem(user: 'A', text: 'silenced', self: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('silenced'), findsNothing);
    });

    testWidgets('danmus render inside [80, height-40] region', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        ctrl.add(DanmakuItem(user: 'U$i', text: 'msg$i', self: false));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 4; i++) {
        final r = tester.getRect(find.text('msg$i'));
        // Overlay is 240 tall; effective region [80, 200].
        expect(r.top, greaterThanOrEqualTo(80.0 - 0.5));
        expect(r.bottom, lessThanOrEqualTo(200.0 + 0.5));
      }

      await tester.pump(const Duration(seconds: 10));
    });
  });
}
