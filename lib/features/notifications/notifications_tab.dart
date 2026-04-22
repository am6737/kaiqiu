// notifications_tab.dart — 嵌入 InboxScreen 的通知列表（无 Scaffold / 无 PageTitleBar）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/notification_item.dart';
import '../../providers.dart';
import '../../utils/time_fmt.dart';
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

const _branchRoots = {'/home', '/pickup', '/events', '/me'};

class NotificationsTab extends ConsumerStatefulWidget {
  const NotificationsTab({super.key});

  @override
  ConsumerState<NotificationsTab> createState() => NotificationsTabState();
}

class NotificationsTabState extends ConsumerState<NotificationsTab> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final notifsAsync = ref.watch(notificationsProvider);

    return notifsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Empty(label: l.empty_no_notifications),
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            color: context.tokens.accent,
            backgroundColor: context.tokens.elev1,
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(notificationsUnreadProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_Empty(label: l.empty_no_notifications)],
            ),
          );
        }
        return RefreshIndicator(
          color: context.tokens.accent,
          backgroundColor: context.tokens.elev1,
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            ref.invalidate(notificationsUnreadProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final group in _grouped(items).entries) ...[
                SectionHeader(title: _groupLabel(group.key)),
                for (final n in group.value)
                  _NotifRow(
                    item: n,
                    onTap: () {
                      if (!n.read) {
                        ref.read(notificationsRepoProvider).markRead(n.id);
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(notificationsUnreadProvider);
                      }
                      final route = n.route;
                      if (route == null) return;
                      if (route == '/messages') {
                        context.go('/inbox?tab=messages');
                        return;
                      }
                      if (_branchRoots.contains(route)) {
                        context.go(route);
                      } else {
                        context.push(route);
                      }
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Map<String, List<NotificationItem>> _grouped(List<NotificationItem> items) {
    final m = <String, List<NotificationItem>>{};
    for (final n in items) {
      m.putIfAbsent(n.group, () => []).add(n);
    }
    return m;
  }

  String _groupLabel(String key) {
    final l = context.l10n;
    return switch (key) {
      'system' => l.notif_group_system,
      'match' => l.notif_group_match,
      'pickup' => l.notif_group_pickup,
      'rating' => l.notif_group_rating,
      _ => key,
    };
  }
}

IconData _iconForType(String type) => switch (type) {
  'system' => Icons.info_outline,
  'rating' => Icons.star_outline,
  'pickup' => Icons.sports_soccer,
  'match' => Icons.emoji_events,
  'follow' => Icons.person_add_alt,
  _ => Icons.notifications_outlined,
};

class _NotifRow extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotifRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: item.read ? null : context.tokens.accentSubtle.withAlpha(0x18),
          border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.tokens.line),
              ),
              child: Icon(
                _iconForType(item.type),
                size: 18,
                color: context.tokens.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.inkSub,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Label(formatRelative(item.createdAt, context: context)),
                ],
              ),
            ),
            if (!item.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: context.tokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Avatar('📭', size: 40),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: context.tokens.inkSub, fontSize: 13)),
        ],
      ),
    );
  }
}
