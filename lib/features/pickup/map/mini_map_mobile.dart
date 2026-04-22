// mini_map_mobile.dart — read-only Google Maps for pickup detail.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    // Nanning fallback when the pickup has no coords yet.
    final target = LatLng(lat ?? 22.8170, lng ?? 108.3665);
    return SizedBox(
      height: height,
      child: AbsorbPointer(
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: {
            if (lat != null && lng != null)
              Marker(
                markerId: const MarkerId('venue'),
                position: target,
              ),
          },
          zoomControlsEnabled: false,
          liteModeEnabled: true,
        ),
      ),
    );
  }
}
