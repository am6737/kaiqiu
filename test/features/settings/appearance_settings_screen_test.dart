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

// Override the Riverpod provider with a fresh ThemeController.test() each time
// so ProviderScope disposes the test instance — not the ThemeController.instance
// singleton. The screen reads ThemeController.instance directly for mutations,
// so assertions on ThemeController.instance remain valid.
Widget _wrap(Widget child) {
  // ignore: invalid_use_of_visible_for_testing_member
  final testController = ThemeController.test();
  return ProviderScope(
    overrides: [
      themeControllerProvider.overrideWith((_) => testController),
    ],
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
}

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
