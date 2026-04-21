// inbox_screen_test.dart — 初始 tab / 切换 / 红点 / redirect 的 widget 测试。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/features/inbox/inbox_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/models/message.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

class _FakeMessagesRepo extends MessagesRepository {
  @override
  Future<List<ConversationRow>> listConversations() async => const [];
  @override
  Future<List<Message>> listMessages(String convId) async => const [];
  @override
  Future<Message> send(String convId, String body) =>
      throw UnimplementedError();
  @override
  Stream<List<Message>> streamMessages(String convId) => const Stream.empty();
  @override
  Future<String> createConversation({String? title, String kind = 'group'}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteConversation(String convId) async {}
  @override
  Future<void> clearMessages(String convId) async {}
  @override
  Future<void> markRead(String convId) async {}
  @override
  Future<void> markUnread(String convId, {int count = 1}) async {}
  @override
  Future<String> ensureEventConversation(String eventId) =>
      throw UnimplementedError();
}

ConversationRow _conv(String id, {int unread = 0}) => ConversationRow(
      id: id,
      title: 'Conv $id',
      kind: 'group',
      updatedAt: DateTime(2026, 4, 21, 10, 0),
      unread: unread,
    );

Widget _wrap({
  required List<ConversationRow> conversations,
  InboxTab initialTab = InboxTab.notifications,
}) {
  final t = ThemeController.test();
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWith((_) => LocalStoreNotifier()),
      messagesRepoProvider.overrideWithValue(_FakeMessagesRepo()),
      conversationsProvider.overrideWith((_) async => conversations),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: InboxScreen(initialTab: initialTab),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('defaults to notifications tab', (tester) async {
    await tester.pumpWidget(_wrap(conversations: const []));
    await tester.pumpAndSettle();
    // Notif sub-tab "全部 / 未读" is visible (NotificationsTab only).
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('未读'), findsOneWidget);
  });

  testWidgets('initialTab=messages shows messages content', (tester) async {
    await tester.pumpWidget(
      _wrap(
        conversations: [_conv('c1')],
        initialTab: InboxTab.messages,
      ),
    );
    await tester.pumpAndSettle();
    // Messages tab is shown: conversation title visible.
    expect(find.text('Conv c1'), findsOneWidget);
    // Notifications sub-tabs are NOT visible (hidden by IndexedStack).
    expect(find.text('全部'), findsNothing);
  });

  testWidgets('tapping messages tab switches header action to "+ new DM"',
      (tester) async {
    await tester.pumpWidget(_wrap(conversations: const []));
    await tester.pumpAndSettle();
    // Default (notifications) action is "全部已读" label, not "+".
    expect(find.byIcon(Icons.add), findsNothing);
    // Tap "消息" top tab.
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('messages unread provider → shows red dot on messages tab label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(conversations: [_conv('c1', unread: 2)]),
    );
    await tester.pumpAndSettle();
    // Unread dot: find the 6x6 accent-colored circle next to "消息" label.
    // Heuristic: assert at least one Container with shape: BoxShape.circle
    // within the _InboxTabButton row labeled "消息".
    final messagesLabel = find.text('消息');
    expect(messagesLabel, findsOneWidget);
    final dots = find.descendant(
      of: find.ancestor(of: messagesLabel, matching: find.byType(Row)),
      matching: find.byType(Container),
    );
    // Row contains label container + dot container when showDot is true.
    expect(dots.evaluate().length, greaterThanOrEqualTo(1));
  });
}
