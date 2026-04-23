# Map Marker Bubble Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace default AMap red pin markers with custom bubble-label markers that display pickup price (e.g. "¥30"), colored by status (green=open, orange=almost, grey=full), with a triangle pointer at the bottom.

**Architecture:** Create a `MarkerBubblePainter` (`CustomPainter`) that draws the bubble shape + text. For AMap mobile, render the widget offscreen to PNG bytes via `RepaintBoundary.toImage()` and use `BitmapDescriptor.fromBytes()`. For web stub, render the same painter directly as a `CustomPaint` widget. Cache rendered bitmaps by key to avoid redundant rendering.

**Tech Stack:** Flutter CustomPainter, `dart:ui` for offscreen rendering, `amap_map` BitmapDescriptor

**Spec:** `docs/superpowers/specs/2026-04-23-map-marker-bubble-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/features/pickup/map/marker_painter.dart` | Create | `MarkerBubblePainter` CustomPainter + `renderMarkerBitmap()` async function + bitmap cache |
| `lib/features/pickup/map/real_map_mobile.dart` | Modify | Use custom BitmapDescriptor icons from `renderMarkerBitmap()` instead of default markers |
| `lib/features/pickup/map/real_map_stub.dart` | Modify | Replace `_Pin` circle+icon with `CustomPaint(painter: MarkerBubblePainter(...))` |

---

### Task 1: Create `MarkerBubblePainter` and `renderMarkerBitmap`

**Files:**
- Create: `lib/features/pickup/map/marker_painter.dart`

- [ ] **Step 1: Create the `MarkerBubblePainter` CustomPainter**

Create `lib/features/pickup/map/marker_painter.dart` with the full painter:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MarkerBubblePainter extends CustomPainter {
  final String text;
  final Color bgColor;
  final bool active;

  const MarkerBubblePainter({
    required this.text,
    required this.bgColor,
    this.active = false,
  });

  static const double _height = 28;
  static const double _triSize = 6;
  static const double _radius = 6;
  static const double _hPad = 10;
  static const double _fontSize = 12;

  /// Measure total width based on text.
  double get _textWidth {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  double get totalWidth => _textWidth + _hPad * 2;
  double get totalHeight => _height + _triSize;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bgPaint = Paint()..color = bgColor;

    // Draw glow for active state.
    if (active) {
      final glowPaint = Paint()
        ..color = bgColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final glowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, _height),
        const Radius.circular(_radius),
      );
      canvas.drawRRect(glowRect, glowPaint);
    }

    // Rounded rectangle body.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, _height),
      const Radius.circular(_radius),
    );
    canvas.drawRRect(bodyRect, bgPaint);

    // Bottom triangle.
    final triPath = Path()
      ..moveTo(w / 2 - _triSize, _height)
      ..lineTo(w / 2, _height + _triSize)
      ..lineTo(w / 2 + _triSize, _height)
      ..close();
    canvas.drawPath(triPath, bgPaint);

    // White text centered.
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((_hPad), (_height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant MarkerBubblePainter old) =>
      old.text != text || old.bgColor != bgColor || old.active != active;
}
```

- [ ] **Step 2: Add `renderMarkerBitmap` function and cache**

Append to the same file, after the `MarkerBubblePainter` class:

```dart
final Map<String, Uint8List> _bytesCache = {};

Future<Uint8List> renderMarkerBitmap({
  required String text,
  required Color bgColor,
  bool active = false,
}) async {
  final key = '$text|${bgColor.toARGB32()}|$active';
  final cached = _bytesCache[key];
  if (cached != null) return cached;

  final painter = MarkerBubblePainter(
    text: text,
    bgColor: bgColor,
    active: active,
  );

  final scale = active ? 1.2 : 1.0;
  final w = painter.totalWidth * scale;
  final h = painter.totalHeight * scale;
  final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  final pixelW = (w * dpr).ceil();
  final pixelH = (h * dpr).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(dpr * scale);
  painter.paint(canvas, Size(painter.totalWidth, painter.totalHeight));
  final picture = recorder.endRecording();

  final image = await picture.toImage(pixelW, pixelH);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();

  final bytes = byteData!.buffer.asUint8List();
  _bytesCache[key] = bytes;
  return bytes;
}
```

- [ ] **Step 3: Verify file compiles**

Run: `/home/coder/flutter/bin/flutter analyze lib/features/pickup/map/marker_painter.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/pickup/map/marker_painter.dart
git commit -m "feat(pickup-map): add MarkerBubblePainter and renderMarkerBitmap"
```

---

### Task 2: Use custom bitmap markers in AMap mobile

**Files:**
- Modify: `lib/features/pickup/map/real_map_mobile.dart`

- [ ] **Step 1: Add imports and state for marker icons**

At the top of `real_map_mobile.dart`, add the import:

```dart
import 'dart:typed_data';
import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:x_amap_base/x_amap_base.dart';

import '../../../models/map_pin.dart';
import '../../../models/pickup.dart';
import 'marker_painter.dart';
```

Add state field to `_RealPickupMapState`:

```dart
class _RealPickupMapState extends State<RealPickupMap> {
  AMapController? _controller;
  LatLng? _userLocation;
  bool _initialLocateDone = false;
  bool _pendingLocate = false;
  Map<String, BitmapDescriptor> _markerIcons = {};
```

- [ ] **Step 2: Add `_renderAllIcons` method and wire lifecycle**

Add this method to `_RealPickupMapState`, after the `_flyToUser` method:

```dart
  Future<void> _renderAllIcons() async {
    if (!mounted) return;
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
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
```

Wire lifecycle — add `initState` and update `didUpdateWidget`:

```dart
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
```

- [ ] **Step 3: Update `_buildMarkers` to use custom icons**

Replace the existing `_buildMarkers` method:

```dart
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
```

- [ ] **Step 4: Verify compilation**

Run: `/home/coder/flutter/bin/flutter analyze lib/features/pickup/map/real_map_mobile.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/pickup/map/real_map_mobile.dart
git commit -m "feat(pickup-map): use custom bubble bitmap markers on AMap"
```

---

### Task 3: Update web stub pins to use bubble label

**Files:**
- Modify: `lib/features/pickup/map/real_map_stub.dart`

- [ ] **Step 1: Add import for marker_painter**

Add at the top of `real_map_stub.dart`:

```dart
import 'marker_painter.dart';
```

Remove the now-unused `sport_icon.dart` import:

```dart
// DELETE: import '../../../widgets/sport_icon.dart';
```

- [ ] **Step 2: Replace `_Pin` widget build method**

Replace the entire `build` method of `_Pin` (lines 104-161):

```dart
  @override
  Widget build(BuildContext context) {
    final lngRaw = pickup.lng ?? 0.5;
    final latRaw = pickup.lat ?? 0.5;
    final (normX, normY) = _normalise(lngRaw, latRaw);
    final x = normX * size.width;
    final y = normY * (size.height * 0.7) + 120;

    final statusColor = switch (pickup.status) {
      PickupStatus.full => context.tokens.inkMute,
      PickupStatus.almost => context.tokens.warn,
      _ => context.tokens.accent,
    };

    final text = '¥${pickup.feeYuan.toStringAsFixed(0)}';
    final painter = MarkerBubblePainter(
      text: text,
      bgColor: statusColor,
      active: isActive,
    );
    final scale = isActive ? 1.2 : 1.0;
    final w = painter.totalWidth * scale;
    final h = painter.totalHeight * scale;

    return Positioned(
      left: x - w / 2,
      top: y - h,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: w,
          height: h,
          child: CustomPaint(
            painter: painter,
            size: Size(painter.totalWidth, painter.totalHeight),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Verify compilation**

Run: `/home/coder/flutter/bin/flutter analyze lib/features/pickup/map/real_map_stub.dart 2>&1 | tail -5`
Expected: No errors (or info-level only)

- [ ] **Step 4: Commit**

```bash
git add lib/features/pickup/map/real_map_stub.dart
git commit -m "feat(pickup-map): use bubble label markers in web stub"
```

---

### Task 4: Verify full project and smoke test

- [ ] **Step 1: Analyze entire pickup feature**

Run: `/home/coder/flutter/bin/flutter analyze lib/features/pickup/ 2>&1 | tail -10`
Expected: No errors

- [ ] **Step 2: Manual verification on device/emulator**

1. Navigate to 约球 tab (pickup map)
2. Verify markers show as bubble labels with price text (e.g. "¥30", "¥50")
3. Verify colors: green for open, orange for almost full, grey for full
4. Verify bubble has rounded rectangle body + bottom triangle pointer
5. Tap a marker → floating card appears (existing behavior preserved)
6. Verify active marker appears slightly larger (1.2x scale + glow)
7. Verify extraPins (venue markers) still use default marker style

- [ ] **Step 3: Final commit if touch-ups needed**

```bash
git add -A
git commit -m "fix(pickup-map): touch-up bubble markers after smoke test"
```
