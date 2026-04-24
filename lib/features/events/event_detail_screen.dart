// event_detail_screen.dart — 赛事详情 (5 tabs)
//
// 球员评分已移至比赛详情子页：/event/:eventId/match/:matchId/ratings
// 文件 match_ratings_screen.dart。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';

import 'panels/chat_panel.dart';
import 'panels/competition_panel.dart';
import 'panels/overview_panel.dart';
import 'panels/scorers_panel.dart';
import 'panels/teams_panel.dart';
import 'widgets/bottom_cta.dart';
import 'widgets/event_header.dart';
import 'widgets/kpi_strip.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  String _tab = 'competition';

  Future<void> _confirmCancelEvent(Event event) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_cancel),
        content: Text(l.event_cancel_confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(eventsRepoProvider).cancelEvent(event.id);
    ref.invalidate(eventDetailProvider(event.id));
    ref.invalidate(myHostedEventsProvider);
    if (mounted) {
      showToast(context, l.event_cancel_success, success: true);
      context.go('/events');
    }
  }

  void _showCreatorRegisterSheet(Event event) {
    final bottomCta = BottomCta(event: event);
    bottomCta.showRegisterSheet(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: async.when(
        data: (event) => _buildContent(event),
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        error: (e, _) => _buildError(e),
      ),
    );
  }

  Widget _buildError(Object e) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: context.tokens.danger),
            const SizedBox(height: 8),
            Text(
              '${l.error_load_failed}: $e',
              style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
            ),

            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(eventDetailProvider(widget.id)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.common_retry,
                  style: TextStyle(color: context.tokens.ink, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Event event) {
    final l = context.l10n;
    final tabs = [
      ('overview', l.event_tab_overview),
      ('teams', l.event_tab_teams),
      ('competition', l.event_tab_competition),
      ('scorers', l.event_tab_scorers),
      ('chat', l.event_tab_chat),
    ];
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Cover 240 + KpiStrip ~62 + Tabs ~47 = ~349 above; reserve 110 for CTA.
        final panelMinHeight = (constraints.maxHeight - 349 - 110)
            .clamp(0.0, double.infinity);
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: _tab == 'chat' ? 166 : 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventHeader(
                    event: event,
                    onBack: () => context.pop(),
                    isCreator: event.creatorId != null && event.creatorId == currentUserId,
                    onEdit: () => context.push('/event/${event.id}/edit'),
                    onCancel: () => _confirmCancelEvent(event),
                    onRegister: () => _showCreatorRegisterSheet(event),
                  ),
                  KpiStrip(
                    eventId: event.id,
                    prizeCents: event.prizeCents,
                    teamsMax: event.teamsMax,
                  ),
                  _Tabs(
                    current: _tab,
                    tabs: tabs,
                    onChange: (v) => setState(() => _tab = v),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: panelMinHeight),
                    child: switch (_tab) {
                      'overview' => OverviewPanel(event: event),
                      'teams' => TeamsPanel(
                        eventId: event.id,
                        isCreator: event.creatorId != null &&
                            event.creatorId == currentUserId,
                        reviewMode: event.reviewMode,
                        teamsMax: event.teamsMax,
                      ),
                      'competition' => CompetitionPanel(eventId: event.id),
                      'scorers' => ScorersPanel(eventId: event.id),
                      _ => ChatPanel(eventId: event.id),
                    },
                  ),
                ],
              ),
            ),
            if (_tab == 'chat')
              Positioned(
                bottom: 96,
                left: 0,
                right: 0,
                child: ChatInput(eventId: event.id),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BottomCta(event: event),
            ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  final String current;
  final List<(String, String)> tabs;
  final ValueChanged<String> onChange;

  const _Tabs({
    required this.current,
    required this.tabs,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (final t in tabs)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChange(t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: current == t.$1 ? context.tokens.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      t.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: current == t.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: current == t.$1 ? context.tokens.ink : context.tokens.inkSub,
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
