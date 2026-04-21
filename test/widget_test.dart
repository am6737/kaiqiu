// Smoke test for the app shell. Supabase is not initialized in tests, so
// we render KaiqiuApp directly and just verify it builds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaiqiu_app/app.dart';

void main() {
  testWidgets('App boots and shows bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(const KaiqiuApp());
    // Router settles on '/home' initial route with BottomNavShell present.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('约球'), findsOneWidget);
    expect(find.text('赛事'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
