// pitch_view.dart — 俯视球场（单队 4-3-3），球员点击触发回调
import 'package:flutter/material.dart';

import '../../../models/pickup.dart';
import '../../../theme/tokens.dart';
import '../../../theme/app_tokens.dart';

class PitchView extends StatelessWidget {
  final List<PickupSlot> slots;
  final String? currentUserId;
  final String? selectedSlotId;
  final Map<String, double> ratedScores;
  final void Function(PickupSlot slot) onTap;

  const PitchView({
    super.key,
    required this.slots,
    required this.currentUserId,
    required this.selectedSlotId,
    required this.ratedScores,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HSLColor.fromAHSL(1, 150, 0.25, 0.20).toColor(),
                HSLColor.fromAHSL(1, 150, 0.25, 0.16).toColor(),
              ],
            ),
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(T.r3),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
              for (final s in slots) _positionedDot(s, w, h),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedDot(PickupSlot s, double w, double h) {
    final dotW = 40.0;
    final dotH = 52.0;
    final isSelf = s.userId != null && s.userId == currentUserId;
    final isSelected = s.id == selectedSlotId;
    final rated = ratedScores[s.id];

    return Positioned(
      left: (s.x / 100) * w - dotW / 2,
      top: (s.y / 100) * h - dotH / 2,
      width: dotW,
      height: dotH,
      child: _PlayerDot(
        slot: s,
        isSelf: isSelf,
        isSelected: isSelected,
        rated: rated,
        onTap: () => onTap(s),
      ),
    );
  }
}

class _PlayerDot extends StatelessWidget {
  final PickupSlot slot;
  final bool isSelf;
  final bool isSelected;
  final double? rated;
  final VoidCallback onTap;

  const _PlayerDot({
    required this.slot,
    required this.isSelf,
    required this.isSelected,
    required this.rated,
    required this.onTap,
  });

  Color _ratedColor(BuildContext context, double v) {
    if (v >= 8) return context.tokens.accent;
    if (v >= 6) return context.tokens.ink;
    if (v >= 4) return context.tokens.warn;
    return context.tokens.danger;
  }

  @override
  Widget build(BuildContext context) {
    final label = slot.initial(isSelf ? slot.userId : null);
    final dotColor = rated != null
        ? _ratedColor(context, rated!)
        : (isSelected ? context.tokens.ink : context.tokens.elev1);
    final dotFg = rated != null || isSelected ? Colors.black : context.tokens.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Self halo
              if (isSelf)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.tokens.accent, width: 2),
                  ),
                ),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? context.tokens.ink : context.tokens.line,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: T.fontMono,
                    fontFamilyFallback: T.monoFallbacks,
                    fontSize: label.runes.length > 1 ? 9 : 11,
                    fontWeight: FontWeight.w700,
                    color: dotFg,
                  ),
                ),
              ),
              // Rated score badge (above the dot)
              if (rated != null)
                Positioned(
                  top: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _ratedColor(context, rated!),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Text(
                      rated!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontFamily: T.fontMono,
                        fontFamilyFallback: T.monoFallbacks,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0x80000000),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              slot.position,
              style: TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: isSelf ? context.tokens.accent : context.tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      stroke,
    );
    canvas.drawLine(
      Offset(1, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      stroke,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 30, stroke);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = const Color(0x4DFFFFFF),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, 1, size.width * 0.4, size.height * 0.14),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.3,
        size.height * 0.85,
        size.width * 0.4,
        size.height * 0.14,
      ),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.4, 1, size.width * 0.2, size.height * 0.06),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.4,
        size.height * 0.93,
        size.width * 0.2,
        size.height * 0.06,
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => false;
}
