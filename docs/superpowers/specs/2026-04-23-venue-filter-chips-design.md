# 场馆模式过滤 Chips 设计

## 概述

在约球地图页面（`pickup_map_screen.dart`）的场馆模式下，增加与约球模式对称的过滤 chips 栏，支持按场地类型、运动类型、价格、距离、评分等维度筛选场馆。用户可自定义显示哪些 chips。

## 目标文件

`lib/features/pickup/pickup_map_screen.dart` — 所有改动集中在此文件。

## 过滤选项定义

key 统一加 `v_` 前缀，避免与约球 filter 冲突。

| key | 标签 | 过滤逻辑 |
|-----|------|----------|
| `v_all` | 全部 | 不过滤 |
| `v_indoor` | 室内 | `fieldType == indoor` |
| `v_outdoor` | 室外 | `fieldType == outdoor` |
| `v_semi` | 半室内 | `fieldType == semi` |
| `v_football` | 足球 | `sportType == 'football'` |
| `v_basketball` | 篮球 | `sportType == 'basketball'` |
| `v_badminton` | 羽毛球 | `sportType == 'badminton'` |
| `v_free` | 免费 | `pricePerHourCents == 0` |
| `v_cheap` | 低价 | `pricePerHourCents <= 5000`（≤50元/时） |
| `v_near` | 附近 | 距离 ≤ 3.0 km（通过 `Geolocator.distanceBetween` 计算） |
| `v_rated` | 高评分 | `rating != null && rating >= 4.0` |

## 状态变量

新增两个状态变量，与约球 filter 对称：

```dart
String _venueFilter = 'v_all';

static const _defaultVisibleVenueKeys = {
  'v_all', 'v_indoor', 'v_outdoor',
  'v_football', 'v_basketball',
  'v_free', 'v_near',
};
final Set<String> _visibleVenueFilterKeys = Set.of(_defaultVisibleVenueKeys);
```

## 过滤方法

纯客户端过滤，在 `_buildMap` 中对 venues 列表应用：

```dart
List<Venue> _filterVenues(List<Venue> venues) {
  return switch (_venueFilter) {
    'v_indoor'     => venues.where((v) => v.fieldType == VenueFieldType.indoor),
    'v_outdoor'    => venues.where((v) => v.fieldType == VenueFieldType.outdoor),
    'v_semi'       => venues.where((v) => v.fieldType == VenueFieldType.semi),
    'v_football'   => venues.where((v) => v.sportType == 'football'),
    'v_basketball' => venues.where((v) => v.sportType == 'basketball'),
    'v_badminton'  => venues.where((v) => v.sportType == 'badminton'),
    'v_free'       => venues.where((v) => v.pricePerHourCents == 0),
    'v_cheap'      => venues.where((v) => v.pricePerHourCents <= 5000),
    'v_near'       => venues.where((v) {
      final m = Geolocator.distanceBetween(_userLat, _userLng, v.lat, v.lng);
      return m <= 3000;
    }),
    'v_rated'      => venues.where((v) => v.rating != null && v.rating! >= 4.0),
    _              => venues,
  }.toList();
}
```

## UI 变动

### 1. 顶部 chips 栏

当前 chips 栏被 `if (!isVenueMode)` 包裹，仅约球模式可见。改为：

- 约球模式：渲染现有的约球 chips（逻辑不变）
- 场馆模式：渲染场馆专属 chips，使用 `_venueFilter` 和 `_visibleVenueFilterKeys`

两套 chips 复用同一个 `ChipPill` widget 和相同的布局结构（`ListView.separated` + tune 按钮）。

### 2. Tune 按钮（自定义配置）

场馆模式的 tune 按钮弹出 `_showVenueFilterChipConfig`，UI 结构与 `_showFilterChipConfig` 一致：
- ModalBottomSheet
- Wrap 展示所有可选 chips（排除 `v_all`）
- 点击切换勾选状态，更新 `_visibleVenueFilterKeys`

### 3. 地图 pins

`_buildMap` 中将 `venues` 替换为过滤后的列表，地图只显示符合条件的场馆 pins。

### 4. 底部列表

底部抽屉的场馆列表和计数文案（"N 个场馆"）同样使用过滤后的列表。

### 5. 高级过滤按钮

当前场馆模式下不显示高级过滤按钮（`if (!isVenueMode)`），本次不改变此行为，chips 已覆盖主要过滤维度。

## 数据流

```
liveVenuesProvider (全量) 
  → _filterVenues() (客户端过滤)
    → filteredVenues
      → _venuesToPins() → 地图
      → SliverList → 底部列表
      → 计数文案
```

## 不涉及的改动

- 不修改 Venue 模型
- 不修改 VenuesRepository
- 不修改 providers.dart
- 不新增 l10n keys（场馆 filter 标签用硬编码中文，与场馆模式其他文案一致）
- 不涉及高级过滤弹窗（slider 形式）
