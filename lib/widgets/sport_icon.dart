// sport_icon.dart — minimalist geometric sport marks (no "people")
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

enum Sport { football, basketball, badminton, pingpong, cycling }

class SportIcon extends StatelessWidget {
  final Sport sport;
  final double size;
  final Color? color;

  const SportIcon(this.sport, {super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SportPainter(sport, color ?? context.tokens.ink)),
    );
  }
}

class _SportPainter extends CustomPainter {
  final Sport sport;
  final Color color;
  _SportPainter(this.sport, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scale);

    switch (sport) {
      case Sport.football:
        canvas.drawCircle(const Offset(8, 8), 6.5, paint);
        final p = Path()
          ..moveTo(8, 3.5)
          ..lineTo(5, 6)
          ..lineTo(6.2, 9.6)
          ..lineTo(9.8, 9.6)
          ..lineTo(11, 6)
          ..close();
        canvas.drawPath(p, paint);
        break;
      case Sport.basketball:
        canvas.drawCircle(const Offset(8, 8), 6.5, paint);
        canvas.drawLine(const Offset(1.5, 8), const Offset(14.5, 8), paint);
        canvas.drawLine(const Offset(8, 1.5), const Offset(8, 14.5), paint);
        canvas.drawPath(
          Path()
            ..moveTo(3.3, 3.3)
            ..cubicTo(5, 5, 5, 11, 3.3, 12.7),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12.7, 3.3)
            ..cubicTo(11, 5, 11, 11, 12.7, 12.7),
          paint,
        );
        break;
      case Sport.badminton:
        canvas.drawCircle(const Offset(5, 11), 2.5, paint);
        canvas.drawLine(const Offset(6.8, 9.2), const Offset(13, 3), paint);
        canvas.drawLine(const Offset(10, 3), const Offset(13, 3), paint);
        canvas.drawLine(const Offset(13, 3), const Offset(13, 6), paint);
        break;
      case Sport.pingpong:
        canvas.save();
        canvas.translate(7, 7);
        canvas.rotate(-0.5236); // -30 degrees
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 9, height: 11),
          paint,
        );
        canvas.restore();
        canvas.drawLine(
          const Offset(10, 10),
          const Offset(13, 13),
          paint..strokeWidth = 1.4 * scale,
        );
        break;
      case Sport.cycling:
        canvas.drawCircle(const Offset(4, 11), 3, paint);
        canvas.drawCircle(const Offset(12, 11), 3, paint);
        final p = Path()
          ..moveTo(4, 11)
          ..lineTo(7, 5)
          ..lineTo(10, 5)
          ..lineTo(12, 11)
          ..moveTo(7, 5)
          ..lineTo(6, 5)
          ..moveTo(10, 5)
          ..lineTo(8, 11);
        canvas.drawPath(p, paint);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SportPainter old) =>
      old.sport != sport || old.color != color;
}
