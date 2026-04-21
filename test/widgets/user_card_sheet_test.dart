import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/models/profile.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/user_card_sheet.dart';

class _SlowMessagesRepo extends MessagesRepository {
  final completer = Completer<String>();
  int callCount = 0;

  @override
  Future<String> ensureDmWith(String otherUserId) {
    callCount++;
    return completer.future;
  }
}

class _FakeMessagesRepo extends MessagesRepository {
  String? calledWithUserId;
  String nextConvId = 'conv-123';

  @override
  Future<String> ensureDmWith(String otherUserId) async {
    calledWithUserId = otherUserId;
    return nextConvId;
  }
}

Profile _sampleProfile({
  String id = 'u-other',
  String name = 'Bob',
  String? handle = 'bobbb',
  String? position = 'CF',
  String? city = 'Beijing',
}) => Profile(
      id: id,
      name: name,
      handle: handle,
      city: city,
      position: position,
      createdAt: DateTime(2026, 1, 1),
    );

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

void main() {
  // NOTE: Test case for "self-detection" (userId == currentUserId) is not
  // unit-tested here because currentUserId is a top-level getter that reads
  // from a live Supabase session, which cannot be overridden in widget tests
  // without injecting an auth mock. Rely on manual testing for that path.

  group('showUserCardSheet', () {
    testWidgets('renders name, handle, position · city', (tester) async {
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => Center(
            child: Consumer(
              builder: (c, ref, _) {
                return ElevatedButton(
                  onPressed: () => showUserCardSheet(c, ref, userId: 'u-other'),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
        overrides: [
          profileByIdProvider('u-other').overrideWith((ref) async => _sampleProfile()),
        ],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('bobbb'), findsOneWidget);
      expect(find.textContaining('CF'), findsOneWidget);
      expect(find.text('发起私聊'), findsOneWidget);
    });

    testWidgets('tapping Start DM calls ensureDmWith', (tester) async {
      final repo = _FakeMessagesRepo();
      await tester.pumpWidget(_wrap(
        Builder(
          builder: (ctx) => Center(
            child: Consumer(
              builder: (c, ref, _) {
                return ElevatedButton(
                  onPressed: () => showUserCardSheet(c, ref, userId: 'u-other'),
                  child: const Text('open'),
                );
              },
            ),
          ),
        ),
        overrides: [
          profileByIdProvider('u-other').overrideWith((ref) async => _sampleProfile()),
          messagesRepoProvider.overrideWithValue(repo),
        ],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('发起私聊'));
      await tester.pumpAndSettle();

      expect(repo.calledWithUserId, 'u-other');
    });

    testWidgets('button disabled while ensureDmWith pending', (tester) async {
      final repo = _SlowMessagesRepo();
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) => Center(
          child: Consumer(builder: (c, ref, _) => ElevatedButton(
            onPressed: () => showUserCardSheet(c, ref, userId: 'u-other'),
            child: const Text('open'),
          )),
        )),
        overrides: [
          profileByIdProvider('u-other').overrideWith((ref) async => _sampleProfile()),
          messagesRepoProvider.overrideWithValue(repo),
        ],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // First tap kicks off ensureDmWith (still pending)
      await tester.tap(find.text('发起私聊'));
      await tester.pump(); // let setState take effect, but don't settle
      expect(repo.callCount, 1);

      // Second tap should NOT invoke the repo again while _busy
      await tester.tap(find.text('发起私聊'));
      await tester.pump();
      expect(repo.callCount, 1);

      // Let the pending future complete to clean up (avoid pending timers warnings).
      repo.completer.complete('conv-done');
      await tester.pumpAndSettle();
    });
  });
}
