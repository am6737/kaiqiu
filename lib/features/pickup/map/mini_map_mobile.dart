// mini_map_mobile.dart — read-only AMap for pickup detail.
import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:x_amap_base/x_amap_base.dart';

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
    final target = LatLng(lat ?? 22.8170, lng ?? 108.3665);
    return SizedBox(
      height: height,
      child: AbsorbPointer(
        child: AMapWidget(
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: {
            if (lat != null && lng != null)
              Marker(position: target),
          },
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          scaleEnabled: false,
          compassEnabled: false,
        ),
      ),
    );
  }
}
