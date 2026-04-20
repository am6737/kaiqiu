// wc_live_screen.dart — 世界杯直播（占位 player + 弹幕）
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/typography.dart';

class WcLiveScreen extends ConsumerStatefulWidget {
  final String matchId;
  const WcLiveScreen({super.key, required this.matchId});

  @override
  ConsumerState<WcLiveScreen> createState() => _WcLiveScreenState();
}

class _WcLiveScreenState extends ConsumerState<WcLiveScreen> {
  final _inputC = TextEditingController();
  final _danmus = <_Danmu>[];
  late Timer _tickTimer;
  int _scoreA = 1;
  int _scoreB = 1;
  int _minute = 67;
  late int _viewers;

  static const _botMessages = [
    '狼队今天状态拉满',
    '边路这一下太精彩了',
    '门将反应真快',
    '这个越位判得准',
    '进球进球进球！',
    '看直播真爽',
    '现场氛围不错',
    'FC 黑马防守端还得加强',
    '这个换人很关键',
    '下半场节奏更好了',
  ];

  static const _botNames = [
    '老王',
    '阿泽',
    'Kevin',
    '江北',
    '林帅',
    '路人甲',
    '小张',
    '老李',
    '球迷007',
  ];

  @override
  void initState() {
    super.initState();
    final r = Random(widget.matchId.hashCode);
    _viewers = 1200 + r.nextInt(128000);
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _viewers += r.nextInt(50) - 10;
        if (_viewers < 0) _viewers = 0;
        _minute = (_minute + 1).clamp(0, 90);
        // tiny chance to bump score
        if (r.nextInt(60) == 0) {
          if (r.nextBool()) {
            _scoreA++;
          } else {
            _scoreB++;
          }
        }
        // occasional bot danmu
        if (r.nextInt(3) == 0) {
          _danmus.insert(
            0,
            _Danmu(
              user: _botNames[r.nextInt(_botNames.length)],
              text: _botMessages[r.nextInt(_botMessages.length)],
              at: DateTime.now(),
              self: false,
            ),
          );
          if (_danmus.length > 40) _danmus.removeLast();
        }
      });
    });
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    _inputC.dispose();
    super.dispose();
  }

  void _send() {
    final t = _inputC.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _danmus.insert(
        0,
        _Danmu(user: 'You', text: t, at: DateTime.now(), self: true),
      );
    });
    _inputC.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final viewerStr = _viewers > 1000
        ? '${(_viewers / 1000).toStringAsFixed(1)}K'
        : '$_viewers';
    final hasReminder = LocalStore.hasReminder(widget.matchId);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Player area
            Stack(
              children: [
                Container(
                  height: 240,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0E1712), Color(0xFF050808)],
                    ),
                  ),
                  child: CustomPaint(
                    painter: _StreamPainter(_minute),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 56,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x80000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 12,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await LocalStore.toggleReminder(widget.matchId);
                          if (context.mounted) {
                            showToast(
                              context,
                              LocalStore.hasReminder(widget.matchId)
                                  ? l.wc_remind_set
                                  : l.wc_remind_unset,
                              success: true,
                            );
                          }
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x80000000),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasReminder
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                                size: 14,
                                color: hasReminder ? T.live : Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l.wc_btn_remind,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      const LivePill(),
                      const SizedBox(width: 6),
                      Label('$_minute\'', color: Colors.white),
                      const Spacer(),
                      Icon(
                        Icons.remove_red_eye,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.wc_live_viewer_count(viewerStr),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Score bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: const BoxDecoration(
                color: T.elev1,
                border: Border(bottom: BorderSide(color: T.line, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TeamBadge(
                      name: 'ARG',
                      label: l.wc_team_argentina,
                      hue: 200,
                      alignEnd: false,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      N(
                        '$_scoreA',
                        size: 32,
                        weight: FontWeight.w800,
                        color: T.live,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '-',
                          style: TextStyle(color: T.inkDim, fontSize: 16),
                        ),
                      ),
                      N(
                        '$_scoreB',
                        size: 32,
                        weight: FontWeight.w800,
                        color: T.ink,
                      ),
                    ],
                  ),
                  Expanded(
                    child: _TeamBadge(
                      name: 'BRA',
                      label: l.wc_team_brazil,
                      hue: 140,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
            // Danmu feed
            Expanded(
              child: Container(
                color: T.bg,
                child: _danmus.isEmpty
                    ? Center(
                        child: Text(
                          l.wc_live_comment_ph,
                          style: const TextStyle(color: T.inkDim, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        reverse: false,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        itemCount: _danmus.length,
                        itemBuilder: (_, i) {
                          final d = _danmus[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: d.self ? T.liveDim : T.elev2,
                                    border: Border.all(
                                      color: d.self ? T.live : T.line,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${d.user}: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: d.self ? T.live : T.inkSub,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: d.text,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: T.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
              decoration: const BoxDecoration(
                color: T.elev1,
                border: Border(top: BorderSide(color: T.line, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: T.elev2,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _inputC,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(color: T.ink, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: l.wc_live_input_hint,
                          hintStyle: const TextStyle(
                            color: T.inkDim,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: T.live,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        size: 16,
                        color: Colors.black,
                      ),
                    ),
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

class _TeamBadge extends StatelessWidget {
  final String name, label;
  final double hue;
  final bool alignEnd;
  const _TeamBadge({
    required this.name,
    required this.label,
    required this.hue,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final flag = Container(
      width: 40,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, hue, 0.4, 0.3).toColor(),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontFamily: T.fontMono,
          fontFamilyFallback: T.monoFallbacks,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: T.ink,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (!alignEnd) flag,
        if (!alignEnd) const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: T.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (alignEnd) const SizedBox(width: 8),
        if (alignEnd) flag,
      ],
    );
  }
}

class _Danmu {
  final String user, text;
  final DateTime at;
  final bool self;
  const _Danmu({
    required this.user,
    required this.text,
    required this.at,
    required this.self,
  });
}

class _StreamPainter extends CustomPainter {
  final int minute;
  _StreamPainter(this.minute);

  @override
  void paint(Canvas canvas, Size size) {
    // Faux pitch: center circle, halfway line
    final fg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawCircle(Offset(cx, cy), 36, fg);
    canvas.drawLine(Offset(cx, 10), Offset(cx, size.height - 10), fg);
    // Progress bar at bottom
    final bar = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final done = Paint()..color = T.live;
    final y = size.height - 30;
    canvas.drawRect(Rect.fromLTWH(24, y, size.width - 48, 3), bar);
    final pct = (minute / 90).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(24, y, (size.width - 48) * pct, 3), done);
  }

  @override
  bool shouldRepaint(covariant _StreamPainter old) => old.minute != minute;
}
