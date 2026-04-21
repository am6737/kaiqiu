// wc_live_screen.dart — 世界杯直播（真实 HLS 流 + 弹幕）
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/live_predict_strip.dart';
import '../../widgets/live_stream_player.dart';
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
        if (r.nextInt(60) == 0) {
          if (r.nextBool()) {
            _scoreA++;
          } else {
            _scoreB++;
          }
        }
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
    final scoreOverlay = l.wc_live_score_overlay(
      'ARG',
      '$_scoreA',
      '$_scoreB',
      'BRA',
      '$_minute',
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            LiveStreamPlayer(
              height: 240,
              scoreOverlay: scoreOverlay,
              topLeft: _BackButton(onTap: () => context.pop()),
              topRight: _ReminderButton(
                hasReminder: hasReminder,
                label: l.wc_btn_remind,
                onTap: () async {
                  final repo = ref.read(remindersRepoProvider);
                  if (LocalStore.hasReminder(widget.matchId)) {
                    await repo.cancel(widget.matchId);
                  } else {
                    await repo.schedule(
                      matchId: widget.matchId,
                      remindAt: DateTime.now().add(const Duration(hours: 1)),
                    );
                  }
                  if (!context.mounted) return;
                  showToast(
                    context,
                    LocalStore.hasReminder(widget.matchId)
                        ? l.wc_remind_set
                        : l.wc_remind_unset,
                    success: true,
                  );
                  setState(() {});
                },
              ),
              bottomLeftOverlay: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LivePill(),
                  const SizedBox(width: 6),
                  Label('$_minute\'', color: Colors.white),
                ],
              ),
              bottomRightOverlay: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_red_eye,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.85),
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
            // Score bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: context.tokens.elev1,
                border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
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
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '-',
                          style: TextStyle(color: context.tokens.inkDim, fontSize: 16),
                        ),
                      ),
                      N(
                        '$_scoreB',
                        size: 32,
                        weight: FontWeight.w800,
                        color: context.tokens.ink,
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
            // Prediction strip — tap to open bottom sheet.
            LivePredictStrip(
              matchId: widget.matchId,
              homeLabel: l.wc_team_argentina,
              awayLabel: l.wc_team_brazil,
            ),
            // Danmu feed
            Expanded(
              child: Container(
                color: context.tokens.bg,
                child: _danmus.isEmpty
                    ? Center(
                        child: Text(
                          l.wc_live_comment_ph,
                          style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
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
                                    color: d.self ? T.liveDim : context.tokens.elev2,
                                    border: Border.all(
                                      color: d.self ? T.live : context.tokens.line,
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
                                            color: d.self ? T.live : context.tokens.inkSub,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: d.text,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.tokens.ink,
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
              decoration: BoxDecoration(
                color: context.tokens.elev1,
                border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.tokens.elev2,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _inputC,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(color: context.tokens.ink, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: l.wc_live_input_hint,
                          hintStyle: TextStyle(
                            color: context.tokens.inkDim,
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
                      decoration: BoxDecoration(
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

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Color(0x80000000),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ReminderButton extends StatelessWidget {
  final bool hasReminder;
  final String label;
  final VoidCallback onTap;
  const _ReminderButton({
    required this.hasReminder,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x80000000),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasReminder ? Icons.notifications_active : Icons.notifications_none,
              size: 14,
              color: hasReminder ? T.live : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
        style: TextStyle(
          fontFamily: T.fontMono,
          fontFamilyFallback: T.monoFallbacks,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: context.tokens.ink,
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
          style: TextStyle(
            fontSize: 13,
            color: context.tokens.ink,
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
