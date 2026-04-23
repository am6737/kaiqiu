# 赛事创建：地图选择场地

## 概述

将赛事创建流程中的场地选择从文本输入改为地图选择，复用约球/场馆共用的 `LocationPickerScreen`。同时在赛事详情页展示场地地址和导航按钮。

## 涉及文件

| 文件 | 改动类型 |
|------|---------|
| `supabase/migrations/0001_schema.sql` | 修改：events 表新增 address/lat/lng 列 |
| `lib/models/event.dart` | 修改：Event 类新增 address/lat/lng 字段 |
| `lib/features/create_event/step_basic_info.dart` | 修改：文本输入 → 地图选择器 |
| `lib/features/create_event/create_event_screen.dart` | 修改：状态管理和提交逻辑 |
| `lib/features/create_event/step_preview.dart` | 修改：预览展示地址 |
| `lib/features/events/panels/overview_panel.dart` | 修改：新增场地+导航区块 |

## 1. 数据库

`events` 表新增 3 列：

```sql
address text,
lat double precision,
lng double precision
```

不新建迁移文件，直接在 `0001_schema.sql` 中修改 `create table public.events` 语句。

## 2. Dart 模型 — Event

`lib/models/event.dart` 中 `Event` 类新增：

```dart
final String? address;
final double? lat;
final double? lng;
```

`fromMap` 中解析：

```dart
address: m['address'] as String?,
lat: (m['lat'] as num?)?.toDouble(),
lng: (m['lng'] as num?)?.toDouble(),
```

构造函数新增对应可选参数。

## 3. 创建页面 — StepBasicInfo

### 接口变更

移除 `venueController` 参数，替换为：

```dart
final PickedLocation? pickedLocation;
final VoidCallback onPickLocation;
final VoidCallback onClearLocation;
final String? venueError;
```

### UI 实现

将原来的 `EventField(label: '场地', controller: venueController)` 替换为可点击的位置选择容器，交互方式与 `create_pickup_screen.dart` 第 208-293 行完全一致：

- **未选择状态**：location_on_outlined 图标（inkDim 色）+ "选择赛事场地" 占位文字 + chevron_right 图标
- **已选择状态**：location_on_outlined 图标（accent 色）+ 场地名称（14px，ink，w500）+ 地址（12px，inkDim）+ close 清除按钮
- **错误状态**：容器 border 变红，下方显示 errorText

容器样式：`elev2` 背景，`line` 边框，`r2` 圆角，内边距 12px。

## 4. 创建页面 — CreateEventScreen

### 状态变更

```dart
// 移除
final _venue = TextEditingController();

// 新增
PickedLocation? _pickedLocation;
```

同步从 `dispose()` 中移除 `_venue`。

### _pickLocation 方法

新增方法，与约球创建中的实现一致：

```dart
Future<void> _pickLocation() async {
  final result = await Navigator.of(context).push<PickedLocation>(
    MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
  );
  if (result != null && mounted) {
    setState(() => _pickedLocation = result);
  }
}
```

### 验证逻辑

`_validateStep` 中第 2 步的场地验证从：

```dart
if (_venue.text.trim().isEmpty) errors['venue'] = l.validation_venue_required;
```

改为：

```dart
if (_pickedLocation == null) errors['venue'] = l.validation_venue_required;
```

### 提交逻辑

`_submitImpl` 中 payload 调整：

```dart
'sub': _pickedLocation?.name,
'address': _pickedLocation?.address,
'lat': _pickedLocation?.lat,
'lng': _pickedLocation?.lng,
```

### StepBasicInfo 调用

```dart
StepBasicInfo(
  nameController: _name,
  startDate: _startDate,
  endDate: _endDate,
  pickedLocation: _pickedLocation,
  onPickLocation: _pickLocation,
  onClearLocation: () => setState(() => _pickedLocation = null),
  feeController: _fee,
  prizeController: _prize,
  errors: _errors,
  onPickStart: ...,
  onPickEnd: ...,
),
```

### 编辑模式

`_loadEvent` 中，如果已有赛事包含位置数据，恢复 `_pickedLocation`：

```dart
if (event.lat != null && event.lng != null) {
  _pickedLocation = PickedLocation(
    name: event.sub ?? '',
    address: event.address ?? '',
    lat: event.lat!,
    lng: event.lng!,
  );
}
```

如果是历史赛事只有 `sub` 没有坐标，不设置 `_pickedLocation`，允许用户重新通过地图选择。

### StepPreview 调用

```dart
StepPreview(
  ...
  venueName: _pickedLocation?.name ?? '',
  venueAddress: _pickedLocation?.address,
  ...
),
```

## 5. 预览页面 — StepPreview

新增 `venueAddress` 可选参数。预览卡片中 `$tplName · $venueName` 行下方可追加一行地址（如果有）：

```dart
if (venueAddress != null && venueAddress!.isNotEmpty)
  Text(
    venueAddress!,
    style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
```

`configOk` 检查从 `venueName.trim().isNotEmpty` 改为判断 `venueName` 非空即可（地图选出来的名称不会为空）。

## 6. 赛事详情页 — OverviewPanel

在"规则"区块和"组织方"区块之间新增"赛事场地"区块。

### 布局

```dart
// 在规则 SizedBox(height: 10) 之后，组织方 Label 之前
if (event.sub != null && event.sub!.isNotEmpty) ...[
  Label('赛事场地'),  // 需添加 l10n key
  const SizedBox(height: 10),
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.tokens.elev2,
      border: Border.all(color: context.tokens.line),
      borderRadius: BorderRadius.circular(context.tokens.r2),
    ),
    child: Row(
      children: [
        Icon(Icons.near_me, size: 14, color: context.tokens.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _locationText,  // venue · address
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _canNavigate ? () => _openNav(context) : null,
          child: Text('导航'),  // 需添加 l10n key，复用 pickup_detail_navigate
        ),
      ],
    ),
  ),
  const SizedBox(height: 14),
],
```

### 导航

调用 `MapLauncher.openNavigation(context: context, lat: event.lat!, lng: event.lng!, name: event.sub!)`。

需要新增 import：`package:qiuju_app/services/map_launcher.dart`。

### 向后兼容

如果 `event.lat == null || event.lng == null`（历史赛事无坐标），导航按钮禁用，仅展示文字。

## 7. 不需要改动的部分

- `LocationPickerScreen` — 直接复用，无需修改
- `PickedLocation` 模型 — 直接复用
- `AmapSearchService` — 直接复用
- `MapLauncher` — 直接复用
- 数据库 RLS 策略 — 新字段继承现有 events 表策略，无需额外配置
