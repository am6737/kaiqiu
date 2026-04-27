import 'dart:async';
import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../models/picked_location.dart';
import '../../models/venue.dart';
import '../../providers.dart';
import '../../services/amap_search_service.dart';
import '../../services/location.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primary_button.dart';

const double _defaultLat = 22.8170;
const double _defaultLng = 108.3665;

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  AMapController? _mapController;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Timer? _cameraDebounce;

  List<PoiResult> _searchResults = [];
  bool _showSearchResults = false;
  bool _searching = false;

  String _poiName = '';
  String _poiAddress = '';
  double _centerLat = _defaultLat;
  double _centerLng = _defaultLng;
  bool _reverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _cameraDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    final pos = await LocationService().currentPosition();
    if (pos != null && mounted) {
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
      });
      _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_centerLat, _centerLng),
          16,
        ),
      );
      _doReverseGeocode(_centerLat, _centerLng);
    } else {
      _doReverseGeocode(_centerLat, _centerLng);
    }
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      final city = ref.read(cityProvider);
      final results = await ref.read(amapSearchProvider).searchPoi(text, city: city);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _showSearchResults = true;
        _searching = false;
      });
    });
  }

  void _selectSearchResult(PoiResult poi) {
    _searchCtrl.clear();
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
      _poiName = poi.name;
      _poiAddress = poi.address;
      _centerLat = poi.lat;
      _centerLng = poi.lng;
    });
    _mapController?.moveCamera(
      CameraUpdate.newLatLngZoom(LatLng(poi.lat, poi.lng), 16),
    );
    FocusScope.of(context).unfocus();
  }

  void _selectVenue(Venue v) {
    _searchCtrl.clear();
    setState(() {
      _showSearchResults = false;
      _searchResults = [];
      _poiName = v.name;
      _poiAddress = v.address;
      _centerLat = v.lat;
      _centerLng = v.lng;
    });
    _mapController?.moveCamera(
      CameraUpdate.newLatLngZoom(LatLng(v.lat, v.lng), 16),
    );
    FocusScope.of(context).unfocus();
  }

  void _onCameraMoveEnd(CameraPosition pos) {
    _cameraDebounce?.cancel();
    final lat = pos.target.latitude;
    final lng = pos.target.longitude;
    _centerLat = lat;
    _centerLng = lng;
    _cameraDebounce = Timer(const Duration(milliseconds: 500), () {
      _doReverseGeocode(lat, lng);
    });
  }

  Future<void> _doReverseGeocode(double lat, double lng) async {
    setState(() => _reverseGeocoding = true);
    final result = await ref.read(amapSearchProvider).reverseGeocode(lat, lng);
    if (!mounted) return;
    setState(() {
      _reverseGeocoding = false;
      if (result != null) {
        _poiName = result.name;
        _poiAddress = result.address;
      }
    });
  }

  Widget _buildVenueQuickPick(BuildContext context) {
    final t = context.tokens;
    final venuesAsync = ref.watch(liveVenuesProvider);
    return venuesAsync.when(
      data: (venues) => venues.isEmpty
          ? Center(
              child: Text('无搜索结果', style: TextStyle(color: t.inkDim)),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    '平台场馆',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.inkSub,
                    ),
                  ),
                ),
                for (final v in venues)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.stadium_outlined, color: t.accent, size: 18),
                    title: Text(v.name, style: TextStyle(color: t.ink, fontSize: 14)),
                    subtitle: Text(
                      v.address,
                      style: TextStyle(color: t.inkDim, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectVenue(v),
                  ),
              ],
            ),
      loading: () => Center(child: CircularProgressIndicator(color: t.accent)),
      error: (_, _) => Center(
        child: Text('无搜索结果', style: TextStyle(color: t.inkDim)),
      ),
    );
  }

  void _confirm() {
    if (_poiName.isEmpty && _poiAddress.isEmpty) return;
    Navigator.of(context).pop(PickedLocation(
      name: _poiName.isNotEmpty ? _poiName : _poiAddress,
      address: _poiAddress,
      lat: _centerLat,
      lng: _centerLng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Map
            Positioned.fill(
              child: AMapWidget(
                initialCameraPosition: CameraPosition(
                  target: LatLng(_centerLat, _centerLng),
                  zoom: 16,
                ),
                myLocationStyleOptions: MyLocationStyleOptions(true),
                onMapCreated: (c) => _mapController = c,
                onCameraMoveEnd: _onCameraMoveEnd,
              ),
            ),

            // Center pin
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 42,
                  color: context.tokens.accent,
                ),
              ),
            ),

            // Top search bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: context.tokens.elev1,
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: context.tokens.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: context.tokens.elev2,
                          borderRadius:
                              BorderRadius.circular(context.tokens.r2),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          onTap: () {
                            if (!_showSearchResults) {
                              setState(() => _showSearchResults = true);
                            }
                          },
                          style: TextStyle(
                            color: context.tokens.ink,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '搜索地点或选择场馆',
                            hintStyle: TextStyle(
                              color: context.tokens.inkDim,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                            icon: Icon(
                              Icons.search,
                              size: 18,
                              color: context.tokens.inkDim,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search results overlay
            if (_showSearchResults)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                bottom: 160,
                child: Container(
                  color: context.tokens.elev1,
                  child: _searching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? _buildVenueQuickPick(context)
                          : ListView.separated(
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: context.tokens.line,
                              ),
                              itemBuilder: (_, i) {
                                final poi = _searchResults[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    poi.name,
                                    style: TextStyle(
                                      color: context.tokens.ink,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    poi.address,
                                    style: TextStyle(
                                      color: context.tokens.inkDim,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () => _selectSearchResult(poi),
                                );
                              },
                            ),
                ),
              ),

            // Locate me button
            Positioned(
              right: 16,
              bottom: 180,
              child: FloatingActionButton.small(
                heroTag: 'locate_me',
                backgroundColor: context.tokens.elev1,
                onPressed: _locateUser,
                child: Icon(
                  Icons.my_location,
                  color: context.tokens.accent,
                ),
              ),
            ),

            // Bottom info bar + confirm button
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                decoration: BoxDecoration(
                  color: context.tokens.elev1,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_reverseGeocoding)
                      Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.tokens.accent,
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        _poiName.isNotEmpty ? _poiName : '移动地图选择位置',
                        style: TextStyle(
                          color: context.tokens.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_poiAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _poiAddress,
                          style: TextStyle(
                            color: context.tokens.inkDim,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: '确认选点',
                      variant: BtnVariant.primary,
                      size: BtnSize.lg,
                      full: true,
                      onPressed:
                          (_poiName.isEmpty && _poiAddress.isEmpty) || _reverseGeocoding
                              ? null
                              : _confirm,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
