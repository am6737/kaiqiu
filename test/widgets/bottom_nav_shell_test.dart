// bottom_nav_shell_test.dart — 底部导航应为 4 个 tab（home/pickup/events/me）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/bottom_nav_shell.dart';

Widget _shellWith4Branches() {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => BottomNavShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const _Stub('H')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pickup', builder: (_, _) => const _Stub('P')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/events', builder: (_, _) => const _Stub('E')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/me', builder: (_, _) => const _Stub('M')),
          ]),
        ],
      ),
    ],
  );
  final t = ThemeController.test();
  return ProviderScope(
    child: MaterialApp.router(
      locale: const Locale('zh'),
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(label)));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('renders exactly 4 bottom tabs', (tester) async {
    await tester.pumpWidget(_shellWith4Branches());
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('约球'), findsOneWidget);
    expect(find.text('赛事'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('消息'), findsNothing);
  });

  testWidgets('tapping a tab switches branch', (tester) async {
    await tester.pumpWidget(_shellWith4Branches());
    await tester.pumpAndSettle();

    expect(find.text('H'), findsOneWidget);
    await tester.tap(find.text('赛事'));
    await tester.pumpAndSettle();
    expect(find.text('E'), findsOneWidget);
  });
}
