// mini_map_mobile.dart — read-only AMapWidget for pickup detail.
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';

import '../../../config/env.dart';

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
    // Shenzhen center fallback when the pickup has no coords yet.
    final target = LatLng(lat ?? 22.5431, lng ?? 114.0579);
    return SizedBox(
      height: height,
      child: AbsorbPointer(
        child: AMapWidget(
          apiKey: AMapApiKey(
            iosKey: Env.amapIosKey,
            androidKey: Env.amapAndroidKey,
          ),
          privacyStatement: const AMapPrivacyStatement(
            hasContains: true,
            hasShow: true,
            hasAgree: true,
          ),
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: {
            if (lat != null && lng != null)
              Marker(
                position: target,
                infoWindow: const InfoWindow(title: ''),
              ),
          },
        ),
      ),
    );
  }
}
