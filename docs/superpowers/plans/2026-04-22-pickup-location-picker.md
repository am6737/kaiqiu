# 约球创建 — 活动标题 & 地图选点 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在约球创建流程中增加选填活动标题（未填自动生成）和全屏地图选点（支持拖动 + POI 搜索）。

**Architecture:** 新建高德 Web Service API 封装（HTTP）用于 POI 搜索和逆地理编码；新建全屏地图选点页面（条件导入模式，移动端用 AMap、Web 端用纯搜索 stub）；改造创建表单，用地点选择卡片替换原文本字段，顶部增加标题输入框。

**Tech Stack:** Flutter, Riverpod, GoRouter, AMap SDK (`amap_map`/`x_amap_base`), `http` package, Supabase

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `lib/models/picked_location.dart` | 选点返回数据结构 |
| 新建 | `lib/services/amap_search_service.dart` | 高德 POI 搜索 + 逆地理编码封装 |
| 新建 | `lib/features/pickup/location_picker.dart` | 条件导入入口 |
| 新建 | `lib/features/pickup/location_picker_mobile.dart` | 移动端全屏地图选点 |
| 新建 | `lib/features/pickup/location_picker_stub.dart` | Web 端纯搜索 stub |
| 修改 | `lib/features/pickup/create_pickup_screen.dart` | 标题字段 + 地点选择卡片 + 提交逻辑 |
| 修改 | `lib/providers.dart` | 添加 amapSearchProvider |
| 修改 | `lib/config/env.dart` | 添加 amapWebKey（Web Service Key） |
| 修改 | `pubspec.yaml` | 添加 http 依赖 |

---

### Task 1: 添加 http 依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 在 pubspec.yaml 添加 http 包**

在 `dependencies:` 中添加（找到 `intl:` 那一行附近即可）：

```yaml
  http: ^1.2.0
```

- [ ] **Step 2: 运行 pub get**

Run: `flutter pub get`
Expected: 成功解析依赖

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add http package for AMap Web Service API"
```

---

### Task 2: 添加 Web Service API Key 配置

**Files:**
- Modify: `lib/config/env.dart`

- [ ] **Step 1: 在 Env 类中添加 amapWebKey**

在 `lib/config/env.dart` 的 `amapKey` 常量后面追加：

```dart
  // AMap Web Service API key (for POI search / reverse geocoding).
  // May be the same key if the console has Web Service enabled for it.
  static const amapWebKey = String.fromEnvironment(
    'AMAP_WEB_KEY',
    defaultValue: '320ae72b5f24ee9d84f966cb2c9ecd98',
  );
```

- [ ] **Step 2: Commit**

```bash
git add lib/config/env.dart
git commit -m "feat: add AMap Web Service API key config"
```

---

### Task 3: 创建 PickedLocation 模型

**Files:**
- Create: `lib/models/picked_location.dart`

- [ ] **Step 1: 创建模型文件**

```dart
class PickedLocation {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const PickedLocation({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/picked_location.dart
git commit -m "feat: add PickedLocation model"
```

---

### Task 4: 创建 AmapSearchService

**Files:**
- Create: `lib/services/amap_search_service.dart`
- Modify: `lib/providers.dart`

- [ ] **Step 1: 创建 amap_search_service.dart**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class PoiResult {
  final String name;
  final String address;
  final double lat;
  final double lng;

  const PoiResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class AmapSearchService {
  static const _base = 'https://restapi.amap.com/v3';

  Future<List<PoiResult>> searchPoi(String keywords) async {
    if (keywords.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/place/text').replace(queryParameters: {
      'key': Env.amapWebKey,
      'keywords': keywords.trim(),
      'offset': '20',
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['status'] != '1') return [];
      final pois = body['pois'] as List? ?? [];
      return pois.map((p) {
        final loc = (p['location'] as String? ?? '').split(',');
        final lng = double.tryParse(loc.isNotEmpty ? loc[0] : '') ?? 0;
        final lat = double.tryParse(loc.length > 1 ? loc[1] : '') ?? 0;
        return PoiResult(
          name: p['name'] as String? ?? '',
          address: p['address'] as String? ?? '',
          lat: lat,
          lng: lng,
        );
      }).where((p) => p.lat != 0 && p.lng != 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<PoiResult?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_base/geocode/regeo').replace(queryParameters: {
      'key': Env.amapWebKey,
      'location': '${lng.toStringAsFixed(6)},${lat.toStringAsFixed(6)}',
      'extensions': 'all',
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['status'] != '1') return null;
      final regeo = body['regeocode'] as Map<String, dynamic>? ?? {};
      final formatted = regeo['formatted_address'] as String? ?? '';
      final pois = regeo['pois'] as List?;
      String name;
      if (pois != null && pois.isNotEmpty) {
        name = pois[0]['name'] as String? ?? '';
      } else {
        final comp = regeo['addressComponent'] as Map<String, dynamic>? ?? {};
        final nb = comp['neighborhood'] as Map<String, dynamic>? ?? {};
        name = nb['name'] as String? ?? '';
      }
      if (name.isEmpty) name = formatted;
      return PoiResult(name: name, address: formatted, lat: lat, lng: lng);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 2: 在 providers.dart 添加 provider**

在 `lib/providers.dart` 的 import 区域添加：

```dart
import 'services/amap_search_service.dart';
```

在 Repositories 区域（`likesRepoProvider` 之后）添加：

```dart
final amapSearchProvider = Provider((_) => AmapSearchService());
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/amap_search_service.dart lib/providers.dart
git commit -m "feat: add AmapSearchService with POI search and reverse geocoding"
```

---

### Task 5: 创建 LocationPicker 条件导入入口

**Files:**
- Create: `lib/features/pickup/location_picker.dart`

- [ ] **Step 1: 创建条件导入文件**

```dart
export 'location_picker_stub.dart'
    if (dart.library.io) 'location_picker_mobile.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pickup/location_picker.dart
git commit -m "feat: add location picker conditional import entry"
```

---

### Task 6: 创建 LocationPicker Web Stub

**Files:**
- Create: `lib/features/pickup/location_picker_stub.dart`

- [ ] **Step 1: 创建 stub 文件**

Web 端不使用地图，只提供搜索框 + POI 列表选择。

```dart
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
      final results = await ref.read(amapSearchProvider).searchPoi(text);
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
                  separatorBuilder: (_, __) =>
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pickup/location_picker_stub.dart
git commit -m "feat: add LocationPicker web stub (search-only)"
```

---

### Task 7: 创建 LocationPicker 移动端（全屏地图 + 搜索）

**Files:**
- Create: `lib/features/pickup/location_picker_mobile.dart`

- [ ] **Step 1: 创建移动端地图选点页面**

```dart
import 'dart:async';
import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../models/picked_location.dart';
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
  Timer? _debounce;

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
    _debounce?.cancel();
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
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      final results = await ref.read(amapSearchProvider).searchPoi(text);
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

  void _onCameraMoveEnd(CameraPosition pos) {
    _debounce?.cancel();
    final lat = pos.target.latitude;
    final lng = pos.target.longitude;
    _centerLat = lat;
    _centerLng = lng;
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
                          style: TextStyle(
                            color: context.tokens.ink,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '搜索地点',
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
                          ? Center(
                              child: Text(
                                '无搜索结果',
                                style: TextStyle(
                                  color: context.tokens.inkDim,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => Divider(
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/pickup/location_picker_mobile.dart
git commit -m "feat: add LocationPicker mobile with AMap and POI search"
```

---

### Task 8: 改造 CreatePickupScreen

**Files:**
- Modify: `lib/features/pickup/create_pickup_screen.dart`

这是最大的改动，分为几个子步骤。

- [ ] **Step 1: 添加 import 和新状态变量**

在文件顶部添加 import：

```dart
import '../../models/picked_location.dart';
```

在 `_CreatePickupScreenState` 类中，删除 `_venue` 和 `_address` 两个 TextEditingController：

```dart
  // 删除这两行：
  // final _venue = TextEditingController(text: '莲花山足球场');
  // final _address = TextEditingController();
```

替换为新的状态字段：

```dart
  final _title = TextEditingController();
  PickedLocation? _pickedLocation;
```

- [ ] **Step 2: 更新 dispose 方法**

将 dispose 方法从：

```dart
  @override
  void dispose() {
    for (final c in [_venue, _address, _start, _duration, _total, _fee]) {
      c.dispose();
    }
    super.dispose();
  }
```

改为：

```dart
  @override
  void dispose() {
    for (final c in [_title, _start, _duration, _total, _fee]) {
      c.dispose();
    }
    super.dispose();
  }
```

- [ ] **Step 3: 添加默认标题生成方法和选点导航方法**

在 `_parseStart` 方法之后添加：

```dart
  String _generateDefaultTitle(String venue, DateTime startAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startAt.year, startAt.month, startAt.day);
    final diff = startDay.difference(today).inDays;
    final time =
        '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}';
    String label;
    if (diff == 0) {
      label = '今天 $time';
    } else if (diff == 1) {
      label = '明天 $time';
    } else if (diff > 1 && diff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      label = '${weekdays[startAt.weekday - 1]} $time';
    } else {
      label = '${startAt.month}/${startAt.day} $time';
    }
    return '$venue $label';
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) {
        // 使用条件导入的 LocationPickerScreen
        return const LocationPickerScreen();
      }),
    );
    if (result != null && mounted) {
      setState(() => _pickedLocation = result);
    }
  }
```

注意：这里需要在文件顶部添加对 location_picker 的 import：

```dart
import 'location_picker.dart';
```

- [ ] **Step 4: 更新 _submit 方法**

将 `_submit` 方法中的校验和 payload 构建改为：

将：
```dart
    if (validateRequired(_venue.text) != null) {
      showToast(context, l.error_required_field, error: true);
      return;
    }
```

改为：
```dart
    if (_pickedLocation == null) {
      showToast(context, '请选择场地位置', error: true);
      return;
    }
```

将 payload 中的 venue/address 字段替换。将整个 payload map：

```dart
            payload: {
              'host_id': uid,
              'venue': _venue.text.trim(),
              if (_address.text.trim().isNotEmpty)
                'address': _address.text.trim(),
              'start_at': startAt.toUtc().toIso8601String(),
```

改为：

```dart
            payload: {
              'host_id': uid,
              'venue': _pickedLocation!.name,
              'address': _pickedLocation!.address,
              'lat': _pickedLocation!.lat,
              'lng': _pickedLocation!.lng,
              'title': _title.text.trim().isNotEmpty
                  ? _title.text.trim()
                  : _generateDefaultTitle(
                      _pickedLocation!.name, startAt),
              'start_at': startAt.toUtc().toIso8601String(),
```

- [ ] **Step 5: 更新 build 方法中的表单 UI**

在 `ListView` 的 `children` 中，替换前两个 `_Field`（venue 和 address）。

将：
```dart
                  _Field(label: l.pickup_create_venue, controller: _venue),
                  _Field(
                    label: l.pickup_create_address,
                    controller: _address,
                    hint: l.pickup_create_address_hint,
                  ),
```

改为：
```dart
                  // 活动标题（选填）
                  _Field(
                    label: '活动标题',
                    controller: _title,
                    hint: '给你的约球起个标题吧',
                  ),
                  // 地点选择卡片
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label('场地位置'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _pickLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.tokens.elev2,
                              border: Border.all(color: context.tokens.line),
                              borderRadius:
                                  BorderRadius.circular(context.tokens.r2),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                  color: _pickedLocation != null
                                      ? context.tokens.accent
                                      : context.tokens.inkDim,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _pickedLocation != null
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _pickedLocation!.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: context.tokens.ink,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _pickedLocation!.address,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.tokens.inkDim,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        )
                                      : Text(
                                          '选择场地位置',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: context.tokens.inkDim,
                                          ),
                                        ),
                                ),
                                if (_pickedLocation != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _pickedLocation = null),
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: context.tokens.inkDim,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: context.tokens.inkDim,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/pickup/create_pickup_screen.dart
git commit -m "feat: add title field and location picker card to create pickup form"
```

---

### Task 9: 验证与集成测试

**Files:** 无新文件

- [ ] **Step 1: 静态分析**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: 编译检查**

Run: `flutter build apk --debug --dart-define=AMAP_KEY=320ae72b5f24ee9d84f966cb2c9ecd98`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: Commit（如有修复）**

如果分析或编译发现问题，修复后：

```bash
git add -u
git commit -m "fix: resolve analysis/build issues in location picker"
```
