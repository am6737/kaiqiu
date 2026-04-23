// bracket_mini_painter.dart — mini bracket diagram for template selection
import 'package:flutter/material.dart';

class BracketMiniPainter extends CustomPainter {
  final String variant;
  final bool active;
  final Color inkSub;
  final Color inkMute;
  final Color accent;
  BracketMiniPainter(this.variant, this.active, {required this.inkSub, required this.inkMute, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = active ? accent : inkSub;
    final cDim = active ? accent : inkMute;
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale);

    final stroke = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final dim = Paint()..color = cDim;
    final dimStroke = Paint()
      ..color = cDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;

    if (variant == 'group8') {
      for (final y in [6.0, 14.0]) {
        canvas.drawRect(Rect.fromLTWH(4, y, 16, 6), stroke);
        canvas.drawRect(Rect.fromLTWH(4, y + 24, 16, 6), stroke);
      }
      canvas.drawLine(const Offset(24, 24), const Offset(44, 24), dimStroke);
      canvas.drawRect(const Rect.fromLTWH(30, 20, 14, 8), stroke);
    } else if (variant == 'knockout16') {
      for (final y in [4.0, 10.0, 18.0, 24.0, 32.0, 38.0]) {
        canvas.drawRect(Rect.fromLTWH(2, y, 10, 3), dim);
      }
      for (final y in [8.0, 22.0, 36.0]) {
        canvas.drawRect(Rect.fromLTWH(14, y, 10, 3), dim);
      }
      for (final y in [16.0, 30.0]) {
        canvas.drawRect(Rect.fromLTWH(26, y, 10, 3), dim);
      }
      canvas.drawRect(const Rect.fromLTWH(38, 24, 10, 3), dim);
    } else if (variant == 'wc') {
      for (int col = 0; col < 4; col++) {
        for (final y in [4.0, 12.0, 20.0, 28.0]) {
          canvas.drawRect(Rect.fromLTWH(2 + col * 6, y, 4, 2), dim);
        }
      }
      canvas.drawLine(const Offset(28, 24), const Offset(46, 24), stroke);
      canvas.drawRect(const Rect.fromLTWH(34, 20, 10, 8), stroke);
    } else {
      // league
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 6, 40, 36),
          const Radius.circular(2),
        ),
        stroke,
      );
      for (final y in [12.0, 18.0, 24.0, 30.0, 36.0]) {
        canvas.drawLine(Offset(4, y), Offset(44, y), dimStroke);
      }
      for (final x in [14.0, 24.0, 34.0]) {
        canvas.drawLine(Offset(x, 6), Offset(x, 42), dimStroke);
      }
      canvas.drawRect(const Rect.fromLTWH(4, 6, 10, 6), dim);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BracketMiniPainter old) =>
      old.variant != variant || old.active != active;
}
