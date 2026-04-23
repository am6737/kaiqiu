import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/picked_location.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.bg,
      appBar: AppBar(
        backgroundColor: context.tokens.elev1,
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: TextStyle(color: context.tokens.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: '搜索地点',
            hintStyle: TextStyle(color: context.tokens.inkDim, fontSize: 15),
            border: InputBorder.none,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.tokens.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _searchCtrl.text.isEmpty ? '输入关键词搜索地点' : '无搜索结果',
                    style: TextStyle(color: context.tokens.inkDim),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.tokens.line),
                  itemBuilder: (_, i) {
                    final poi = _results[i];
                    return ListTile(
                      title: Text(
                        poi.name,
                        style: TextStyle(
                          color: context.tokens.ink,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        poi.address,
                        style: TextStyle(
                          color: context.tokens.inkDim,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => _selectPoi(poi),
                    );
                  },
                ),
    );
  }
}
