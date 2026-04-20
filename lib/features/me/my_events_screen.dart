// my_events_screen.dart — 我的赛事 (报名/组织/已完赛)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/photo_halftone.dart';
import '../../widgets/section_header.dart';

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(title: l.me_events_title, onBack: () => context.pop()),
            _Tabs(
              current: _tab,
              tabs: [
                l.me_events_tab_registered,
                l.me_events_tab_hosted,
                l.me_events_tab_done,
              ],
              onChange: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: switch (_tab) {
                0 => _RegisteredView(),
                1 => _HostedView(),
                _ => _DoneView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int current;
  final List<String> tabs;
  final ValueChanged<int> onChange;
  const _Tabs({
    required this.current,
    required this.tabs,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: Row(
          children: [
            for (int i = 0; i < tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChange(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: current == i ? T.elev3 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: current == i ? T.ink : T.inkSub,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RegisteredView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myFavoriteEventsProvider);
    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.event_available,
            title: l.empty_no_events,
            subtitle: l.empty_no_events_sub,
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [for (final e in list) _EventCard(event: e)],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _HostedView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myHostedEventsProvider);
    return async.when(
      data: (list) {
        final open = list.where((e) => e.status != EventStatus.done).toList();
        if (open.isEmpty) {
          return EmptyState(
            icon: Icons.event_available,
            title: l.empty_no_events,
            subtitle: l.empty_no_events_sub,
            action: GestureDetector(
              onTap: () => context.push('/create-event'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: T.liveDim,
                  border: Border.all(color: const Color(0x6600FF85)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.events_create,
                  style: const TextStyle(
                    color: T.live,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [for (final e in open) _EventCard(event: e)],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _DoneView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(myHostedEventsProvider);
    return async.when(
      data: (list) {
        final done = list.where((e) => e.status == EventStatus.done).toList();
        if (done.isEmpty) {
          return EmptyState(icon: Icons.history, title: l.empty_no_events);
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [for (final e in done) _EventCard(event: e)],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: T.live)),
      error: (e, _) => Center(child: Text('${l.error_load_failed}: $e')),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(T.r3),
                topRight: Radius.circular(T.r3),
              ),
              child: PhotoHalftone(
                label: event.name,
                height: 90,
                hue: hue,
                variant: HalftoneVariant.lines,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: T.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (event.sub?.isNotEmpty ?? false) event.sub!,
                      if (event.city?.isNotEmpty ?? false) event.city!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: T.inkSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
