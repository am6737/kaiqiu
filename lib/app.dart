// app.dart — root MaterialApp
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'routes.dart';
import 'theme/theme_controller.dart';

class KaiqiuApp extends StatelessWidget {
  const KaiqiuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        LocaleController.instance,
        ThemeController.instance,
      ]),
      builder: (_, _) {
        final tc = ThemeController.instance;
        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppL10n.of(ctx).app_name,
          debugShowCheckedModeBanner: false,
          theme: tc.lightTheme,
          darkTheme: tc.darkTheme,
          themeMode: tc.mode,
          routerConfig: router,
          locale: LocaleController.instance.current,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
        );
      },
    );
  }
}
