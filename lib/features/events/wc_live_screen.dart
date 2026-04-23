// wc_live_screen.dart — 世界杯直播（真实 HLS 流 + 弹幕）
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/external_match.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../utils/toast.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/live_predict_strip.dart';
import '../../widgets/live_stream_player.dart';
import '../../widgets/team_badge.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/rich_input.dart';

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
  final StreamController<DanmakuItem> _danmuController =
      StreamController<DanmakuItem>.broadcast();
  bool _danmakuOn = LocalStore.danmakuEnabled;
  int _scoreA = 0;
  int _scoreB = 0;
  String _minute = '';
  int _viewers = 0;
  String _teamA = '';
  String _teamB = '';
  String? _flagA;
  String? _flagB;

  @override
  void initState() {
    super.initState();
    _loadMatch();
    _tickTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadMatch();
    });
  }

  Future<void> _loadMatch() async {
    try {
      final row = await supabase
          .from('external_matches')
          .select()
          .eq('id', widget.matchId)
          .maybeSingle();
      if (row == null || !mounted) return;
      final m = ExternalMatch.fromMap(row);
      setState(() {
        _scoreA = m.scoreA ?? 0;
        _scoreB = m.scoreB ?? 0;
        _minute = m.minute ?? '';
        _viewers = m.viewers;
        _teamA = m.teamA;
        _teamB = m.teamB;
        _flagA = m.flagA;
        _flagB = m.flagB;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    _inputC.dispose();
    _danmuController.close();
    super.dispose();
  }

  void _pushDanmu(_Danmu d) {
    setState(() {
      _danmus.insert(0, d);
      if (_danmus.length > 40) _danmus.removeLast();
    });
    _danmuController.add(
      DanmakuItem(user: d.user, text: d.text, self: d.self),
    );
  }

  void _send() {
    final t = _inputC.text.trim();
    if (t.isEmpty) return;
    _pushDanmu(_Danmu(user: 'You', text: t, at: DateTime.now(), self: true));
    _inputC.clear();
  }

  Future<void> _showReminderSheet(BuildContext ctx) async {
    final l = ctx.l10n;
    final repo = ref.read(remindersRepoProvider);
    final matchId = widget.matchId;
    final picked = await showModalBottomSheet<int>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReminderSheet(
        hasReminder: LocalStore.hasReminder(matchId),
      ),
    );
    if (picked == null) return;
    if (!ctx.mounted) return;
    if (picked == 0) {
      await repo.cancel(matchId);
      if (!ctx.mounted) return;
      showToast(ctx, l.wc_remind_unset, success: true);
    } else {
      await repo.schedule(
        matchId: matchId,
        remindAt: DateTime.now().add(Duration(minutes: picked)),
      );
      if (!ctx.mounted) return;
      showToast(ctx, l.wc_remind_set_n_min(picked), success: true);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final viewerStr = _viewers > 1000
        ? '${(_viewers / 1000).toStringAsFixed(1)}K'
        : '$_viewers';
    final hasReminder = LocalStore.hasReminder(widget.matchId);
    final scoreOverlay = l.wc_live_score_overlay(
      _teamA.isNotEmpty ? _teamA : '—',
      '$_scoreA',
      '$_scoreB',
      _teamB.isNotEmpty ? _teamB : '—',
      _minute,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  LiveStreamPlayer(
                    height: 240,
                    scoreOverlay: scoreOverlay,
                    danmakuStream: _danmuController.stream,
                    danmakuEnabled: _danmakuOn,
                    topLeft: _BackButton(onTap: () => context.pop()),
                    topRight: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DanmakuToggleButton(
                          on: _danmakuOn,
                          label: _danmakuOn
                              ? l.wc_btn_danmaku_on
                              : l.wc_btn_danmaku_off,
                          onTap: () async {
                            final next = !_danmakuOn;
                            setState(() => _danmakuOn = next);
                            await LocalStore.setDanmakuEnabled(next);
                          },
                        ),
                        const SizedBox(width: 8),
                        _ReminderButton(
                          hasReminder: hasReminder,
                          label: l.wc_btn_remind,
                          onTap: () => _showReminderSheet(context),
                        ),
                      ],
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
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DanmakuOverlay(
                        stream: _danmuController.stream,
                        enabled: _danmakuOn,
                      ),
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
                    child: Row(
                      children: [
                        if (_teamA.isNotEmpty || _flagA != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TeamBadge(
                              name: _teamA.isNotEmpty ? _teamA : '?',
                              logoUrl: _flagA,
                              size: 36,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            _teamA.isNotEmpty ? _teamA : '—',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.tokens.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      N(
                        '$_scoreA',
                        size: 32,
                        weight: FontWeight.w800,
                        color: context.tokens.accent,
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
                        color: context.tokens.accent,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            _teamB.isNotEmpty ? _teamB : '—',
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.tokens.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_teamB.isNotEmpty || _flagB != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: TeamBadge(
                              name: _teamB.isNotEmpty ? _teamB : '?',
                              logoUrl: _flagB,
                              size: 36,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Prediction strip — tap to open bottom sheet.
            LivePredictStrip(
              matchId: widget.matchId,
              homeLabel: _teamA,
              awayLabel: _teamB,
              homeFlagUrl: _flagA,
              awayFlagUrl: _flagB,
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
                                    color: d.self ? context.tokens.accentSubtle : context.tokens.elev2,
                                    border: Border.all(
                                      color: d.self ? context.tokens.accent : context.tokens.line,
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
                                            color: d.self ? context.tokens.accent : context.tokens.inkSub,
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
            RichInput(
              controller: _inputC,
              onSend: _send,
              hintText: l.wc_live_input_hint,
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
              color: hasReminder ? context.tokens.accent : Colors.white,
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

class _DanmakuToggleButton extends StatelessWidget {
  final bool on;
  final String label;
  final VoidCallback onTap;
  const _DanmakuToggleButton({
    required this.on,
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
              on ? Icons.subtitles : Icons.subtitles_off,
              size: 14,
              color: on ? context.tokens.accent : Colors.white,
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

/// Bottom sheet that lets the user pick a pre-match reminder offset.
/// Pops with the chosen offset in minutes, `0` to cancel, or `null` on dismiss.
class _ReminderSheet extends StatelessWidget {
  final bool hasReminder;
  const _ReminderSheet({required this.hasReminder});

  static const _options = <int>[5, 10, 15, 30, 60];
  static const _defaultMinutes = 10;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.tokens.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.wc_remind_sheet_title,
            style: TextStyle(
              color: context.tokens.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.wc_remind_sheet_sub,
            style: TextStyle(
              color: context.tokens.inkDim,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          for (final m in _options)
            _ReminderOption(
              label: m >= 60
                  ? l.wc_remind_option_hour(m ~/ 60)
                  : l.wc_remind_option_min(m),
              isDefault: m == _defaultMinutes,
              onTap: () => Navigator.of(context).pop(m),
            ),
          if (hasReminder) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l.wc_remind_cancel,
                  style: TextStyle(
                    color: context.tokens.inkSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderOption extends StatelessWidget {
  final String label;
  final bool isDefault;
  final VoidCallback onTap;
  const _ReminderOption({
    required this.label,
    required this.isDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDefault
                ? context.tokens.accentSubtle
                : context.tokens.elev2,
            border: Border.all(
              color: isDefault ? context.tokens.accent : context.tokens.line,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 18,
                color: isDefault
                    ? context.tokens.accent
                    : context.tokens.inkSub,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.tokens.ink,
                    fontSize: 14,
                    fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.tokens.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l.wc_remind_default_badge,
                    style: TextStyle(
                      color: context.tokens.accentInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
