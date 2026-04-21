// notifications_screen.dart — 薄壳：仅为了让旧 /notifications 路由在 Task 6
// 改为 redirect 前仍然编译。Task 9 将删除。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import 'notifications_tab.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _tabKey = GlobalKey<NotificationsTabState>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.notif_title,
              onBack: () => context.pop(),
              actions: [
                GestureDetector(
                  onTap: () => _tabKey.currentState?.markAllRead(),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Label(l.notif_mark_all_read),
                  ),
                ),
              ],
            ),
            Expanded(child: NotificationsTab(key: _tabKey)),
          ],
        ),
      ),
    );
  }
}
