// real_map_mobile.dart — Google Maps-backed pickup map (iOS + Android).
//
// `GoogleMap` renders an empty gray tile when GMAPS_API_KEY isn't provided,
// so the app still ships before you register a key on Google Cloud.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(defaultCenterLat, defaultCenterLng),
        zoom: 12,
      ),
      markers: _buildMarkers(),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (c) => _controller = c,
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
          markerId: MarkerId(p.id),
          position: LatLng(la, ln),
          infoWindow: InfoWindow(
            title: p.venue,
            snippet: p.hostName ?? '球局',
          ),
          onTap: () => widget.onPinTap(p.id),
        ),
      );
    }
    return out;
  }

  /// Seed data may still carry normalised 0-1 coords; scatter them into a
  /// plausible Shenzhen bounding box so pins aren't all pinned at (0, 0).
  (double, double) _normaliseToShenzhen(double lat, double lng) {
    final looksNormalised = lat >= 0 && lat <= 1 && lng >= 0 && lng <= 1;
    if (!looksNormalised) return (lat, lng);
    const lngMin = 113.9;
    const lngMax = 114.2;
    const latMin = 22.5;
    const latMax = 22.7;
    final la = latMin + (latMax - latMin) * lat;
    final ln = lngMin + (lngMax - lngMin) * lng;
    return (la, ln);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
