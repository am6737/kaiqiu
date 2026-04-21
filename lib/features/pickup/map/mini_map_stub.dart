// mini_map_stub.dart — web placeholder. Keeps the existing dark-grid look.
import 'package:flutter/material.dart';
import '../../../theme/app_tokens.dart';


class PickupMiniMap extends StatelessWidget {
  final double? lat;
  final double? lng;
  final double height;

  const PickupMiniMap({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        color: const Color(0xFF0E1310),
        child: CustomPaint(painter: _MiniStubPainter(accentColor: context.tokens.accent)),
      ),
    );
  }
}

class _MiniStubPainter extends CustomPainter {
  final Color accentColor;
  const _MiniStubPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()..color = const Color(0x0AFFFFFF);
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final road = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 60), Offset(size.width, 70), road);
    canvas.drawCircle(
      Offset(size.width / 2, 60),
      12,
      Paint()
        ..color = const Color(0x4D00FF85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(size.width / 2, 60), 5, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant _MiniStubPainter oldDelegate) => false;
}
