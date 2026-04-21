import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/features/events/wc_live_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/providers.dart';

Widget _wrap(Widget child) {
  final t = ThemeController.test();
  // Override localStoreProvider with a fresh instance each time so that
  // ProviderScope disposal does not call dispose() on the global singleton.
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWith((_) => LocalStoreNotifier()),
    ],
    child: MaterialApp(
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('sending a message puts text into both chat list and overlay',
      (tester) async {
    await tester.pumpWidget(_wrap(const WcLiveScreen(matchId: 'm-test')));
    await tester.pump();

    final input = find.byType(TextField);
    await tester.enterText(input, 'hello-overlay');
    await tester.pump();

    // Tap the send button (GestureDetector with Icons.send inside).
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Two occurrences: one in the danmaku overlay (Text('hello-overlay'))
    // and one in the bubble list (Text.rich with plain text 'You: hello-overlay').
    // textContaining matches both since both contain the substring.
    expect(find.textContaining('hello-overlay'), findsNWidgets(2));

    // Drain animations.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('toggling danmaku off keeps chat list but stops overlay',
      (tester) async {
    await tester.pumpWidget(_wrap(const WcLiveScreen(matchId: 'm-test-2')));
    await tester.pump();

    // Tap the danmaku toggle button (initially "弹幕 开" — has Icons.subtitles).
    await tester.tap(find.byIcon(Icons.subtitles));
    await tester.pump();

    // Now send a message.
    await tester.enterText(find.byType(TextField), 'solo-list');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Should appear exactly once — only in the bubble list below.
    // The danmaku overlay is disabled so it won't render the text.
    expect(find.textContaining('solo-list'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
  });
}
