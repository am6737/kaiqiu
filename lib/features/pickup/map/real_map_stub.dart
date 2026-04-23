// real_map_stub.dart — used on web. Renders the existing SVG-style canvas
// and lays out pins using each pickup's normalised (0-1) coords as a fallback.
//
// A mobile-first app will naturally see the real map via real_map_mobile.dart;
// web keeps a visually-coherent placeholder rather than a blank Google-Maps-
// style tile we can't render without a vendor SDK.

import 'package:flutter/material.dart';

import '../../../models/map_pin.dart';
import '../../../models/pickup.dart';
import 'marker_painter.dart';
import '../../../theme/app_tokens.dart';

/// Nanning default center — used by the mobile map, surfaced here so the
/// web stub can fake-scale pins around the same reference point.
const double defaultCenterLat = 22.8170;
const double defaultCenterLng = 108.3665;

class RealPickupMap extends StatelessWidget {
  final List<Pickup> pickups;
  final List<MapPin> extraPins;
  final String? activePinId;
  final ValueChanged<String> onPinTap;
  final VoidCallback? onLocateMe;
  final double? centerLat;
  final double? centerLng;
  final int locateTrigger;
  final dynamic onUserLocationChanged;
  final VoidCallback? onMapPanned;
  final VoidCallback? onMapTap;

  const RealPickupMap({
    super.key,
    required this.pickups,
    this.extraPins = const [],
    required this.onPinTap,
    this.activePinId,
    this.onLocateMe,
    this.centerLat,
    this.centerLng,
    this.locateTrigger = 0,
    this.onUserLocationChanged,
    this.onMapPanned,
    this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapBg     = isDark ? const Color(0xFF0E1310) : const Color(0xFFE8EDE9);
    final mapPark   = isDark ? const Color(0xFF142219) : const Color(0xFFC8E0D0);
    final mapStreet = isDark ? const Color(0xFF1D2A24) : const Color(0xFFD8DCD9);
    final mapRiver  = isDark ? const Color(0xFF13212B) : const Color(0xFFB8D4E2);
    return GestureDetector(
      onTap: onMapTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: mapBg,
            child: CustomPaint(
              painter: _MapStubPainter(
                parkColor:   mapPark,
                streetColor: mapStreet,
                riverColor:  mapRiver,
                bgColor:     mapBg,
              ),
            ),
          ),
          for (final p in pickups)
            _Pin(
              pickup: p,
              size: size,
              isActive: activePinId == p.id,
              onTap: () => onPinTap(p.id),
            ),
          for (final pin in extraPins)
            _VenuePin(
              pin: pin,
              size: size,
              isActive: activePinId == pin.id,
              onTap: () => onPinTap(pin.id),
            ),
        ],
      ),
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

    final text = '¥${pickup.feeYuan.toStringAsFixed(0)}';
    final painter = MarkerBubblePainter(
      text: text,
      bgColor: statusColor,
      active: isActive,
    );
    final scale = isActive ? 1.2 : 1.0;
    final w = painter.totalWidth * scale;
    final h = painter.totalHeight * scale;

    return Positioned(
      left: x - w / 2,
      top: y - h,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: painter,
            size: Size(painter.totalWidth, painter.totalHeight),
          ),
        ),
      ),
    );
  }

  (double, double) _normalise(double lng, double lat) {
    if (lng >= 0 && lng <= 1 && lat >= 0 && lat <= 1) {
      return (lng, lat);
    }
    // Real lat/lng (assume Nanning window). Map to 0-1.
    const lngMin = 108.1;
    const lngMax = 108.6;
    const latMin = 22.6;
    const latMax = 22.95;
    final nx = ((lng - lngMin) / (lngMax - lngMin)).clamp(0.02, 0.98);
    final ny = ((latMax - lat) / (latMax - latMin)).clamp(0.02, 0.98);
    return (nx.toDouble(), ny.toDouble());
  }
}

class _VenuePin extends StatelessWidget {
  final MapPin pin;
  final Size size;
  final bool isActive;
  final VoidCallback onTap;
  const _VenuePin({
    required this.pin,
    required this.size,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lngRaw = pin.lng;
    final latRaw = pin.lat;
    final (normX, normY) = _normalise(lngRaw, latRaw);
    final x = normX * size.width;
    final y = normY * (size.height * 0.7) + 120;

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
                border: Border.all(
                  color: const Color(0xFF2196F3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                Icons.stadium,
                size: isActive ? 18 : 14,
                color: const Color(0xFF2196F3),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: -3),
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
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
    const lngMin = 108.1;
    const lngMax = 108.6;
    const latMin = 22.6;
    const latMax = 22.95;
    final nx = ((lng - lngMin) / (lngMax - lngMin)).clamp(0.02, 0.98);
    final ny = ((latMax - lat) / (latMax - latMin)).clamp(0.02, 0.98);
    return (nx.toDouble(), ny.toDouble());
  }
}

class _MapStubPainter extends CustomPainter {
  final Color bgColor;
  final Color parkColor;
  final Color streetColor;
  final Color riverColor;

  const _MapStubPainter({
    required this.bgColor,
    required this.parkColor,
    required this.streetColor,
    required this.riverColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bg);

    // Soft green tint for "parks".
    final park = Paint()..color = parkColor;
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
      ..color = streetColor
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
      ..color = riverColor
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
  bool shouldRepaint(covariant _MapStubPainter oldDelegate) =>
      oldDelegate.bgColor != bgColor ||
      oldDelegate.parkColor != parkColor ||
      oldDelegate.streetColor != streetColor ||
      oldDelegate.riverColor != riverColor;
}
