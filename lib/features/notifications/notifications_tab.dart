// notifications_tab.dart — 嵌入 InboxScreen 的通知列表（无 Scaffold / 无 PageTitleBar）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../utils/time_fmt.dart';
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

// Shell-branch roots (after inbox merge, /messages is gone).
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
    final items = _demoItems(l);

    return items.isEmpty
        ? _Empty(label: l.empty_no_notifications)
        : ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final group in _grouped(items).entries) ...[
                SectionHeader(title: _groupLabel(group.key)),
                for (final n in group.value)
                  _NotifRow(
                    item: n,
                    onTap: () {
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
          );
  }

  Map<String, List<_Notif>> _grouped(List<_Notif> items) {
    final m = <String, List<_Notif>>{};
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
      _ => '',
    };
  }

  List<_Notif> _demoItems(AppL10n l) {
    final now = DateTime.now();
    return [
      _Notif(
        id: 'welcome',
        group: 'system',
        icon: Icons.celebration,
        title: l.notif_demo_welcome_t,
        body: l.notif_demo_welcome_b,
        at: now.subtract(const Duration(seconds: 10)),
        route: '/me',
      ),
      _Notif(
        id: 'rate-1',
        group: 'rating',
        icon: Icons.star_outline,
        title: l.notif_demo_rate_t,
        body: l.notif_demo_rate_b,
        at: now.subtract(const Duration(minutes: 20)),
        route: '/rate/$demoMatchId',
      ),
      _Notif(
        id: 'pickup-1',
        group: 'pickup',
        icon: Icons.sports_soccer,
        title: l.notif_demo_pickup_t,
        body: l.notif_demo_pickup_b,
        at: now.subtract(const Duration(hours: 1)),
        route: '/pickup',
      ),
      _Notif(
        id: 'event-1',
        group: 'match',
        icon: Icons.emoji_events,
        title: l.notif_demo_event_t,
        body: l.notif_demo_event_b,
        at: now.subtract(const Duration(hours: 3)),
        route: '/events',
      ),
      _Notif(
        id: 'follow-1',
        group: 'system',
        icon: Icons.person_add_alt,
        title: l.notif_demo_follow_t,
        body: l.notif_demo_follow_b,
        at: now.subtract(const Duration(days: 1)),
        route: '/me',
      ),
    ];
  }
}

class _Notif {
  final String id, group, title, body;
  final DateTime at;
  final IconData icon;
  final String? route;
  const _Notif({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    required this.body,
    required this.at,
    this.route,
  });
}

class _NotifRow extends StatelessWidget {
  final _Notif item;
  final VoidCallback onTap;
  const _NotifRow({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
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
              child: Icon(item.icon, size: 18, color: context.tokens.accent),
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
                      fontWeight: FontWeight.w700,
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
                  Label(formatRelative(item.at, context: context)),
                ],
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
