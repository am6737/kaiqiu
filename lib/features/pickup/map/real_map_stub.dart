// real_map_stub.dart — used on web. Renders the existing SVG-style canvas
// and lays out pins using each pickup's normalised (0-1) coords as a fallback.
//
// A mobile-first app will naturally see the real map via real_map_mobile.dart;
// web keeps a visually-coherent placeholder rather than a blank Google-Maps-
// style tile we can't render without a vendor SDK.

import 'package:flutter/material.dart';

import '../../../models/pickup.dart';
import '../../../widgets/sport_icon.dart';
import '../../../theme/app_tokens.dart';

/// Shenzhen default center — used by the mobile map, surfaced here so the
/// web stub can fake-scale pins around the same reference point.
const double defaultCenterLat = 22.5431;
const double defaultCenterLng = 114.0579;

class RealPickupMap extends StatelessWidget {
  final List<Pickup> pickups;
  final String? activePinId;
  final ValueChanged<String> onPinTap;
  final VoidCallback? onLocateMe;

  const RealPickupMap({
    super.key,
    required this.pickups,
    required this.onPinTap,
    this.activePinId,
    this.onLocateMe,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: const Color(0xFF0E1310),
          child: CustomPaint(painter: _MapStubPainter()),
        ),
        for (final p in pickups)
          _Pin(
            pickup: p,
            size: size,
            isActive: activePinId == p.id,
            onTap: () => onPinTap(p.id),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  final Pickup pickup;
  final Size size;
  final bool isActive;
  final VoidCallback onTap;
  const _Pin({
    required this.pickup,
    required this.size,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // On web we accept either normalised (0-1) coords or real lat/lng that
    // happen to fall near Shenzhen. Auto-detect.
    final lngRaw = pickup.lng ?? 0.5;
    final latRaw = pickup.lat ?? 0.5;
    final (normX, normY) = _normalise(lngRaw, latRaw);
    final x = normX * size.width;
    final y = normY * (size.height * 0.7) + 120;

    final statusColor = switch (pickup.status) {
      PickupStatus.full => context.tokens.inkMute,
      PickupStatus.almost => context.tokens.warn,
      _ => context.tokens.accent,
    };

    return Positioned(
      left: x - 16,
      top: y - 40,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isActive ? 40 : 32,
              height: isActive ? 40 : 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev1,
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: SportIcon(
                Sport.football,
                size: isActive ? 18 : 14,
                color: statusColor,
              ),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: -3),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (double, double) _normalise(double lng, double lat) {
    if (lng >= 0 && lng <= 1 && lat >= 0 && lat <= 1) {
      return (lng, lat);
    }
    // Real lat/lng (assume Shenzhen window). Map to 0-1.
    const lngMin = 113.7;
    const lngMax = 114.5;
    const latMin = 22.4;
    const latMax = 22.8;
    final nx = ((lng - lngMin) / (lngMax - lngMin)).clamp(0.02, 0.98);
    final ny = ((latMax - lat) / (latMax - latMin)).clamp(0.02, 0.98);
    return (nx.toDouble(), ny.toDouble());
  }
}

class _MapStubPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()..color = const Color(0xFF0E1310);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    // Soft green tint for "parks".
    final park = Paint()..color = const Color(0xFF142219);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.08, h * 0.62)
        ..quadraticBezierTo(w * 0.18, h * 0.5, w * 0.32, h * 0.58)
        ..quadraticBezierTo(w * 0.42, h * 0.66, w * 0.35, h * 0.8)
        ..quadraticBezierTo(w * 0.20, h * 0.85, w * 0.08, h * 0.78)
        ..close(),
      park,
    );

    // Streets grid.
    final street = Paint()
      ..color = const Color(0xFF1D2A24)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 12; i++) {
      final y = h * (0.12 + i * 0.07);
      canvas.drawLine(Offset(0, y), Offset(w, y + 6), street);
    }
    for (int i = 0; i < 8; i++) {
      final x = w * (0.1 + i * 0.11);
      canvas.drawLine(Offset(x, 0), Offset(x + 8, h), street);
    }

    // River.
    final river = Paint()
      ..color = const Color(0xFF13212B)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.3)
        ..quadraticBezierTo(w * 0.3, h * 0.35, w * 0.55, h * 0.28)
        ..quadraticBezierTo(w * 0.8, h * 0.22, w, h * 0.3),
      river,
    );
  }

  @override
  bool shouldRepaint(covariant _MapStubPainter oldDelegate) => false;
}
