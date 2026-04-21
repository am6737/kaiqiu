// notifications_screen.dart — 通知中心
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../theme/tokens.dart';
import '../../utils/time_fmt.dart';
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;
  final Set<String> _read = {};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _demoItems(l);
    final list = _unreadOnly
        ? items.where((n) => !_read.contains(n.id)).toList()
        : items;

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.notif_title,
              onBack: () => context.pop(),
              actions: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _read.addAll(items.map((i) => i.id))),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Label(l.notif_mark_all_read),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: T.elev2,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Tab(
                        label: l.notif_all,
                        active: !_unreadOnly,
                        onTap: () => setState(() => _unreadOnly = false),
                      ),
                    ),
                    Expanded(
                      child: _Tab(
                        label: l.notif_unread,
                        active: _unreadOnly,
                        onTap: () => setState(() => _unreadOnly = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? _Empty(label: l.empty_no_notifications)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        for (final group in _grouped(list).entries) ...[
                          SectionHeader(title: _groupLabel(group.key)),
                          for (final n in group.value)
                            _NotifRow(
                              item: n,
                              read: _read.contains(n.id),
                              onTap: () {
                                setState(() => _read.add(n.id));
                                if (n.route != null) context.push(n.route!);
                              },
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
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
        route: '/rate/demo',
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

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? T.elev3 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? T.ink : T.inkSub,
          ),
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final _Notif item;
  final bool read;
  final VoidCallback onTap;
  const _NotifRow({
    required this.item,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: T.line, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: T.elev3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: T.line),
              ),
              child: Icon(item.icon, size: 18, color: T.live),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: read ? T.inkSub : T.ink,
                          ),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: T.live,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: T.inkSub,
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
          Text(label, style: const TextStyle(color: T.inkSub, fontSize: 13)),
        ],
      ),
    );
  }
}
