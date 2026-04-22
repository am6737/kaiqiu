# Pickup Map Floating Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user taps a map pin on the pickup screen, show a floating card at the bottom of the screen with pickup details; tapping the card navigates to the pickup detail page.

**Architecture:** Modify the existing `PickupMapScreen` to show an animated floating card (`_PickupFloatingCard`) when `_activePin` is set, instead of expanding the bottom sheet. Add `onMapTap` callback to both map implementations (AMap mobile + web stub) so tapping empty map space dismisses the card.

**Tech Stack:** Flutter, AMap (`amap_map` 1.0.15), Riverpod, go_router

**Spec:** `docs/superpowers/specs/2026-04-22-pickup-map-floating-card-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/features/pickup/map/real_map_mobile.dart` | Modify | Add `onMapTap` callback, wire to AMapWidget's `onTap` |
| `lib/features/pickup/map/real_map_stub.dart` | Modify | Add `onMapTap` callback, wire to GestureDetector on background |
| `lib/features/pickup/pickup_map_screen.dart` | Modify | Add `_PickupFloatingCard` widget, rewire `onPinTap`/dismiss logic, add card to Stack |

---

### Task 1: Add `onMapTap` to AMap mobile implementation

**Files:**
- Modify: `lib/features/pickup/map/real_map_mobile.dart:13-35` (widget params) and `:75-109` (build method)

- [ ] **Step 1: Add `onMapTap` parameter to `RealPickupMap`**

In `lib/features/pickup/map/real_map_mobile.dart`, add the new parameter to the widget class:

```dart
class RealPickupMap extends StatefulWidget {
  final List<Pickup> pickups;
  final String? activePinId;
  final ValueChanged<String> onPinTap;
  final VoidCallback? onLocateMe;
  final double? centerLat;
  final double? centerLng;
  final int locateTrigger;
  final ValueChanged<LatLng>? onUserLocationChanged;
  final VoidCallback? onMapPanned;
  final VoidCallback? onMapTap;  // ← ADD

  const RealPickupMap({
    super.key,
    required this.pickups,
    required this.onPinTap,
    this.activePinId,
    this.onLocateMe,
    this.centerLat,
    this.centerLng,
    this.locateTrigger = 0,
    this.onUserLocationChanged,
    this.onMapPanned,
    this.onMapTap,  // ← ADD
  });
```

- [ ] **Step 2: Wire `onTap` in the `AMapWidget`**

In the `build` method, add `onTap` to the `AMapWidget` constructor:

```dart
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
```

- [ ] **Step 3: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/map/real_map_mobile.dart 2>&1 | tail -5`
Expected: No errors (warnings about unused imports are OK)

- [ ] **Step 4: Commit**

```bash
git add lib/features/pickup/map/real_map_mobile.dart
git commit -m "feat(pickup-map): add onMapTap callback to AMap mobile implementation"
```

---

### Task 2: Add `onMapTap` to web stub implementation

**Files:**
- Modify: `lib/features/pickup/map/real_map_stub.dart:19-40` (widget params) and `:44-74` (build method)

- [ ] **Step 1: Add `onMapTap` parameter to web `RealPickupMap`**

In `lib/features/pickup/map/real_map_stub.dart`, add the parameter:

```dart
class RealPickupMap extends StatelessWidget {
  final List<Pickup> pickups;
  final String? activePinId;
  final ValueChanged<String> onPinTap;
  final VoidCallback? onLocateMe;
  final double? centerLat;
  final double? centerLng;
  final int locateTrigger;
  final dynamic onUserLocationChanged;
  final VoidCallback? onMapPanned;
  final VoidCallback? onMapTap;  // ← ADD

  const RealPickupMap({
    super.key,
    required this.pickups,
    required this.onPinTap,
    this.activePinId,
    this.onLocateMe,
    this.centerLat,
    this.centerLng,
    this.locateTrigger = 0,
    this.onUserLocationChanged,
    this.onMapPanned,
    this.onMapTap,  // ← ADD
  });
```

- [ ] **Step 2: Wrap the background container with GestureDetector**

In the `build` method, wrap the first `Container` (the map background) with a `GestureDetector`:

```dart
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapBg     = isDark ? const Color(0xFF0E1310) : const Color(0xFFE8EDE9);
    final mapPark   = isDark ? const Color(0xFF142219) : const Color(0xFFC8E0D0);
    final mapStreet = isDark ? const Color(0xFF1D2A24) : const Color(0xFFD8DCD9);
    final mapRiver  = isDark ? const Color(0xFF13212B) : const Color(0xFFB8D4E2);
    return GestureDetector(
      onTap: onMapTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: mapBg,
            child: CustomPaint(
              painter: _MapStubPainter(
                parkColor:   mapPark,
                streetColor: mapStreet,
                riverColor:  mapRiver,
                bgColor:     mapBg,
              ),
            ),
          ),
          for (final p in pickups)
            _Pin(
              pickup: p,
              size: size,
              isActive: activePinId == p.id,
              onTap: () => onPinTap(p.id),
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 3: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/map/real_map_stub.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/pickup/map/real_map_stub.dart
git commit -m "feat(pickup-map): add onMapTap callback to web stub implementation"
```

---

### Task 3: Add `_PickupFloatingCard` widget and rewire interactions

**Files:**
- Modify: `lib/features/pickup/pickup_map_screen.dart`

This is the main task. It has three sub-parts: (A) add the card widget, (B) rewire onPinTap/dismiss logic, (C) add the card to the Stack with animation.

- [ ] **Step 1: Add `_PickupFloatingCard` widget class at the end of the file**

Add this class after the existing `_MapListRow` class (after line 734):

```dart
class _PickupFloatingCard extends StatelessWidget {
  final Pickup pickup;
  final String? distanceKm;
  final VoidCallback onTap;
  const _PickupFloatingCard({
    super.key,
    required this.pickup,
    this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final need = pickup.displayNeed;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.elev2,
          borderRadius: BorderRadius.circular(t.r3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Venue photo or sport icon placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: pickup.venuePhotoUrl != null
                  ? Image.network(
                      pickup.venuePhotoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(t),
                    )
                  : _placeholder(t),
            ),
            const SizedBox(width: 10),
            // Info columns
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pickup.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [pickup.displayTime, pickup.formation]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(fontSize: 11, color: t.inkSub),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '¥${pickup.feeYuan.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: t.inkSub),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me, size: 10, color: t.inkMute),
                        const SizedBox(width: 2),
                        Text(
                          '${distanceKm}km',
                          style: TextStyle(fontSize: 11, color: t.inkMute),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge + chevron
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _badge(t, need),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 18, color: t.inkMute),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppTokens t) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.elev3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SportIcon(Sport.football, size: 22, color: t.inkSub),
    );
  }

  Widget _badge(AppTokens t, int needed) {
    final Color bg, fg;
    final String text;
    if (needed > 2) {
      bg = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      fg = const Color(0xFF4CAF50);
      text = '有位';
    } else if (needed > 0) {
      bg = t.warn.withValues(alpha: 0.15);
      fg = t.warn;
      text = '快满了';
    } else {
      bg = t.inkMute.withValues(alpha: 0.15);
      fg = t.inkMute;
      text = '已满';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
```

- [ ] **Step 2: Add `_dismissCard()` method to `_PickupMapScreenState`**

Add this method after the existing `_distanceTo` method (after line 113):

```dart
  void _dismissCard() {
    if (_activePin == null) return;
    setState(() => _activePin = null);
    _sheetCtrl.animateTo(
      0.55,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
```

- [ ] **Step 3: Rewire `onPinTap` in `_buildMap`**

Replace the existing `onPinTap` handler (lines 359-366) in the `RealPickupMap` constructor inside `_buildMap`:

Old:
```dart
              onPinTap: (id) {
                setState(() => _activePin = id);
                _sheetCtrl.animateTo(
                  0.55,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
```

New:
```dart
              onPinTap: (id) {
                setState(() => _activePin = id);
                final minSize = 80 / MediaQuery.of(context).size.height;
                _sheetCtrl.animateTo(
                  minSize,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              onMapTap: _dismissCard,
```

- [ ] **Step 4: Add floating card to the Stack in `_buildMap`**

Insert the animated floating card into the `Stack` children, **after** the `DraggableScrollableSheet` (after the closing of the sheet block around line 589) and before the closing `],` of the Stack. Also wire `onMapPanned` to dismiss:

Find the existing `onMapPanned` callback:
```dart
              onMapPanned: () {
                if (mounted && _mapCentered) {
                  setState(() => _mapCentered = false);
                }
              },
```

Replace with:
```dart
              onMapPanned: () {
                if (mounted && _mapCentered) {
                  setState(() => _mapCentered = false);
                }
                _dismissCard();
              },
```

Then add the floating card widget before the closing `],` of the Stack's children (just before line 592's `],`):

```dart
          // Floating pickup card
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: AnimatedSlide(
              offset: _activePin != null ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _activePin != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: _activePin == null,
                  child: Builder(
                    builder: (context) {
                      final pickup = _activePin != null
                          ? pickups.cast<Pickup?>().firstWhere(
                              (p) => p!.id == _activePin,
                              orElse: () => null,
                            )
                          : null;
                      if (pickup == null) return const SizedBox.shrink();
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _PickupFloatingCard(
                          key: ValueKey(pickup.id),
                          pickup: pickup,
                          distanceKm: _distanceTo(pickup),
                          onTap: () => context.push('/pickup/${pickup.id}'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
```

- [ ] **Step 5: Add sheet listener to dismiss card when user drags sheet up**

In `initState`, after `_acquireLocation();`, add a listener to `_sheetCtrl`:

```dart
  @override
  void initState() {
    super.initState();
    _acquireLocation();
    _sheetCtrl.addListener(_onSheetChanged);
  }
```

Add the listener method after `_dismissCard()`:

```dart
  void _onSheetChanged() {
    if (!_sheetCtrl.isAttached) return;
    final minSize = 80 / MediaQuery.of(context).size.height;
    if (_activePin != null && _sheetCtrl.size > minSize + 0.01) {
      setState(() => _activePin = null);
    }
  }
```

Update `dispose` to remove the listener:

```dart
  @override
  void dispose() {
    _sheetCtrl.removeListener(_onSheetChanged);
    _sheetCtrl.dispose();
    super.dispose();
  }
```

- [ ] **Step 6: Verify full project compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/pickup/ 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/pickup/pickup_map_screen.dart
git commit -m "feat(pickup-map): add floating card on pin tap with animated show/dismiss"
```

---

### Task 4: Smoke test on device / emulator

- [ ] **Step 1: Build and launch**

Run: `cd /home/coder/workspaces/qiuju_app && flutter run`

- [ ] **Step 2: Manual verification checklist**

Test each interaction from the spec:

1. Navigate to 约球 tab (pickup map)
2. Tap a pin → verify bottom sheet collapses, floating card appears with slide-up animation
3. Verify card shows: venue photo (or placeholder), venue name, time, formation, fee, distance, status badge, chevron
4. Tap the floating card → verify navigation to `/pickup/:id` detail screen
5. Go back to map, tap a pin again → card appears
6. Tap empty map space → card disappears with slide-down animation, bottom sheet restores to 55%
7. Tap a pin → card appears → tap a different pin → card content switches to new pickup
8. Tap a pin → card appears → drag map → card disappears
9. Tap a pin → card appears → pull bottom sheet up → card disappears

- [ ] **Step 3: Final commit (if any touch-ups needed)**

```bash
git add -A
git commit -m "fix(pickup-map): touch-up floating card after smoke test"
```
