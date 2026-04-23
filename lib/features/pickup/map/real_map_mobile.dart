// real_map_mobile.dart — AMap-backed pickup map (iOS + Android).

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../../models/map_pin.dart';
import '../../../models/pickup.dart';
import 'marker_painter.dart';

const double defaultCenterLat = 22.8170;
const double defaultCenterLng = 108.3665;

class RealPickupMap extends StatefulWidget {
  final List<Pickup> pickups;
  final List<MapPin> extraPins;
  final String? activePinId;
  final ValueChanged<String> onPinTap;
  final VoidCallback? onLocateMe;
  final double? centerLat;
  final double? centerLng;
  final int locateTrigger;
  final ValueChanged<LatLng>? onUserLocationChanged;
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
  State<RealPickupMap> createState() => _RealPickupMapState();
}

class _RealPickupMapState extends State<RealPickupMap> {
  AMapController? _controller;
  LatLng? _userLocation;
  bool _initialLocateDone = false;
  bool _pendingLocate = false;
  Map<String, BitmapDescriptor> _markerIcons = {};

  @override
  void initState() {
    super.initState();
    _renderAllIcons();
  }

  @override
  void didUpdateWidget(RealPickupMap old) {
    super.didUpdateWidget(old);
    if (widget.locateTrigger != old.locateTrigger) {
      _flyToUser();
    }
    if (widget.pickups != old.pickups || widget.activePinId != old.activePinId) {
      _renderAllIcons();
    }
  }

  Future<void> _renderAllIcons() async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF4CAF50) : const Color(0xFF4CAF50);
    final warnColor = isDark ? const Color(0xFFFF6B35) : const Color(0xFFFF6B35);
    final muteColor = isDark ? const Color(0x80FFFFFF) : const Color(0x80B8B2A8);

    final icons = <String, BitmapDescriptor>{};
    for (final p in widget.pickups) {
      final text = '¥${p.feeYuan.toStringAsFixed(0)}';
      final need = p.displayNeed;
      final Color bgColor;
      if (need > 2) {
        bgColor = accentColor;
      } else if (need > 0) {
        bgColor = warnColor;
      } else {
        bgColor = muteColor;
      }
      final isActive = p.id == widget.activePinId;
      final bytes = await renderMarkerBitmap(
        text: text,
        bgColor: bgColor,
        active: isActive,
      );
      icons[p.id] = BitmapDescriptor.fromBytes(bytes);
    }
    if (mounted) setState(() => _markerIcons = icons);
  }

  void _flyToUser() {
    if (_userLocation != null) {
      _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 15),
      );
      return;
    }
    if (widget.centerLat != null && widget.centerLng != null) {
      final target = LatLng(widget.centerLat!, widget.centerLng!);
      _userLocation = target;
      _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );
      return;
    }
    _pendingLocate = true;
  }

  @override
  Widget build(BuildContext context) {
    return AMapWidget(
      initialCameraPosition: const CameraPosition(
        target: LatLng(defaultCenterLat, defaultCenterLng),
        zoom: 12,
      ),
      markers: _buildMarkers(),
      myLocationStyleOptions: MyLocationStyleOptions(true),
      onMapCreated: (c) {
        _controller = c;
        _flyToUser();
      },
      onTap: (LatLng _) => widget.onMapTap?.call(),  // ← ADD
      onLocationChanged: (AMapLocation loc) {
        if (isLocationValid(loc)) {
          _userLocation = loc.latLng;
          widget.onUserLocationChanged?.call(loc.latLng);
          if (!_initialLocateDone || _pendingLocate) {
            _initialLocateDone = true;
            _pendingLocate = false;
            _controller?.moveCamera(
              CameraUpdate.newLatLngZoom(loc.latLng, 15),
            );
          }
        }
      },
      onCameraMoveEnd: (pos) {
        if (_userLocation == null) return;
        final meters = Geolocator.distanceBetween(
          pos.target.latitude, pos.target.longitude,
          _userLocation!.latitude, _userLocation!.longitude,
        );
        if (meters > 50) {
          widget.onMapPanned?.call();
        }
      },
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
          icon: _markerIcons[p.id] ?? BitmapDescriptor.defaultMarker,
          infoWindowEnable: false,
          onTap: (id) => widget.onPinTap(p.id),
        ),
      );
    }
    for (final pin in widget.extraPins) {
      final (la, ln) = _normaliseToNanning(pin.lat, pin.lng);
      out.add(
        Marker(
          position: LatLng(la, ln),
          infoWindow: InfoWindow(
            title: pin.label,
            snippet: pin.sublabel ?? '场馆',
          ),
          onTap: (id) => widget.onPinTap(pin.id),
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
