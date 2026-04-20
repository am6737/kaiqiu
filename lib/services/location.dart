// location.dart — platform permission handshake + current coords.
//
// Uses `geolocator` under the hood (has a web implementation backed by the
// browser's Geolocation API). Amap's own location SDK is only wired to the
// map widget's "my location" overlay; for arbitrary queries we rely on the
// platform-agnostic geolocator instead.

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns the device's current position or `null` if the user declines the
  /// permission or location services are off. Never throws.
  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
