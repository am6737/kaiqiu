import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MarkerBubblePainter extends CustomPainter {
  final String text;
  final Color bgColor;
  final bool active;

  const MarkerBubblePainter({
    required this.text,
    required this.bgColor,
    this.active = false,
  });

  static const double _height = 28;
  static const double _triSize = 6;
  static const double _radius = 6;
  static const double _hPad = 10;
  static const double _fontSize = 12;

  double get _textWidth {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  double get totalWidth => _textWidth + _hPad * 2;
  double get totalHeight => _height + _triSize;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bgPaint = Paint()..color = bgColor;

    if (active) {
      final glowPaint = Paint()
        ..color = bgColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final glowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, _height),
        const Radius.circular(_radius),
      );
      canvas.drawRRect(glowRect, glowPaint);
    }

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, _height),
      const Radius.circular(_radius),
    );
    canvas.drawRRect(bodyRect, bgPaint);

    final triPath = Path()
      ..moveTo(w / 2 - _triSize, _height)
      ..lineTo(w / 2, _height + _triSize)
      ..lineTo(w / 2 + _triSize, _height)
      ..close();
    canvas.drawPath(triPath, bgPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((_hPad), (_height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant MarkerBubblePainter old) =>
      old.text != text || old.bgColor != bgColor || old.active != active;
}

final Map<String, Uint8List> _bytesCache = {};

Future<Uint8List> renderMarkerBitmap({
  required String text,
  required Color bgColor,
  bool active = false,
}) async {
  final key = '$text|${bgColor.toARGB32()}|$active';
  final cached = _bytesCache[key];
  if (cached != null) return cached;

  final painter = MarkerBubblePainter(
    text: text,
    bgColor: bgColor,
    active: active,
  );

  final scale = active ? 1.2 : 1.0;
  final w = painter.totalWidth * scale;
  final h = painter.totalHeight * scale;
  final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  final pixelW = (w * dpr).ceil();
  final pixelH = (h * dpr).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(dpr * scale);
  painter.paint(canvas, Size(painter.totalWidth, painter.totalHeight));
  final picture = recorder.endRecording();

  final image = await picture.toImage(pixelW, pixelH);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  final bytes = byteData!.buffer.asUint8List();
  _bytesCache[key] = bytes;
  return bytes;
}
