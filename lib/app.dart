// app.dart — root MaterialApp
import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'config/env.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'routes.dart';
import 'theme/theme_controller.dart';

class KaiqiuApp extends StatelessWidget {
  const KaiqiuApp({super.key});

  @override
  Widget build(BuildContext context) {
    AMapInitializer.init(context, apiKey: AMapApiKey(
      androidKey: Env.amapKey,
      iosKey: Env.amapKey,
    ));
    AMapInitializer.updatePrivacyAgree(const AMapPrivacyStatement(
      hasContains: true,
      hasShow: true,
      hasAgree: true,
    ));

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
