// notif_settings_screen.dart — 通知与消息设置
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';

class NotifSettingsScreen extends ConsumerWidget {
  const NotifSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.settings_notif_title,
              onBack: () => context.pop(),
            ),
            _switchRow(
              title: l.settings_notif_push,
              sub: l.settings_notif_push_sub,
              value: LocalStore.notifPush,
              onChanged: LocalStore.setNotifPush,
            ),
            _switchRow(
              title: l.settings_notif_inapp,
              sub: l.settings_notif_inapp_sub,
              value: LocalStore.notifInApp,
              onChanged: LocalStore.setNotifInApp,
            ),
            _switchRow(
              title: l.settings_notif_email,
              sub: l.settings_notif_email_sub,
              value: LocalStore.notifEmail,
              onChanged: LocalStore.setNotifEmail,
            ),
            _switchRow(
              title: l.settings_notif_match_reminder,
              sub: l.settings_notif_match_reminder_sub,
              value: LocalStore.notifMatchReminder,
              onChanged: LocalStore.setNotifMatchReminder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String sub,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.elev2,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: T.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: T.inkSub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: T.live,
            onChanged: (v) async => await onChanged(v),
          ),
        ],
      ),
    );
  }
}
