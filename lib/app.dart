// app.dart — root MaterialApp
import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'routes.dart';
import 'theme/theme.dart';

class KaiqiuApp extends StatelessWidget {
  const KaiqiuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (_, _) {
        return MaterialApp.router(
          onGenerateTitle: (ctx) => AppL10n.of(ctx).app_name,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          routerConfig: router,
          locale: LocaleController.instance.current,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
        );
      },
    );
  }
}
