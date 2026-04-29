# City Picker Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the CityPickerScreen with GPS auto-locate, search, recent cities, and region-grouped city list with sidebar index.

**Architecture:** The page stays a full-screen Scaffold pushed via `/city-picker`. City data moves from two flat `List<String>` to a structured `CityInfo` list grouped by geographic region. LocalStore gains a `recentCities` field. GPS matching uses Haversine distance against pre-set city coordinates — no new dependencies.

**Tech Stack:** Flutter, Riverpod, geolocator (existing), SharedPreferences (existing), go_router (existing)

---

### Task 1: Add `recentCities` to LocalStore

**Files:**
- Modify: `lib/services/local_storage.dart` (after line 143, the city section)

- [ ] **Step 1: Add the key constant**

In `lib/services/local_storage.dart`, add after the existing `_kCity` constant (line 22):

```dart
const _kRecentCities = 'recent_cities';
```

- [ ] **Step 2: Add the getter and setter**

In `lib/services/local_storage.dart`, add inside the `LocalStore` class, right after the `setCity` method (after line 143):

```dart
  // ─── recent cities
  static List<String> get recentCities =>
      _prefs.getStringList(_kRecentCities) ?? <String>[];

  static Future<void> addRecentCity(String city) async {
    final list = recentCities;
    list.remove(city);
    list.insert(0, city);
    while (list.length > 5) {
      list.removeLast();
    }
    await _prefs.setStringList(_kRecentCities, list);
    localStoreNotifier.bump();
  }
```

- [ ] **Step 3: Wire into setCity so recent list auto-updates**

Modify the existing `setCity` method to also record the city in recent history. Replace the `setCity` method:

```dart
  static Future<void> setCity(String city) async {
    await _prefs.setString(_kCity, city);
    await addRecentCity(city);
    localStoreNotifier.bump();
  }
```

- [ ] **Step 4: Verify the app still compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/services/local_storage.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/services/local_storage.dart
git commit -m "feat(city-picker): add recentCities to LocalStore"
```

---

### Task 2: Add l10n strings for new UI elements

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add Chinese l10n strings**

In `lib/l10n/app_zh.arb`, find the existing `city_picker_*` entries (around line 680) and replace/extend them to:

```json
  "city_picker_title": "选择城市",
  "city_picker_hot": "热门城市",
  "city_picker_all": "全部城市",
  "city_picker_current": "当前定位",
  "city_picker_recent": "最近使用",
  "city_picker_search_hint": "搜索城市名称或拼音",
  "city_picker_gps_located": "GPS 已定位",
  "city_picker_gps_locating": "正在定位...",
  "city_picker_gps_failed": "定位失败，点击重试",
  "city_picker_gps_not_supported": "当前城市暂未开通",
  "city_picker_gps_use": "使用此城市",
  "city_picker_current_label": "当前",
  "city_picker_no_result": "没有找到匹配的城市",
```

- [ ] **Step 2: Add English l10n strings**

In `lib/l10n/app_en.arb`, find the existing `city_picker_*` entries (around line 680) and replace/extend them to:

```json
  "city_picker_title": "Choose city",
  "city_picker_hot": "Popular",
  "city_picker_all": "All cities",
  "city_picker_current": "Current location",
  "city_picker_recent": "Recent",
  "city_picker_search_hint": "Search city name or pinyin",
  "city_picker_gps_located": "GPS located",
  "city_picker_gps_locating": "Locating...",
  "city_picker_gps_failed": "Location failed, tap to retry",
  "city_picker_gps_not_supported": "City not supported yet",
  "city_picker_gps_use": "Use this city",
  "city_picker_current_label": "Current",
  "city_picker_no_result": "No matching city found",
```

- [ ] **Step 3: Regenerate l10n**

Run: `cd /home/coder/workspaces/qiuju_app && flutter gen-l10n`
Expected: Files in `lib/l10n/generated/` regenerated without errors

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/generated/
git commit -m "feat(city-picker): add l10n strings for redesigned city picker"
```

---

### Task 3: Create city data model and Haversine helper

**Files:**
- Create: `lib/features/home/city_data.dart`

This file contains the `CityInfo` class, the full city dataset grouped by region, the hot cities list, and the Haversine nearest-city function.

- [ ] **Step 1: Create the file with CityInfo and Haversine**

Create `lib/features/home/city_data.dart`:

```dart
import 'dart:math';

class CityInfo {
  final String name;
  final String province;
  final String pinyin;
  final String region;
  final double lat;
  final double lng;

  const CityInfo({
    required this.name,
    required this.province,
    required this.pinyin,
    required this.region,
    required this.lat,
    required this.lng,
  });
}

const kRegionOrder = ['华北', '华东', '华南', '华中', '西南', '西北', '东北'];

const kHotCityNames = [
  '北京', '上海', '广州', '深圳', '杭州', '成都',
  '武汉', '西安', '南京', '重庆', '苏州', '天津',
];

const kAllCities = <CityInfo>[
  // ── 华北
  CityInfo(name: '北京', province: '直辖市', pinyin: 'beijing', region: '华北', lat: 39.9042, lng: 116.4074),
  CityInfo(name: '天津', province: '直辖市', pinyin: 'tianjin', region: '华北', lat: 39.0842, lng: 117.2010),
  CityInfo(name: '石家庄', province: '河北', pinyin: 'shijiazhuang', region: '华北', lat: 38.0428, lng: 114.5149),
  CityInfo(name: '太原', province: '山西', pinyin: 'taiyuan', region: '华北', lat: 37.8706, lng: 112.5489),
  CityInfo(name: '呼和浩特', province: '内蒙古', pinyin: 'huhehaote', region: '华北', lat: 40.8414, lng: 111.7500),
  // ── 华东
  CityInfo(name: '上海', province: '直辖市', pinyin: 'shanghai', region: '华东', lat: 31.2304, lng: 121.4737),
  CityInfo(name: '南京', province: '江苏', pinyin: 'nanjing', region: '华东', lat: 32.0603, lng: 118.7969),
  CityInfo(name: '苏州', province: '江苏', pinyin: 'suzhou', region: '华东', lat: 31.2990, lng: 120.5853),
  CityInfo(name: '杭州', province: '浙江', pinyin: 'hangzhou', region: '华东', lat: 30.2741, lng: 120.1551),
  CityInfo(name: '合肥', province: '安徽', pinyin: 'hefei', region: '华东', lat: 31.8206, lng: 117.2272),
  CityInfo(name: '福州', province: '福建', pinyin: 'fuzhou', region: '华东', lat: 26.0745, lng: 119.2965),
  CityInfo(name: '厦门', province: '福建', pinyin: 'xiamen', region: '华东', lat: 24.4798, lng: 118.0894),
  CityInfo(name: '济南', province: '山东', pinyin: 'jinan', region: '华东', lat: 36.6512, lng: 117.1201),
  CityInfo(name: '青岛', province: '山东', pinyin: 'qingdao', region: '华东', lat: 36.0671, lng: 120.3826),
  // ── 华南
  CityInfo(name: '广州', province: '广东', pinyin: 'guangzhou', region: '华南', lat: 23.1291, lng: 113.2644),
  CityInfo(name: '深圳', province: '广东', pinyin: 'shenzhen', region: '华南', lat: 22.5431, lng: 114.0579),
  CityInfo(name: '南宁', province: '广西', pinyin: 'nanning', region: '华南', lat: 22.8170, lng: 108.3665),
  CityInfo(name: '海口', province: '海南', pinyin: 'haikou', region: '华南', lat: 20.0440, lng: 110.1999),
  CityInfo(name: '三亚', province: '海南', pinyin: 'sanya', region: '华南', lat: 18.2528, lng: 109.5120),
  // ── 华中
  CityInfo(name: '武汉', province: '湖北', pinyin: 'wuhan', region: '华中', lat: 30.5928, lng: 114.3055),
  CityInfo(name: '长沙', province: '湖南', pinyin: 'changsha', region: '华中', lat: 28.2282, lng: 112.9388),
  CityInfo(name: '郑州', province: '河南', pinyin: 'zhengzhou', region: '华中', lat: 34.7466, lng: 113.6254),
  // ── 西南
  CityInfo(name: '重庆', province: '直辖市', pinyin: 'chongqing', region: '西南', lat: 29.4316, lng: 106.9123),
  CityInfo(name: '成都', province: '四川', pinyin: 'chengdu', region: '西南', lat: 30.5728, lng: 104.0668),
  CityInfo(name: '贵阳', province: '贵州', pinyin: 'guiyang', region: '西南', lat: 26.6470, lng: 106.6302),
  CityInfo(name: '昆明', province: '云南', pinyin: 'kunming', region: '西南', lat: 25.0389, lng: 102.7183),
  CityInfo(name: '拉萨', province: '西藏', pinyin: 'lasa', region: '西南', lat: 29.6500, lng: 91.1000),
  // ── 西北
  CityInfo(name: '西安', province: '陕西', pinyin: "xi'an", region: '西北', lat: 34.3416, lng: 108.9398),
  CityInfo(name: '兰州', province: '甘肃', pinyin: 'lanzhou', region: '西北', lat: 36.0611, lng: 103.8343),
  CityInfo(name: '西宁', province: '青海', pinyin: 'xining', region: '西北', lat: 36.6171, lng: 101.7782),
  CityInfo(name: '银川', province: '宁夏', pinyin: 'yinchuan', region: '西北', lat: 38.4872, lng: 106.2309),
  CityInfo(name: '乌鲁木齐', province: '新疆', pinyin: 'wulumuqi', region: '西北', lat: 43.8256, lng: 87.6168),
  // ── 东北
  CityInfo(name: '沈阳', province: '辽宁', pinyin: 'shenyang', region: '东北', lat: 41.8057, lng: 123.4315),
  CityInfo(name: '大连', province: '辽宁', pinyin: 'dalian', region: '东北', lat: 38.9140, lng: 121.6147),
  CityInfo(name: '长春', province: '吉林', pinyin: 'changchun', region: '东北', lat: 43.8171, lng: 125.3235),
  CityInfo(name: '哈尔滨', province: '黑龙江', pinyin: 'haerbin', region: '东北', lat: 45.8038, lng: 126.5350),
];

/// Group [kAllCities] by region, preserving [kRegionOrder].
Map<String, List<CityInfo>> get citiesByRegion {
  final map = <String, List<CityInfo>>{};
  for (final r in kRegionOrder) {
    map[r] = kAllCities.where((c) => c.region == r).toList();
  }
  return map;
}

/// Search cities by Chinese name or pinyin prefix.
List<CityInfo> searchCities(String query) {
  if (query.isEmpty) return [];
  final q = query.toLowerCase();
  return kAllCities.where((c) {
    return c.name.contains(query) || c.pinyin.toLowerCase().startsWith(q);
  }).toList();
}

/// Find the nearest supported city to the given coordinates.
/// Returns null if the nearest city is more than [maxDistanceKm] away.
CityInfo? findNearestCity(double lat, double lng, {double maxDistanceKm = 100}) {
  CityInfo? best;
  double bestDist = double.infinity;
  for (final city in kAllCities) {
    final d = _haversineKm(lat, lng, city.lat, city.lng);
    if (d < bestDist) {
      bestDist = d;
      best = city;
    }
  }
  if (bestDist > maxDistanceKm) return null;
  return best;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/home/city_data.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/city_data.dart
git commit -m "feat(city-picker): add CityInfo data model, city dataset, and Haversine helper"
```

---

### Task 4: Rewrite CityPickerScreen — scaffold, GPS card, and search box

**Files:**
- Modify: `lib/features/home/city_picker_screen.dart` (full rewrite)

This task builds the page skeleton with GPS card and search. Tasks 5-6 complete the remaining sections.

- [ ] **Step 1: Rewrite the file**

Replace the entire contents of `lib/features/home/city_picker_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../services/local_storage.dart';
import '../../services/location.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';
import 'city_data.dart';

class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';

  // GPS state
  bool _gpsLoading = true;
  CityInfo? _gpsCity;
  bool _gpsFailed = false;

  // Region keys for scroll-to
  final _regionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    for (final r in kRegionOrder) {
      _regionKeys[r] = GlobalKey();
    }
    _locateCity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _locateCity() async {
    setState(() {
      _gpsLoading = true;
      _gpsFailed = false;
      _gpsCity = null;
    });
    final pos = await LocationService().currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _gpsLoading = false;
        _gpsFailed = true;
      });
      return;
    }
    final city = findNearestCity(pos.latitude, pos.longitude);
    setState(() {
      _gpsLoading = false;
      _gpsCity = city;
      _gpsFailed = false;
    });
  }

  Future<void> _pick(String city) async {
    await LocalStore.setCity(city);
    if (mounted) context.pop();
  }

  void _scrollToRegion(String region) {
    final key = _regionKeys[region];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = LocalStore.city;
    final searchResults = searchCities(_query);
    final isSearching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 40, right: 40),
              children: [
                PageTitleBar(
                  title: l.city_picker_title,
                  onBack: () => context.pop(),
                ),
                // ② GPS card
                _GpsCard(
                  loading: _gpsLoading,
                  city: _gpsCity,
                  failed: _gpsFailed,
                  onUse: () {
                    if (_gpsCity != null) _pick(_gpsCity!.name);
                  },
                  onRetry: _locateCity,
                ),
                const SizedBox(height: 14),
                // ③ Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: l.city_picker_search_hint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: isSearching
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: context.tokens.elev2,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (isSearching) ...[
                  // Search results
                  if (searchResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          l.city_picker_no_result,
                          style: TextStyle(color: context.tokens.inkSub, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    for (final c in searchResults)
                      _CityRow(
                        city: c,
                        active: c.name == current,
                        currentLabel: l.city_picker_current_label,
                        onTap: () => _pick(c.name),
                      ),
                ] else ...[
                  // ④ Recent cities
                  _RecentSection(
                    current: current,
                    onPick: _pick,
                  ),
                  // ⑤ Hot cities
                  SectionHeader(title: l.city_picker_hot),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in kHotCityNames)
                          _CityChip(
                            label: name,
                            active: name == current,
                            onTap: () => _pick(name),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ⑥ All cities by region
                  for (final region in kRegionOrder) ...[
                    _RegionHeader(key: _regionKeys[region], title: region),
                    for (final c in citiesByRegion[region]!)
                      _CityRow(
                        city: c,
                        active: c.name == current,
                        currentLabel: l.city_picker_current_label,
                        onTap: () => _pick(c.name),
                      ),
                  ],
                ],
              ],
            ),

            // ⑦ Region index sidebar (only when not searching)
            if (!isSearching)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _RegionIndexBar(
                  regions: kRegionOrder,
                  onTap: _scrollToRegion,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// GPS Card
// ──────────────────────────────────────────────────────────────

class _GpsCard extends StatelessWidget {
  final bool loading;
  final CityInfo? city;
  final bool failed;
  final VoidCallback onUse;
  final VoidCallback onRetry;

  const _GpsCard({
    required this.loading,
    required this.city,
    required this.failed,
    required this.onUse,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isGrey = failed || (city == null && !loading);

    return GestureDetector(
      onTap: failed ? onRetry : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isGrey
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [context.tokens.accent, context.tokens.accent.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (!isGrey)
              BoxShadow(
                color: context.tokens.accent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status line
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: loading
                              ? Colors.amber
                              : failed
                                  ? Colors.grey.shade300
                                  : const Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        loading
                            ? l.city_picker_gps_locating
                            : failed
                                ? l.city_picker_gps_failed
                                : l.city_picker_gps_located,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // City name or loading
                  if (loading)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (city != null) ...[
                    Text(
                      city!.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      city!.province,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ] else
                    Text(
                      failed ? l.city_picker_gps_failed : l.city_picker_gps_not_supported,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            if (!loading && city != null)
              GestureDetector(
                onTap: onUse,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l.city_picker_gps_use,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Recent Section
// ──────────────────────────────────────────────────────────────

class _RecentSection extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPick;

  const _RecentSection({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recent = LocalStore.recentCities.where((c) => c != current).take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.city_picker_recent),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in recent)
                _CityChip(
                  label: name,
                  active: false,
                  onTap: () => onPick(name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Region header
// ──────────────────────────────────────────────────────────────

class _RegionHeader extends StatelessWidget {
  final String title;

  const _RegionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.tokens.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(height: 1, color: context.tokens.line),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// City row (for all-cities list and search results)
// ──────────────────────────────────────────────────────────────

class _CityRow extends StatelessWidget {
  final CityInfo city;
  final bool active;
  final String currentLabel;
  final VoidCallback onTap;

  const _CityRow({
    required this.city,
    required this.active,
    required this.currentLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                city.name,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? context.tokens.accent : context.tokens.ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.accentSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                city.province,
                style: TextStyle(
                  fontSize: 12,
                  color: context.tokens.inkSub,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// City chip (for hot cities and recent cities)
// ──────────────────────────────────────────────────────────────

class _CityChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CityChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : context.tokens.elev2,
          border: Border.all(
            color: active ? context.tokens.accent : context.tokens.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? context.tokens.accent : context.tokens.ink,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Region index sidebar
// ──────────────────────────────────────────────────────────────

class _RegionIndexBar extends StatelessWidget {
  final List<String> regions;
  final ValueChanged<String> onTap;

  const _RegionIndexBar({required this.regions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: context.tokens.elev2.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in regions)
              GestureDetector(
                onTap: () => onTap(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.accent,
                    ),
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

- [ ] **Step 2: Verify the app compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/home/city_picker_screen.dart`
Expected: No errors (or only warnings unrelated to this file)

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/city_picker_screen.dart
git commit -m "feat(city-picker): rewrite CityPickerScreen with GPS, search, recent, region groups, and index sidebar"
```

---

### Task 5: Smoke test in browser

**Files:** None (manual verification)

- [ ] **Step 1: Start the dev server**

Run: `cd /home/coder/workspaces/qiuju_app && flutter run -d chrome --web-port 8080`

- [ ] **Step 2: Test golden path**

Open browser, navigate to the app, tap the city name in the top-left of the home screen. Verify:

1. Page opens with title "选择城市"
2. GPS card appears at the top (may show loading then located or failed)
3. Search box is visible below GPS card
4. Recent cities section shows if there are previous selections (hidden on first use)
5. Hot cities section shows 12 cities as chips
6. All cities section shows 7 region groups with correct cities
7. Right sidebar shows region index
8. Tapping a city selects it and pops back to home
9. Home screen top-left updates to show the newly selected city

- [ ] **Step 3: Test search**

1. Type "nan" in search box — should show 南京, 南宁
2. Type "杭" in search box — should show 杭州
3. Clear search — should restore full layout
4. Type "zzz" — should show "没有找到匹配的城市"

- [ ] **Step 4: Test region index**

1. Tap "东北" in the sidebar — should scroll to the 东北 section
2. Tap "华南" — should scroll to 华南 section

- [ ] **Step 5: Fix any issues found and commit**

```bash
git add -u
git commit -m "fix(city-picker): polish after smoke test"
```

---

### Task 6: Final cleanup and verify no regressions

**Files:** None

- [ ] **Step 1: Run full analyzer**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze`
Expected: No new errors introduced

- [ ] **Step 2: Verify home screen still works**

After selecting a city, verify:
1. Home screen `_TopBar` shows the selected city name
2. Tapping the city name re-opens the picker
3. The picker shows the correct current city as highlighted

- [ ] **Step 3: Final commit if any cleanup**

```bash
git add -u
git commit -m "chore(city-picker): final cleanup"
```
