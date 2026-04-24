# 场馆模式过滤 Chips 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在约球地图页面的场馆模式下增加过滤 chips 栏（场地类型、运动、价格、距离、评分），支持用户自定义可见 chips，纯客户端过滤。

**Architecture:** 所有改动集中在 `lib/features/pickup/pickup_map_screen.dart` 的 `_PickupMapScreenState`。新增场馆专属的 filter 状态变量、过滤选项列表、过滤方法、chip 配置弹窗。UI 层将现有的 `if (!isVenueMode)` 条件改为分支渲染——约球模式和场馆模式各自渲染自己的 chips 行。地图 pins 和底部列表都使用过滤后的场馆列表。

**Tech Stack:** Flutter, Riverpod, Geolocator, 现有 ChipPill widget

**Spec:** `docs/superpowers/specs/2026-04-23-venue-filter-chips-design.md`

---

### Task 1: 新增场馆 filter 状态变量

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart:30-38`

- [ ] **Step 1: 在 `_PickupMapScreenState` 中新增状态变量**

在现有的 `_visibleFilterKeys` 声明（第 38 行）之后，添加场馆专属状态：

```dart
  // Venue filter state (symmetric to pickup filter).
  String _venueFilter = 'v_all';
  static const _defaultVisibleVenueKeys = {
    'v_all', 'v_indoor', 'v_outdoor',
    'v_football', 'v_basketball',
    'v_free', 'v_near',
  };
  final Set<String> _visibleVenueFilterKeys = Set.of(_defaultVisibleVenueKeys);
```

- [ ] **Step 2: 验证编译通过**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/pickup_map_screen.dart 2>&1 | tail -5`
Expected: No errors (warnings OK)

- [ ] **Step 3: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup): add venue filter state variables"
```

---

### Task 2: 添加场馆过滤选项列表和过滤方法

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart:162-180` (after existing `_visibleFilterOptions`)

- [ ] **Step 1: 添加 `_allVenueFilterOptions` 方法**

在 `_visibleFilterOptions` 方法（第 176-180 行）之后添加：

```dart
  List<(String, String)> _allVenueFilterOptions() {
    return const [
      ('v_all', '全部'),
      ('v_indoor', '室内'),
      ('v_outdoor', '室外'),
      ('v_semi', '半室内'),
      ('v_football', '足球'),
      ('v_basketball', '篮球'),
      ('v_badminton', '羽毛球'),
      ('v_free', '免费'),
      ('v_cheap', '低价'),
      ('v_near', '附近'),
      ('v_rated', '高评分'),
    ];
  }

  List<(String, String)> _visibleVenueFilterOptions() {
    return _allVenueFilterOptions()
        .where((f) => f.$1 == 'v_all' || _visibleVenueFilterKeys.contains(f.$1))
        .toList();
  }
```

- [ ] **Step 2: 添加 `_filterVenues` 方法**

在 `_visibleVenueFilterOptions` 之后添加：

```dart
  List<Venue> _filterVenues(List<Venue> venues) {
    return switch (_venueFilter) {
      'v_indoor' => venues.where((v) => v.fieldType == VenueFieldType.indoor),
      'v_outdoor' => venues.where((v) => v.fieldType == VenueFieldType.outdoor),
      'v_semi' => venues.where((v) => v.fieldType == VenueFieldType.semi),
      'v_football' => venues.where((v) => v.sportType == 'football'),
      'v_basketball' => venues.where((v) => v.sportType == 'basketball'),
      'v_badminton' => venues.where((v) => v.sportType == 'badminton'),
      'v_free' => venues.where((v) => v.pricePerHourCents == 0),
      'v_cheap' => venues.where((v) => v.pricePerHourCents <= 5000),
      'v_near' => venues.where((v) {
        final m = Geolocator.distanceBetween(_userLat, _userLng, v.lat, v.lng);
        return m <= 3000;
      }),
      'v_rated' => venues.where((v) => v.rating != null && v.rating! >= 4.0),
      _ => venues,
    }.toList();
  }
```

- [ ] **Step 3: 验证编译通过**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/pickup_map_screen.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup): add venue filter options list and filtering method"
```

---

### Task 3: 添加场馆 chip 配置弹窗

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart:273` (after existing `_showFilterChipConfig`)

- [ ] **Step 1: 添加 `_showVenueFilterChipConfig` 方法**

在 `_showFilterChipConfig` 方法的闭合花括号（第 273 行）之后添加。此方法与 `_showFilterChipConfig` 结构一致，但操作 `_visibleVenueFilterKeys` 和 `_allVenueFilterOptions`：

```dart
  void _showVenueFilterChipConfig(BuildContext context) {
    final allOptions = _allVenueFilterOptions();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.tokens.inkMute,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '场馆筛选配置',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allOptions.where((f) => f.$1 != 'v_all').map((f) {
                      final selected = _visibleVenueFilterKeys.contains(f.$1);
                      return GestureDetector(
                        onTap: () {
                          setModal(() {
                            setState(() {
                              if (selected) {
                                _visibleVenueFilterKeys.remove(f.$1);
                              } else {
                                _visibleVenueFilterKeys.add(f.$1);
                              }
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? context.tokens.accentSubtle : context.tokens.elev2,
                            border: Border.all(
                              color: selected ? context.tokens.accent : context.tokens.line,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                Icon(Icons.check, size: 14, color: context.tokens.accent),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                f.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? context.tokens.accent : context.tokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 2: 验证编译通过**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/pickup_map_screen.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup): add venue filter chip config bottom sheet"
```

---

### Task 4: 改造顶部 chips 栏——场馆/约球分支渲染

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart:592-635`

- [ ] **Step 1: 替换 `if (!isVenueMode)` 块为分支渲染**

将第 592-635 行（从 `const SizedBox(height: 10),` 到 chips Builder 块结束）替换为：

```dart
                  const SizedBox(height: 10),
                  Builder(
                    builder: (ctx) {
                      final filters = isVenueMode
                          ? _visibleVenueFilterOptions()
                          : _visibleFilterOptions(ctx);
                      final activeKey = isVenueMode ? _venueFilter : _filter;
                      return SizedBox(
                        height: 28,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: filters.length,
                                separatorBuilder: (_, i) => const SizedBox(width: 6),
                                itemBuilder: (_, i) {
                                  final f = filters[i];
                                  return ChipPill(
                                    label: f.$2,
                                    active: f.$1 == activeKey,
                                    onTap: () => setState(() {
                                      if (isVenueMode) {
                                        _venueFilter = f.$1;
                                      } else {
                                        _filter = f.$1;
                                      }
                                    }),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => isVenueMode
                                  ? _showVenueFilterChipConfig(ctx)
                                  : _showFilterChipConfig(ctx),
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: context.tokens.elev2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.tokens.line),
                                ),
                                child: Icon(Icons.tune, size: 14, color: context.tokens.inkSub),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
```

- [ ] **Step 2: 验证编译通过**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/pickup_map_screen.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup): render venue filter chips in venue mode"
```

---

### Task 5: 将过滤应用到地图 pins 和底部列表

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart:500-502, 509-510, 757, 792-801`

- [ ] **Step 1: 在 `_buildMap` 开头应用过滤**

在第 501 行 `final isVenueMode = _mode == _MapMode.venue;` 之后添加一行：

```dart
    final filteredVenues = isVenueMode ? _filterVenues(venues) : venues;
```

- [ ] **Step 2: 替换地图 pins 中的 `venues` 为 `filteredVenues`**

将第 510 行：
```dart
              extraPins: isVenueMode ? _venuesToPins(venues) : const [],
```
改为：
```dart
              extraPins: isVenueMode ? _venuesToPins(filteredVenues) : const [],
```

- [ ] **Step 3: 更新底部计数文案**

将第 757 行：
```dart
                                    ? '${venues.length} 个场馆'
```
改为：
```dart
                                    ? '${filteredVenues.length} 个场馆'
```

- [ ] **Step 4: 更新底部列表数据源**

将第 792-801 行的场馆 SliverList 中所有 `venues[i]` 和 `venues.length` 替换为 `filteredVenues[i]` 和 `filteredVenues.length`：

```dart
                  if (isVenueMode)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _VenueListRow(
                          venue: filteredVenues[i],
                          distanceKm: _distanceToPoint(filteredVenues[i].lat, filteredVenues[i].lng),
                          onTap: () => context.push('/venue/${filteredVenues[i].id}'),
                        ),
                        childCount: filteredVenues.length,
                      ),
                    )
```

- [ ] **Step 5: 验证编译通过**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/pickup_map_screen.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup): apply venue filter to map pins and bottom list"
```

---

### Task 6: 更新浮动卡片数据源

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart:843-855`

- [ ] **Step 1: 更新浮动卡片中的 venue 查找**

在浮动卡片的 Builder 中（约第 843 行），将 `venues.where` 改为 `filteredVenues.where`：

```dart
                        final venue = _activePin != null
                            ? filteredVenues.where((v) => v.id == _activePin).firstOrNull
                            : null;
```

注意：如果用户点击了某个 pin 后切换了 filter 导致该 venue 不在过滤结果中，`venue` 会变成 `null`，卡片自动消失——这是期望行为。

- [ ] **Step 2: 验证编译通过**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/pickup_map_screen.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup): update venue floating card to use filtered list"
```

---

### Task 7: 全量编译验证

**Files:**
- None (verification only)

- [ ] **Step 1: 全项目编译检查**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze 2>&1 | tail -10`
Expected: No errors related to pickup_map_screen.dart

- [ ] **Step 2: 冒烟测试（如有设备/模拟器）**

在场馆模式下验证：
1. Chips 栏显示：全部、室内、室外、足球、篮球、免费、附近
2. 点击各 chip 切换高亮，列表和地图 pins 跟随过滤
3. 点击 tune 按钮弹出配置弹窗，可勾选/取消勾选 chips
4. 切回约球模式，约球 chips 正常工作不受影响
5. 切回场馆模式，之前选的场馆 filter 保持

- [ ] **Step 3: 最终 Commit（如有修正）**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "fix(pickup): address venue filter review findings"
```
