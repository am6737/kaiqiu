import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kaiqiu_app/features/messages/new_dm_sheet.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/models/profile.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/repositories/profiles_repository.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/primary_button.dart';

// NOTE: Test case c (self-DM guard) is not covered here because `currentUserId`
// is a top-level getter that reads from a live Supabase session. In tests
// Supabase is not initialized, so the try/catch in _submit() defaults `myId`
// to null, meaning `profile.id == myId` is always false — the self-DM branch
// is unreachable in widget tests. Rely on manual testing for that path.

class _FakeProfilesRepo extends ProfilesRepository {
  final Profile? returnValue;
  String? calledWithHandle;

  _FakeProfilesRepo({this.returnValue});

  @override
  Future<Profile?> fetchByHandle(String handle) async {
    calledWithHandle = handle;
    return returnValue;
  }
}

class _FakeMessagesRepo extends MessagesRepository {
  String? calledWithUserId;
  String nextConvId = 'conv-dm-456';

  @override
  Future<String> ensureDmWith(String otherUserId) async {
    calledWithUserId = otherUserId;
    return nextConvId;
  }
}

Profile _sampleProfile({
  String id = 'u-bob',
  String name = 'Bob',
  String? handle = 'bob',
}) => Profile(
      id: id,
      name: name,
      handle: handle,
      createdAt: DateTime(2026, 1, 1),
    );

/// Basic wrapper without GoRouter — suitable for error-path tests where
/// navigation never happens.
Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  // ignore: invalid_use_of_visible_for_testing_member
  final ctrl = ThemeController.test();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ctrl.lightTheme,
      darkTheme: ctrl.darkTheme,
      locale: const Locale('zh'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

/// Wrapper with a minimal GoRouter so that `GoRouter.of(context)` succeeds
/// inside the sheet. Needed for success-path tests that reach navigation.
Widget _wrapWithRouter(
  Widget Function(BuildContext ctx, WidgetRef ref) builder, {
  List<Override> overrides = const [],
}) {
  // ignore: invalid_use_of_visible_for_testing_member
  final ctrl = ThemeController.test();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Consumer(
            builder: (c, ref, _) => Center(child: builder(c, ref)),
          ),
        ),
      ),
      // Catch-all for /chat/:id so the push doesn't 404
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ctrl.lightTheme,
      darkTheme: ctrl.darkTheme,
      locale: const Locale('zh'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  group('showNewDmSheet', () {
    testWidgets(
      'a) handle normalization + failed lookup → shows 用户不存在',
      (tester) async {
        final profilesRepo = _FakeProfilesRepo(returnValue: null);

        await tester.pumpWidget(_wrap(
          Builder(
            builder: (ctx) => Center(
              child: Consumer(
                builder: (c, ref, _) => ElevatedButton(
                  onPressed: () => showNewDmSheet(c, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          overrides: [
            profilesRepoProvider.overrideWithValue(profilesRepo),
          ],
        ));

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Type handle with @ prefix and mixed case
        await tester.enterText(find.byType(TextField), '@BoB');
        // Tap the PrimaryButton specifically (title text is also '发起私聊')
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();

        // Should have been called with normalized handle: 'bob'
        expect(profilesRepo.calledWithHandle, 'bob');

        // Since repo returned null, should show '用户不存在'
        expect(find.text('用户不存在'), findsOneWidget);
      },
    );

    testWidgets(
      'b) success path → sheet closed and ensureDmWith called with profile id',
      (tester) async {
        final profile = _sampleProfile(id: 'u-bob', handle: 'bob');
        final profilesRepo = _FakeProfilesRepo(returnValue: profile);
        final messagesRepo = _FakeMessagesRepo();

        await tester.pumpWidget(_wrapWithRouter(
          (c, ref) => ElevatedButton(
            onPressed: () => showNewDmSheet(c, ref),
            child: const Text('open'),
          ),
          overrides: [
            profilesRepoProvider.overrideWithValue(profilesRepo),
            messagesRepoProvider.overrideWithValue(messagesRepo),
          ],
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // TextField should be visible now (sheet is open)
        expect(find.byType(TextField), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'bob');
        // Tap the PrimaryButton specifically (title text is also '发起私聊')
        await tester.tap(find.byType(PrimaryButton));
        await tester.pumpAndSettle();

        // Sheet should be dismissed (TextField gone)
        expect(find.byType(TextField), findsNothing);

        // ensureDmWith should have been called with correct user id
        expect(messagesRepo.calledWithUserId, 'u-bob');
      },
    );
  });
}
