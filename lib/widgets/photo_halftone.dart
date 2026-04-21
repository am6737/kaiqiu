// photo_halftone.dart — halftone / scan-line photo placeholder
// Matches the React PhotoHalftone component.
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

enum HalftoneVariant { dots, lines }

class PhotoHalftone extends StatelessWidget {
  final String label;
  final double height;
  final double hue;
  final HalftoneVariant variant;

  const PhotoHalftone({
    super.key,
    required this.label,
    this.height = 160,
    this.hue = 140,
    this.variant = HalftoneVariant.dots,
  });

  @override
  Widget build(BuildContext context) {
    final bg = HSLColor.fromAHSL(1, hue, 0.15, 0.18).toColor();
    return ClipRect(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: bg),
            // Pattern layer
            CustomPaint(painter: _HalftonePainter(variant)),
            // Label at bottom-left
            Positioned(
              left: 10,
              bottom: 10,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
                  fontSize: 10,
                  color: context.tokens.inkDim,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalftonePainter extends CustomPainter {
  final HalftoneVariant variant;
  _HalftonePainter(this.variant);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x17FFFFFF); // ~0.09
    if (variant == HalftoneVariant.dots) {
      const step = 6.0;
      for (double y = 0; y < size.height; y += step) {
        for (double x = 0; x < size.width; x += step) {
          canvas.drawCircle(Offset(x + 2, y + 2), 1, paint);
        }
      }
    } else {
      final line = Paint()
        ..color =
            const Color(0x0AFFFFFF) // ~0.04
        ..strokeWidth = 1;
      for (double y = 0; y < size.height; y += 3) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter old) => old.variant != variant;
}
