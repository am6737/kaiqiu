import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primary_button.dart';

class MatchControlPanel extends ConsumerStatefulWidget {
  final String matchId;
  final String eventId;
  final int initialScoreA;
  final int initialScoreB;
  final int initialMinute;
  final VoidCallback onMatchEnded;

  const MatchControlPanel({
    super.key,
    required this.matchId,
    required this.eventId,
    required this.initialScoreA,
    required this.initialScoreB,
    required this.initialMinute,
    required this.onMatchEnded,
  });

  @override
  ConsumerState<MatchControlPanel> createState() => _MatchControlPanelState();
}

class _MatchControlPanelState extends ConsumerState<MatchControlPanel> {
  late int _scoreA;
  late int _scoreB;
  late int _minute;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scoreA = widget.initialScoreA;
    _scoreB = widget.initialScoreB;
    _minute = widget.initialMinute;
  }

  Future<void> _updateScore() async {
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepoProvider).updateMatchScore(
        widget.matchId,
        scoreA: _scoreA,
        scoreB: _scoreB,
        minute: _minute,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
        final matches = await ref.read(eventsRepoProvider).matchesFor(widget.eventId);
        final allDone = matches.every((m) => m.done || m.id == widget.matchId);
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

      if (mounted) widget.onMatchEnded();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.match_control_score,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreControl(
                label: 'A',
                score: _scoreA,
                onIncrement: () {
                  setState(() => _scoreA++);
                  _updateScore();
                },
                onDecrement: _scoreA > 0
                    ? () {
                        setState(() => _scoreA--);
                        _updateScore();
                      }
                    : null,
              ),
              Column(
                children: [
                  Text(
                    l.match_control_minute,
                    style: TextStyle(fontSize: 11, color: t.inkSub),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _minute > 0
                            ? () {
                                setState(() => _minute--);
                                _updateScore();
                              }
                            : null,
                      ),
                      Text(
                        "$_minute'",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          setState(() => _minute++);
                          _updateScore();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              _ScoreControl(
                label: 'B',
                score: _scoreB,
                onIncrement: () {
                  setState(() => _scoreB++);
                  _updateScore();
                },
                onDecrement: _scoreB > 0
                    ? () {
                        setState(() => _scoreB--);
                        _updateScore();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: l.match_control_end_match,
            full: true,
            size: BtnSize.lg,
            variant: BtnVariant.warn,
            disabled: _busy,
            onPressed: _endMatch,
          ),
        ],
      ),
    );
  }
}

class _ScoreControl extends StatelessWidget {
  final String label;
  final int score;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  const _ScoreControl({
    required this.label,
    required this.score,
    required this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: t.inkSub)),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 28),
              onPressed: onDecrement,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, size: 28),
              color: t.accent,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}
