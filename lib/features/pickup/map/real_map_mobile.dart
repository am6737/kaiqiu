// real_map_mobile.dart — AMapWidget-backed pickup map (iOS + Android).
//
// Requires AMAP_IOS_KEY / AMAP_ANDROID_KEY to be injected at runtime; without
// them the plugin still renders a (blank-with-copyright) basemap and we keep
// the rest of the UI functional.

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../config/env.dart';
import '../../../models/pickup.dart';

/// Shenzhen default center.
const double defaultCenterLat = 22.5431;
const double defaultCenterLng = 114.0579;

class RealPickupMap extends StatefulWidget {
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
  State<RealPickupMap> createState() => _RealPickupMapState();
}

class _RealPickupMapState extends State<RealPickupMap> {
  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();

    return AMapWidget(
      apiKey: AMapApiKey(
        iosKey: Env.amapIosKey,
        androidKey: Env.amapAndroidKey,
      ),
      // Terms must be accepted before any network call is made. The
      // acceptance flag is stored per-install; the calling app is
      // expected to show user-facing ToS elsewhere.
      privacyStatement: const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
      initialCameraPosition: const CameraPosition(
        target: LatLng(defaultCenterLat, defaultCenterLng),
        zoom: 12,
      ),
      markers: markers,
      myLocationStyleOptions: MyLocationStyleOptions(true),
    );
  }

  Set<Marker> _buildMarkers() {
    final out = <Marker>{};
    for (final p in widget.pickups) {
      final latRaw = p.lat;
      final lngRaw = p.lng;
      if (latRaw == null || lngRaw == null) continue;
      final (la, ln) = _normaliseToShenzhen(latRaw, lngRaw);
      out.add(
        Marker(
          position: LatLng(la, ln),
          infoWindow: InfoWindow(title: p.venue, snippet: p.hostName ?? '球局'),
          onTap: (markerId) => widget.onPinTap(p.id),
        ),
      );
    }
    return out;
  }

  /// Seed data may still carry normalised 0-1 coords; convert those to real
  /// world coords inside Shenzhen's bounding box so pins aren't all stuck at
  /// latLng(0,0) which high-德 renders as "off the equator, far at sea".
  (double, double) _normaliseToShenzhen(double lat, double lng) {
    final looksNormalised = lat >= 0 && lat <= 1 && lng >= 0 && lng <= 1;
    if (!looksNormalised) return (lat, lng);
    const lngMin = 113.9;
    const lngMax = 114.2;
    const latMin = 22.5;
    const latMax = 22.7;
    final la = latMin + (latMax - latMin) * lat;
    final ln = lngMin + (lngMax - lngMin) * lng;
    if (kDebugMode) {
      debugPrint('[map] normalised pickup coords ($lat,$lng) → ($la,$ln)');
    }
    return (la, ln);
  }

  // AMapController lifecycle is owned by AMapWidget internally; no explicit
  // dispose needed here.
}
