// my_pickups_screen.dart — 我的球局 (组织/参与)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/pickup.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';

class MyPickupsScreen extends ConsumerStatefulWidget {
  const MyPickupsScreen({super.key});

  @override
  ConsumerState<MyPickupsScreen> createState() => _MyPickupsScreenState();
}

class _MyPickupsScreenState extends ConsumerState<MyPickupsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.me_pickups_title,
              onBack: () => context.pop(),
              actions: [
                GestureDetector(
                  onTap: () => context.push('/pickup/create'),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add, color: T.live),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabBtn(
                        label: l.me_pickups_tab_hosted,
                        active: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabBtn(
                        label: l.me_pickups_tab_joined,
                        active: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _tab == 0 ? _HostedView() : _JoinedView()),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? context.tokens.elev3 : Colors.transparent,
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

class _HostedView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myHostedPickupsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.sports_soccer,
            title: l.empty_no_pickups,
            subtitle: l.empty_no_pickups_sub,
          );
        }
        return _PickupList(items: list);
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _JoinedView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myJoinedPickupsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.sports_soccer,
            title: l.empty_no_pickups,
            subtitle: l.empty_no_pickups_sub,
          );
        }
        return _PickupList(items: list);
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _PickupList extends StatelessWidget {
  final List<Pickup> items;
  const _PickupList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [for (final p in items) _Row(p: p)],
    );
  }
}

class _Row extends StatelessWidget {
  final Pickup p;
  const _Row({required this.p});

  @override
  Widget build(BuildContext context) {
    final state = switch (p.status) {
      PickupStatus.full => 'full',
      PickupStatus.almost => 'almost',
      _ => 'open',
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/pickup/${p.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SportIcon(Sport.football, size: 20, color: T.inkSub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: T.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      N(p.displayTime, size: 11, color: T.inkSub),
                      const SizedBox(width: 10),
                      if (p.level != null) Label(p.level!),
                      const SizedBox(width: 10),
                      N(
                        '¥${p.feeYuan.toStringAsFixed(0)}',
                        size: 11,
                        color: T.inkSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            StatusDot(state: state, size: 7),
          ],
        ),
      ),
    );
  }
}
