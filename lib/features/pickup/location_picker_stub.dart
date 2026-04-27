import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/picked_location.dart';
import '../../models/venue.dart';
import '../../providers.dart';
import '../../services/amap_search_service.dart';
import '../../theme/app_tokens.dart';

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _searchCtrl = TextEditingController();
  List<PoiResult> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (text.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _loading = true);
      final city = ref.read(cityProvider);
      final results = await ref.read(amapSearchProvider).searchPoi(text, city: city);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    });
  }

  void _selectPoi(PoiResult poi) {
    Navigator.of(context).pop(PickedLocation(
      name: poi.name,
      address: poi.address,
      lat: poi.lat,
      lng: poi.lng,
    ));
  }

  void _selectVenue(Venue v) {
    Navigator.of(context).pop(PickedLocation(
      name: v.name,
      address: v.address,
      lat: v.lat,
      lng: v.lng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final venuesAsync = ref.watch(liveVenuesProvider);
    final showSearch = _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.elev1,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: TextStyle(color: t.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: '搜索地点',
            hintStyle: TextStyle(color: t.inkDim, fontSize: 15),
            border: InputBorder.none,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : showSearch
              ? _results.isEmpty
                  ? Center(
                      child: Text('无搜索结果', style: TextStyle(color: t.inkDim)),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: t.line),
                      itemBuilder: (_, i) {
                        final poi = _results[i];
                        return ListTile(
                          title: Text(
                            poi.name,
                            style: TextStyle(color: t.ink, fontSize: 15),
                          ),
                          subtitle: Text(
                            poi.address,
                            style: TextStyle(color: t.inkDim, fontSize: 12),
                          ),
                          onTap: () => _selectPoi(poi),
                        );
                      },
                    )
              : venuesAsync.when(
                  data: (venues) => venues.isEmpty
                      ? Center(
                          child: Text(
                            '输入关键词搜索地点',
                            style: TextStyle(color: t.inkDim),
                          ),
                        )
                      : _VenueList(
                          venues: venues,
                          onSelect: _selectVenue,
                        ),
                  loading: () =>
                      Center(child: CircularProgressIndicator(color: t.accent)),
                  error: (_, _) => Center(
                    child: Text(
                      '输入关键词搜索地点',
                      style: TextStyle(color: t.inkDim),
                    ),
                  ),
                ),
    );
  }
}

class _VenueList extends StatelessWidget {
  final List<Venue> venues;
  final void Function(Venue) onSelect;
  const _VenueList({required this.venues, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
            leading: Icon(Icons.stadium_outlined, color: t.accent, size: 20),
            title: Text(
              v.name,
              style: TextStyle(color: t.ink, fontSize: 15),
            ),
            subtitle: Text(
              v.address,
              style: TextStyle(color: t.inkDim, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: v.pricePerHourCents > 0
                ? Text(
                    '¥${v.pricePerHourYuan.toStringAsFixed(0)}/h',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.inkSub,
                    ),
                  )
                : null,
            onTap: () => onSelect(v),
          ),
        Divider(height: 1, color: t.line),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '找不到场地？在上方搜索栏输入地点名称',
            style: TextStyle(fontSize: 12, color: t.inkDim),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
