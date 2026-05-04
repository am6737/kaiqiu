import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

class MatchControlScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String matchId;
  const MatchControlScreen({
    super.key,
    required this.eventId,
    required this.matchId,
  });

  @override
  ConsumerState<MatchControlScreen> createState() =>
      _MatchControlScreenState();
}

class _MatchControlScreenState extends ConsumerState<MatchControlScreen> {
  int _scoreA = 0;
  int _scoreB = 0;
  int _minute = 0;
  bool _synced = false;
  bool _busy = false;

  void _syncFromMatch(Match match) {
    if (!_synced) {
      _scoreA = match.scoreA ?? 0;
      _scoreB = match.scoreB ?? 0;
      _minute = match.minute ?? 0;
      _synced = true;
    }
  }

  Future<void> _pushScore() async {
    try {
      await ref.read(eventsRepoProvider).updateMatchScore(
            widget.matchId,
            scoreA: _scoreA,
            scoreB: _scoreB,
            minute: _minute,
          );
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _endMatch() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.live_room_end),
        content: Text(l.live_room_end_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.common_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(eventsRepoProvider)
          .endMatch(widget.matchId, _scoreA, _scoreB);

      if (mounted) {
        ref.invalidate(eventMatchesProvider(widget.eventId));
        final matches =
            await ref.read(eventsRepoProvider).matchesFor(widget.eventId);
        final allDone =
            matches.every((m) => m.done || m.id == widget.matchId);
        if (allDone && mounted) {
          final completeEvent = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.event_complete),
              content: Text(l.event_all_matches_done),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.common_cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.common_confirm),
                ),
              ],
            ),
          );
          if (completeEvent == true) {
            await ref.read(eventsRepoProvider).updateEventStatus(
                  widget.eventId,
                  EventStatus.completed,
                );
            ref.invalidate(eventDetailProvider(widget.eventId));
          }
        }
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final matchAsync = ref.watch(matchRealtimeProvider(widget.matchId));

    return Scaffold(
      backgroundColor: t.bg,
      body: matchAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: t.danger)),
        ),
        data: (match) {
          _syncFromMatch(match);
          return _Body(
            match: match,
            scoreA: _scoreA,
            scoreB: _scoreB,
            minute: _minute,
            busy: _busy,
            onScoreA: (delta) {
              final next = _scoreA + delta;
              if (next < 0) return;
              setState(() => _scoreA = next);
              _pushScore();
            },
            onScoreB: (delta) {
              final next = _scoreB + delta;
              if (next < 0) return;
              setState(() => _scoreB = next);
              _pushScore();
            },
            onMinute: (delta) {
              final next = _minute + delta;
              if (next < 0) return;
              setState(() => _minute = next);
              _pushScore();
            },
            onStartLive: () => context.push(
              '/event/${widget.eventId}/match/${widget.matchId}/live',
            ),
            onEndMatch: _endMatch,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Match match;
  final int scoreA;
  final int scoreB;
  final int minute;
  final bool busy;
  final ValueChanged<int> onScoreA;
  final ValueChanged<int> onScoreB;
  final ValueChanged<int> onMinute;
  final VoidCallback onStartLive;
  final VoidCallback onEndMatch;

  const _Body({
    required this.match,
    required this.scoreA,
    required this.scoreB,
    required this.minute,
    required this.busy,
    required this.onScoreA,
    required this.onScoreB,
    required this.onMinute,
    required this.onStartLive,
    required this.onEndMatch,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Column(
      children: [
        _Header(
          match: match,
          scoreA: scoreA,
          scoreB: scoreB,
          minute: minute,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              children: [
                _ScoreSection(
                  teamALabel: match.teamALabel ?? 'A',
                  teamBLabel: match.teamBLabel ?? 'B',
                  scoreA: scoreA,
                  scoreB: scoreB,
                  onScoreA: onScoreA,
                  onScoreB: onScoreB,
                ),
                const SizedBox(height: 28),
                _MinuteSection(minute: minute, onMinute: onMinute),
                const SizedBox(height: 36),
                PrimaryButton(
                  full: true,
                  size: BtnSize.lg,
                  variant: BtnVariant.secondary,
                  onPressed: onStartLive,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 18, color: t.accent),
                      const SizedBox(width: 8),
                      Text(l.match_control_start_live),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: l.match_control_end_match,
                  full: true,
                  size: BtnSize.lg,
                  variant: BtnVariant.warn,
                  disabled: busy,
                  onPressed: onEndMatch,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Match match;
  final int scoreA;
  final int scoreB;
  final int minute;

  const _Header({
    required this.match,
    required this.scoreA,
    required this.scoreB,
    required this.minute,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: Color(0xCCFFFFFF)),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l.match_control_title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: Color(0xFFEF4444)),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      match.teamALabel ?? 'A',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$scoreA',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: Color(0x80FFFFFF),
                            ),
                          ),
                        ),
                        Text(
                          '$scoreB',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.teamBLabel ?? 'B',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$minute'",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF22C55E),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ScoreSection extends StatelessWidget {
  final String teamALabel;
  final String teamBLabel;
  final int scoreA;
  final int scoreB;
  final ValueChanged<int> onScoreA;
  final ValueChanged<int> onScoreB;

  const _ScoreSection({
    required this.teamALabel,
    required this.teamBLabel,
    required this.scoreA,
    required this.scoreB,
    required this.onScoreA,
    required this.onScoreB,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l.match_control_score,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.inkSub,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TeamScoreCard(
                label: teamALabel,
                score: scoreA,
                onIncrement: () => onScoreA(1),
                onDecrement: scoreA > 0 ? () => onScoreA(-1) : null,
                color: t.accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _TeamScoreCard(
                label: teamBLabel,
                score: scoreB,
                onIncrement: () => onScoreB(1),
                onDecrement: scoreB > 0 ? () => onScoreB(-1) : null,
                color: t.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamScoreCard extends StatelessWidget {
  final String label;
  final int score;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;
  final Color color;

  const _TeamScoreCard({
    required this.label,
    required this.score,
    required this.onIncrement,
    this.onDecrement,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.inkSub,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    size: 32, color: onDecrement != null ? t.ink : t.inkDim),
                onPressed: onDecrement,
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.add_circle, size: 32, color: color),
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinuteSection extends StatelessWidget {
  final int minute;
  final ValueChanged<int> onMinute;

  const _MinuteSection({required this.minute, required this.onMinute});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l.match_control_minute,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.inkSub,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: t.elev1,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    size: 28, color: minute > 0 ? t.ink : t.inkDim),
                onPressed: minute > 0 ? () => onMinute(-1) : null,
              ),
              const SizedBox(width: 16),
              Text(
                "$minute'",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: t.ink,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.add_circle, size: 28, color: t.accent),
                onPressed: () => onMinute(1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
