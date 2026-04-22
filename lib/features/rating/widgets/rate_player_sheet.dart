// rate_player_sheet.dart — 底部抽屉：对某位球员打分
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/pickup.dart';
import '../../../widgets/avatar.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class PlayerMatchStats {
  final int goals;
  final int assists;
  const PlayerMatchStats({this.goals = 0, this.assists = 0});
}

class RatePlayerSheet extends StatefulWidget {
  final PickupSlot slot;
  final PlayerMatchStats stats;
  final double? initialScore;
  final String? initialComment;
  final String nextButtonLabel;
  final void Function(double score, String comment) onSave;

  const RatePlayerSheet({
    super.key,
    required this.slot,
    required this.stats,
    required this.initialScore,
    required this.initialComment,
    required this.nextButtonLabel,
    required this.onSave,
  });

  @override
  State<RatePlayerSheet> createState() => _RatePlayerSheetState();
}

class _RatePlayerSheetState extends State<RatePlayerSheet> {
  late double _score;
  late final TextEditingController _commentCtrl;
  bool _emojiOpen = false;
  final _commentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _score = widget.initialScore ?? 7.0;
    _commentCtrl = TextEditingController(text: widget.initialComment ?? '');
  }

  @override
  void dispose() {
    _commentFocus.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Color _colorFor(double v) {
    if (v >= 8) return context.tokens.accent;
    if (v >= 6) return context.tokens.ink;
    if (v >= 4) return context.tokens.warn;
    return context.tokens.danger;
  }

  String _levelLabel(BuildContext ctx, double v) {
    if (v >= 8) return ctx.l10n.rate_level_god;
    if (v >= 6) return ctx.l10n.rate_level_good;
    if (v >= 4) return ctx.l10n.rate_level_meh;
    return ctx.l10n.rate_level_bad;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final slot = widget.slot;
    final displayName =
        slot.displayName ?? (slot.userId != null ? slot.userId! : '—');
    final scoreColor = _colorFor(_score);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.elev1,
          border: Border(top: BorderSide(color: context.tokens.line)),
          borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.r4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: context.tokens.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // head row
              Row(
                children: [
                  Avatar(displayName, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Label(
                          slot.userId == null
                              ? '${slot.position} · ${l.rate_pitch_not_registered}'
                              : slot.position,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // stats row (goals / assists / position)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Row(
                  children: [
                    _StatCell(
                      label: l.rate_pitch_goals_label,
                      value: widget.stats.goals.toString(),
                    ),
                    _Divider(),
                    _StatCell(
                      label: l.rate_pitch_assists_label,
                      value: widget.stats.assists.toString(),
                    ),
                    _Divider(),
                    _StatCell(
                      label: l.rate_pitch_pos_label,
                      value: slot.position,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // score label + number
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Label(_levelLabel(context, _score), color: scoreColor),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      N(
                        _score.toStringAsFixed(1),
                        size: 36,
                        weight: FontWeight.w800,
                        color: scoreColor,
                      ),
                      const SizedBox(width: 2),
                      N('/10', size: 12, color: context.tokens.inkDim),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // slider
              _Slider(value: _score, onChanged: (v) => setState(() => _score = v)),
              const SizedBox(height: 16),
              // comment
              TextField(
                controller: _commentCtrl,
                focusNode: _commentFocus,
                onTap: () {
                  if (_emojiOpen) setState(() => _emojiOpen = false);
                },
                minLines: 2,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 13,
                  color: context.tokens.ink,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: l.rate_other_hint,
                  hintStyle: TextStyle(color: context.tokens.inkDim),
                  filled: true,
                  fillColor: context.tokens.elev3,
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      if (_emojiOpen) {
                        setState(() => _emojiOpen = false);
                        _commentFocus.requestFocus();
                      } else {
                        _commentFocus.unfocus();
                        setState(() => _emojiOpen = true);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _emojiOpen
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        size: 22,
                        color: context.tokens.inkSub,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.accent),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // action
              PrimaryButton(
                label: widget.nextButtonLabel,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: () => widget.onSave(_score, _commentCtrl.text),
              ),
              if (_emojiOpen) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: EmojiPicker(
                    textEditingController: _commentCtrl,
                    onEmojiSelected: (_, _) {},
                    config: Config(
                      height: 220,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        columns: 8,
                        emojiSizeMax: 28 *
                            (defaultTargetPlatform == TargetPlatform.iOS
                                ? 1.2
                                : 1.0),
                        backgroundColor: context.tokens.elev1,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        indicatorColor: context.tokens.accent,
                        iconColorSelected: context.tokens.accent,
                        iconColor: context.tokens.inkDim,
                        backgroundColor: context.tokens.elev1,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        enabled: false,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: context.tokens.elev1,
                        buttonIconColor: context.tokens.inkSub,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          N(value, size: 18, weight: FontWeight.w800),
          const SizedBox(height: 2),
          Label(label),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: context.tokens.line);
  }
}

class _Slider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _Slider({required this.value, required this.onChanged});

  Color _colorFor(BuildContext context, double v) {
    if (v >= 8) return context.tokens.accent;
    if (v >= 6) return context.tokens.ink;
    if (v >= 4) return context.tokens.warn;
    return context.tokens.danger;
  }

  void _update(double x, double width) {
    final frac = (x / width).clamp(0.0, 1.0);
    final v = (frac * 20).round() / 2;
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context, value);
    return LayoutBuilder(
      builder: (_, c) {
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition.dx, c.maxWidth),
          onPanUpdate: (d) => _update(d.localPosition.dx, c.maxWidth),
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (value / 10) * c.maxWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0x4DFF3B6B),
                          Color(0x4DFF6B35),
                          Color(0x1F00FF85),
                          Color(0x1F00FF85),
                        ],
                        stops: [0, 0.4, 0.75, 1],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int n = 0; n <= 10; n++)
                          Text(
                            '$n',
                            style: TextStyle(
                              fontFamily: context.tokens.fontMono,
                              fontFamilyFallback: context.tokens.monoFallbacks,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: n <= value ? context.tokens.ink : context.tokens.inkDim,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: (value / 10) * c.maxWidth - 14,
                  top: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
