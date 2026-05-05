// wc_live_screen.dart — 直播观赛页（赛事 LiveKit 流 / 世界杯 HLS 流 + 弹幕）
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

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
  bool _isEventMatch = false;

  // LiveKit for event matches (viewer-only, no camera/mic).
  Room? _lkRoom;
  EventsListener<RoomEvent>? _lkListener;
  bool _lkConnecting = false;

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
    // Try matches table first (event match with LiveKit stream).
    try {
      final mRow = await supabase
          .from('matches')
          .select('id, event_id, team_a_label, team_b_label, score_a, score_b, minute, viewers')
          .eq('id', widget.matchId)
          .maybeSingle();
      if (mRow != null && mounted) {
        final minute = mRow['minute'];
        setState(() {
          _isEventMatch = true;
          _teamA = (mRow['team_a_label'] as String?) ?? '';
          _teamB = (mRow['team_b_label'] as String?) ?? '';
          _scoreA = (mRow['score_a'] as int?) ?? 0;
          _scoreB = (mRow['score_b'] as int?) ?? 0;
          _minute = minute != null ? "$minute'" : '';
          _viewers = (mRow['viewers'] as int?) ?? 0;
        });
        _connectLiveKit();
        return;
      }
    } catch (_) {}

    // Fallback: external_matches table (World Cup HLS stream).
    try {
      final row = await supabase
          .from('external_matches')
          .select()
          .eq('id', widget.matchId)
          .maybeSingle();
      if (row == null || !mounted) return;
      final m = ExternalMatch.fromMap(row);
      setState(() {
        _isEventMatch = false;
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

  Future<void> _connectLiveKit() async {
    if (_lkRoom != null || _lkConnecting) return;
    _lkConnecting = true;
    try {
      final tokenData =
          await ref.read(livekitTokenProvider(widget.matchId).future);
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      _lkListener = room.createListener();
      _lkListener!
        ..on<TrackSubscribedEvent>((_) { if (mounted) setState(() {}); })
        ..on<TrackUnsubscribedEvent>((_) { if (mounted) setState(() {}); })
        ..on<ParticipantConnectedEvent>((_) { if (mounted) setState(() {}); })
        ..on<ParticipantDisconnectedEvent>((_) { if (mounted) setState(() {}); });
      await room.connect(tokenData.wsUrl, tokenData.token);
      if (!mounted) { await room.disconnect(); return; }
      setState(() {
        _lkRoom = room;
        _lkConnecting = false;
        _viewers = room.remoteParticipants.length + 1;
      });
    } catch (_) {
      if (mounted) setState(() => _lkConnecting = false);
    }
  }

  @override
  void dispose() {
    _tickTimer.cancel();
    _inputC.dispose();
    _danmuController.close();
    _lkListener?.dispose();
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
                  // Video source: LiveKit for event matches, HLS for WC.
                  if (_isEventMatch)
                    _LiveKitVideoArea(
                      room: _lkRoom,
                      connecting: _lkConnecting,
                    )
                  else
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
                          Icon(Icons.remove_red_eye, size: 14,
                              color: Colors.white.withValues(alpha: 0.85)),
                          const SizedBox(width: 4),
                          Text(l.wc_live_viewer_count(viewerStr),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  // Shared overlays for event matches.
                  if (_isEventMatch) ...[
                    // Dim scrim.
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x66000000),
                                Color(0x00000000),
                                Color(0x66000000),
                              ],
                              stops: [0, 0.45, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Scoreboard chip.
                    Positioned(
                      top: 44,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _ScoreboardChip(text: scoreOverlay),
                      ),
                    ),
                    // Top-left back.
                    Positioned(
                      top: 40,
                      left: 12,
                      child: _BackButton(onTap: () => context.pop()),
                    ),
                    // Top-right controls.
                    Positioned(
                      top: 40,
                      right: 12,
                      child: Row(
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
                    ),
                    // Bottom-left LIVE + minute.
                    Positioned(
                      bottom: 10,
                      left: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LivePill(),
                          const SizedBox(width: 6),
                          Label('$_minute\'', color: Colors.white),
                        ],
                      ),
                    ),
                    // Bottom-right viewers.
                    Positioned(
                      bottom: 10,
                      right: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.remove_red_eye, size: 14,
                              color: Colors.white.withValues(alpha: 0.85)),
                          const SizedBox(width: 4),
                          Text(l.wc_live_viewer_count(viewerStr),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  // Danmaku overlay (both match types).
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

// ── LiveKit video area for event matches ──
class _LiveKitVideoArea extends StatelessWidget {
  final Room? room;
  final bool connecting;
  const _LiveKitVideoArea({required this.room, required this.connecting});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E1712), Color(0xFF050808)],
        ),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (connecting || room == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 10),
            Text('Connecting…',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      );
    }

    VideoTrack? bestTrack;
    for (final p in room!.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        if (pub.track != null && !pub.muted) {
          bestTrack = pub.track as VideoTrack;
          break;
        }
      }
      if (bestTrack != null) break;
    }

    if (bestTrack != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: 640,
          height: 360,
          child: VideoTrackRenderer(bestTrack),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off, color: Colors.white38, size: 40),
          SizedBox(height: 8),
          Text('Waiting for stream…',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Scoreboard chip (copied from live_stream_player.dart) ──
class _ScoreboardChip extends StatelessWidget {
  final String text;
  const _ScoreboardChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.tokens.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: context.tokens.accent, blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: context.tokens.fontMono,
              fontFamilyFallback: context.tokens.monoFallbacks,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
