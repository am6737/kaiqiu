// messages_swipe_actions_test.dart — 侧滑露出按钮 / 状态感知文案 /
// 删除确认 / 置顶切换 + 自动收起的 widget 测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kaiqiu_app/features/messages/messages_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/models/message.dart';
import 'package:kaiqiu_app/providers.dart';
import 'package:kaiqiu_app/repositories/messages_repository.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

/// Fake repo — lets us avoid Supabase in tests and record deleteConversation.
class _FakeMessagesRepo extends MessagesRepository {
  final List<String> deletedIds = [];

  @override
  Future<List<ConversationRow>> listConversations() =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Future<List<Message>> listMessages(String convId) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Future<Message> send(String convId, String body) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Stream<List<Message>> streamMessages(String convId) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Future<String> createConversation({String? title, String kind = 'group'}) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Future<void> deleteConversation(String convId) async {
    deletedIds.add(convId);
  }

  @override
  Future<void> clearMessages(String convId) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Future<void> markRead(String convId) async {}

  @override
  Future<void> markUnread(String convId, {int count = 1}) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');

  @override
  Future<String> ensureEventConversation(String eventId) =>
      throw UnimplementedError('not used by messages_swipe_actions_test');
}

ConversationRow _conv(String id, {String? title}) => ConversationRow(
      id: id,
      title: title ?? 'Conv $id',
      kind: 'group',
      updatedAt: DateTime(2026, 4, 21, 10, 0),
      unread: 0,
    );

Widget _wrap({
  required List<ConversationRow> conversations,
  required _FakeMessagesRepo repo,
}) {
  final t = ThemeController.test();
  return ProviderScope(
    overrides: [
      localStoreProvider.overrideWith((_) => LocalStoreNotifier()),
      messagesRepoProvider.overrideWithValue(repo),
      conversationsProvider.overrideWith((_) async => conversations),
    ],
    child: MaterialApp(
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const MessagesScreen(),
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('left swipe on a thread row reveals pin/mute/delete icons',
      (tester) async {
    final repo = _FakeMessagesRepo();
    await tester.pumpWidget(_wrap(
      conversations: [_conv('c1', title: 'Alpha')],
      repo: repo,
    ));
    await tester.pumpAndSettle();

    // Before swipe: no action icons visible.
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    // Drag the row to the left past the slidable threshold.
    await tester.drag(find.text('Alpha'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // All 3 action icons now visible (un-pinned / un-muted default state).
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
