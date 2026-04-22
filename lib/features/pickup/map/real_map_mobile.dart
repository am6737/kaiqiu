// real_map_mobile.dart — AMap-backed pickup map (iOS + Android).

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../../models/pickup.dart';

const double defaultCenterLat = 22.8170;
const double defaultCenterLng = 108.3665;

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
    return AMapWidget(
      initialCameraPosition: const CameraPosition(
        target: LatLng(defaultCenterLat, defaultCenterLng),
        zoom: 12,
      ),
      markers: _buildMarkers(),
      myLocationStyleOptions: MyLocationStyleOptions(true),
    );
  }

  Set<Marker> _buildMarkers() {
    final out = <Marker>{};
    for (final p in widget.pickups) {
      final latRaw = p.lat;
      final lngRaw = p.lng;
      if (latRaw == null || lngRaw == null) continue;
      final (la, ln) = _normaliseToNanning(latRaw, lngRaw);
      out.add(
        Marker(
          position: LatLng(la, ln),
          infoWindow: InfoWindow(
            title: p.venue,
            snippet: p.hostName ?? '球局',
          ),
          onTap: (id) => widget.onPinTap(p.id),
        ),
      );
    }
    return out;
  }

  (double, double) _normaliseToNanning(double lat, double lng) {
    final looksNormalised = lat >= 0 && lat <= 1 && lng >= 0 && lng <= 1;
    if (!looksNormalised) return (lat, lng);
    const lngMin = 108.2;
    const lngMax = 108.5;
    const latMin = 22.7;
    const latMax = 22.9;
    final la = latMin + (latMax - latMin) * lat;
    final ln = lngMin + (lngMax - lngMin) * lng;
    return (la, ln);
  }
}
