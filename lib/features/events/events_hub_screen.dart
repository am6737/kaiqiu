// events_hub_screen.dart — 赛事中心
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock.dart' show WcMatch;
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/photo_halftone.dart';
import '../../widgets/typography.dart';

class EventsHubScreen extends ConsumerStatefulWidget {
  const EventsHubScreen({super.key});

  @override
  ConsumerState<EventsHubScreen> createState() => _EventsHubScreenState();
}

class _EventsHubScreenState extends ConsumerState<EventsHubScreen> {
  String _tab = 'registering';
  static const _tabs = [
    ('ongoing', '进行中'),
    ('registering', '报名中'),
    ('watch', '观看'),
  ];

  @override
  Widget build(BuildContext context) {
    final wcMatches = ref.watch(wcMatchesProvider);
    final statusForTab = switch (_tab) {
      'ongoing' => EventStatus.ongoing,
      'registering' => EventStatus.registering,
      _ => null,
    };

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  const Text('赛事',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: T.ink,
                          letterSpacing: -0.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/create-event'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: T.liveDim,
                        border: Border.all(color: const Color(0x6600FF85)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add, size: 13, color: T.live),
                          SizedBox(width: 5),
                          Text('创建赛事',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: T.live)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // World Cup banner
            _WcBanner(onTap: () => context.push('/worldcup')),
            // Tabs
            Padding(
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
                    for (final t in _tabs)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = t.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tab == t.$1 ? T.elev3 : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _tab == t.$1 ? T.ink : T.inkSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_tab == 'watch')
              ..._buildWatchTab(wcMatches)
            else
              ..._buildEventsList(statusForTab!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventsList(EventStatus status) {
    final async = ref.watch(liveEventsProvider(status));
    return async.when(
      data: (list) {
        if (list.isEmpty) return const [_EmptyEvents()];
        return [
          for (final e in list)
            _LiveEventRow(
              event: e,
              onTap: () => context.push('/event/${e.id}'),
            ),
        ];
      },
      loading: () => const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: T.live)),
        ),
      ],
      error: (err, _) => [
        _EventsError(
          error: err,
          onRetry: () => ref.invalidate(liveEventsProvider(status)),
        ),
      ],
    );
  }

  List<Widget> _buildWatchTab(List<WcMatch> matches) {
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Label('今日赛程 · 你关注的'),
      ),
      for (final m in matches)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: T.elev2,
            border: Border.all(color: T.line),
            borderRadius: BorderRadius.circular(T.r3),
          ),
          child: Row(
            children: [
              Expanded(child: _TeamRow(name: m.teamA, flag: m.flagA, hue: 25)),
              if (m.live)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        N('${m.scoreA}', size: 18, weight: FontWeight.w700),
                        const Text(' - ',
                            style: TextStyle(color: T.inkDim)),
                        N('${m.scoreB}', size: 18, weight: FontWeight.w700),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const LivePill(),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    N(m.time,
                        size: 13, weight: FontWeight.w600),
                    if (m.status != null) Label(m.status!),
                  ],
                ),
              Expanded(
                child: _TeamRow(
                  name: m.teamB, flag: m.flagB, hue: 200, rightAlign: true,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _WcBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _WcBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HSLColor.fromAHSL(1, 260, 0.5, 0.22).toColor(),
                HSLColor.fromAHSL(1, 290, 0.5, 0.16).toColor(),
              ],
            ),
            borderRadius: BorderRadius.circular(T.r3),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  LivePill(),
                  SizedBox(width: 6),
                  Label('职业赛事', color: T.ink),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '2026 FIFA 世界杯专区',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: T.ink,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text('小组赛第 2 轮 · 今晚 5 场同步直播',
                  style: TextStyle(fontSize: 13, color: T.inkSub)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Label('正在直播'),
                      SizedBox(height: 2),
                      N('3', size: 20, weight: FontWeight.w700, color: T.live),
                    ],
                  ),
                  Container(
                      width: 1, height: 28, color: T.line,
                      margin: const EdgeInsets.symmetric(horizontal: 14)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Label('同城竞猜'),
                      SizedBox(height: 2),
                      N('2.4K', size: 20, weight: FontWeight.w700),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward, size: 20, color: T.ink),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveEventRow extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _LiveEventRow({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isReg = event.status == EventStatus.registering;
    final teamsMax = event.teamsMax ?? 16;
    // Placeholder progress until teams table is wired (Session D).
    final teams = (event.id.hashCode.abs() % (teamsMax + 1));
    final progress = teamsMax > 0 ? teams / teamsMax : 0.0;
    final prizeLabel = event.prizeCents != null
        ? '奖金 ¥${(event.prizeCents! / 1000000).toStringAsFixed(1)}万'
        : '奖金待定';
    final deadlineLabel = event.deadline != null
        ? '${event.deadline!.month.toString().padLeft(2, '0')}-${event.deadline!.day.toString().padLeft(2, '0')} 截止'
        : '—';
    final subtitle = [
      if (event.sub?.isNotEmpty ?? false) event.sub!,
      if (event.city?.isNotEmpty ?? false) event.city!,
    ].join(' · ');
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    return GestureDetector(
      onTap: onTap,
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
              child: Stack(
                children: [
                  PhotoHalftone(
                    label: event.name,
                    height: 110,
                    hue: hue,
                    variant: HalftoneVariant.lines,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isReg
                            ? T.liveDim
                            : const Color(0x80000000),
                        border: Border.all(color: isReg ? T.live : T.line),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Label(isReg ? '报名中' : '进行中',
                          color: isReg ? T.live : T.ink),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x80000000),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 11, color: T.warn),
                          const SizedBox(width: 4),
                          N(prizeLabel,
                              size: 11,
                              weight: FontWeight.w600,
                              color: T.ink),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(subtitle.isEmpty ? '—' : subtitle,
                      style: const TextStyle(fontSize: 12, color: T.inkSub)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Label('报名队伍'),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              N('$teams',
                                  size: 16, weight: FontWeight.w700),
                              N('/$teamsMax',
                                  size: 12, color: T.inkDim),
                            ],
                          ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: T.elev3,
                              valueColor: AlwaysStoppedAnimation(
                                  isReg ? T.live : T.inkSub),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Label('状态'),
                          const SizedBox(height: 2),
                          N(deadlineLabel,
                              size: 11,
                              weight: FontWeight.w600,
                              color: isReg ? T.warn : T.inkSub),
                        ],
                      ),
                    ],
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

class _TeamRow extends StatelessWidget {
  final String name, flag;
  final double hue;
  final bool rightAlign;
  const _TeamRow({
    required this.name,
    required this.flag,
    required this.hue,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisAlignment:
          rightAlign ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!rightAlign) _flag(),
        if (!rightAlign) const SizedBox(width: 8),
        Text(name,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: T.ink)),
        if (rightAlign) const SizedBox(width: 8),
        if (rightAlign) _flag(),
      ],
    );
    return row;
  }

  Widget _flag() => Container(
        width: 28,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HSLColor.fromAHSL(1, hue, 0.4, 0.28).toColor(),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(flag,
            style: const TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: T.ink)),
      );
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 30),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r3),
        ),
        child: Column(
          children: const [
            Icon(Icons.inbox_outlined, size: 32, color: T.inkDim),
            SizedBox(height: 10),
            Text('暂无赛事',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: T.ink)),
            SizedBox(height: 4),
            Label('点右上角 创建赛事 发起一个'),
          ],
        ),
      ),
    );
  }
}

class _EventsError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _EventsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Label('加载失败', color: T.danger),
            const SizedBox(height: 6),
            Text('$error',
                style: const TextStyle(fontSize: 12, color: T.inkSub)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: T.elev3,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('重试',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: T.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
