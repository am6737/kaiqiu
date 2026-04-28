// event_detail_screen.dart — 赛事详情
//
// Tabs: teams · bracket · standings · scorers · chat · (manage for creator)
// Collapsible _EventInfoSection replaces OverviewPanel.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/map_launcher.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/typography.dart';

import 'panels/bracket_panel.dart';
import 'panels/chat_panel.dart';
import 'panels/manage_panel.dart';
import 'panels/scorers_panel.dart';
import 'panels/standings_panel.dart';
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
  String? _tab;

  String _defaultTab(Event event) {
    return switch (event.status) {
      EventStatus.draft || EventStatus.registering => 'teams',
      EventStatus.scheduling || EventStatus.ongoing => 'bracket',
      EventStatus.completed => 'standings',
      _ => 'teams',
    };
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
    final isCreator =
        event.creatorId != null && event.creatorId == currentUserId;
    final tab = _tab ?? _defaultTab(event);
    final showCta = !isCreator;
    final ctaVisible = showCta &&
        (event.status == EventStatus.registering ||
         event.status == EventStatus.ongoing);

    final tabs = <(String, String)>[
      ('teams', l.event_tab_teams),
      ('bracket', l.event_tab_bracket),
      ('standings', l.event_tab_standings),
      ('scorers', l.event_tab_scorers),
      ('chat', l.event_tab_chat),
      if (isCreator) ('manage', l.event_tab_manage),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final bottomPad = tab == 'chat'
            ? 166.0
            : (ctaVisible ? 110.0 : 24.0);

        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventHeader(
                    event: event,
                    onBack: () => context.pop(),
                  ),
                  _EventInfoSection(event: event),
                  KpiStrip(
                    eventId: event.id,
                    prizeCents: event.prizeCents,
                    teamsMax: event.teamsMax,
                  ),
                  _Tabs(
                    current: tab,
                    tabs: tabs,
                    onChange: (v) => setState(() => _tab = v),
                  ),
                  switch (tab) {
                    'teams' => TeamsPanel(
                        eventId: event.id,
                        teamsMax: event.teamsMax,
                      ),
                    'bracket' => BracketPanel(eventId: event.id),
                    'standings' => StandingsPanel(eventId: event.id),
                    'scorers' => ScorersPanel(eventId: event.id),
                    'chat' => ChatPanel(eventId: event.id),
                    'manage' => ManagePanel(event: event),
                    _ => TeamsPanel(
                        eventId: event.id,
                        teamsMax: event.teamsMax,
                      ),
                  },
                ],
              ),
            ),
            if (tab == 'chat')
              Positioned(
                bottom: 96,
                left: 0,
                right: 0,
                child: ChatInput(eventId: event.id),
              ),
            if (showCta)
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

// ─────────────────────────────────────────────────────────────
// Collapsible event info section
// ─────────────────────────────────────────────────────────────
class _EventInfoSection extends ConsumerStatefulWidget {
  final Event event;
  const _EventInfoSection({required this.event});

  @override
  ConsumerState<_EventInfoSection> createState() => _EventInfoSectionState();
}

class _EventInfoSectionState extends ConsumerState<_EventInfoSection> {
  bool _expanded = false;

  Event get event => widget.event;

  bool get _canNavigate => event.lat != null && event.lng != null;

  String get _locationText {
    final parts = <String>[];
    if (event.sub != null && event.sub!.isNotEmpty) parts.add(event.sub!);
    if (event.address != null &&
        event.address!.trim().isNotEmpty &&
        event.address != event.sub) {
      parts.add(event.address!);
    }
    return parts.join(' · ');
  }

  void _openNav() {
    if (!_canNavigate) return;
    MapLauncher.openNavigation(
      context: context,
      lat: event.lat!,
      lng: event.lng!,
      name: event.sub ?? (event.address ?? ''),
    );
  }

  Widget _buildOrganizer(BuildContext context) {
    final l = context.l10n;
    final creatorAsync = event.creatorId != null
        ? ref.watch(profileByIdProvider(event.creatorId!))
        : null;

    return GestureDetector(
      onTap: event.creatorId != null
          ? () => context.push('/user/${event.creatorId!}')
          : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Row(
          children: [
            if (creatorAsync != null)
              creatorAsync.when(
                data: (p) => NetworkAvatar(
                  p?.name ?? '?',
                  url: p?.avatarUrl,
                  size: 36,
                  square: true,
                ),
                loading: () => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.tokens.elev3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                error: (_, _) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.tokens.elev3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              )
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creatorAsync?.valueOrNull?.name ?? '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.ink,
                    ),
                  ),
                  Label(l.event_overview_organizer_label),
                ],
              ),
            ),
            if (event.creatorId != null)
              Icon(Icons.chevron_right, size: 18, color: context.tokens.inkMute),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(
          bottom: BorderSide(color: context.tokens.line, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — always visible
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _expanded ? l.event_info_section : event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: context.tokens.inkSub,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    '${event.name}。',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.tokens.ink,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rules
                  Label(l.event_overview_rules),
                  const SizedBox(height: 10),
                  for (final r in [
                    l.event_overview_rule_format,
                    l.event_overview_rule_halves,
                    l.event_overview_rule_subs,
                    l.event_overview_rule_cards,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.tokens.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.tokens.inkSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Venue
                  if (event.sub != null && event.sub!.isNotEmpty) ...[
                    Label(l.event_overview_venue),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.tokens.elev2,
                        border: Border.all(color: context.tokens.line),
                        borderRadius:
                            BorderRadius.circular(context.tokens.r2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.near_me,
                            size: 14,
                            color: context.tokens.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.tokens.inkSub,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed:
                                _canNavigate ? () => _openNav() : null,
                            style: TextButton.styleFrom(
                              foregroundColor: context.tokens.accent,
                              disabledForegroundColor: context.tokens.inkMute,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            child: Text(l.pickup_detail_navigate),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Organizer
                  Label(l.event_overview_organizer),
                  const SizedBox(height: 10),
                  _buildOrganizer(context),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scrollable tab bar
// ─────────────────────────────────────────────────────────────
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
        border: Border(
            bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            for (final t in tabs)
              GestureDetector(
                onTap: () => onChange(t.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: current == t.$1
                            ? context.tokens.accent
                            : Colors.transparent,
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
                      color: current == t.$1
                          ? context.tokens.ink
                          : context.tokens.inkSub,
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
