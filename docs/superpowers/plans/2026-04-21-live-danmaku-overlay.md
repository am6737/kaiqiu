# 赛事直播弹幕叠层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `wc_live_screen.dart` 的视频播放器之上叠加一层 B 站风格的横向滚动弹幕;用户发送和 bot 生成的消息同时流向弹幕轨道和下方气泡列表;提供弹幕开关并持久化;全屏模式同样支持。

**Architecture:** 新增可复用的 `DanmakuOverlay` 控件,订阅 `Stream<DanmakuItem>`,用多个 `AnimationController`(每条弹幕一个)在 4 条固定轨道上从右向左匀速飘过。视频页持有一个 `StreamController<DanmakuItem>.broadcast()`,在原有 `_send()` / bot timer 中同步派发到 stream 和 `_danmus` 列表。视频容器用 `Stack` 将 `LiveStreamPlayer` 与 `DanmakuOverlay`(包 `IgnorePointer`)叠加,不影响原有手势。

**Tech Stack:** Flutter 3.x, Dart 3.11.5, `flutter_riverpod`, `shared_preferences`, 项目自有 `AppTokens`(`context.tokens.*`),`flutter_test`。

**Spec:** `docs/superpowers/specs/2026-04-21-live-danmaku-overlay-design.md`

---

## File Structure

**新增文件:**

| 路径 | 职责 |
|---|---|
| `lib/widgets/danmaku_overlay.dart` | `DanmakuItem` 数据类 + `DanmakuOverlay` StatefulWidget(多轨道调度 + 飘动动画) |
| `test/widgets/danmaku_overlay_test.dart` | 控件单元测试 |
| `test/services/local_storage_danmaku_test.dart` | 持久化字段测试 |
| `test/features/events/wc_live_screen_test.dart` | 页面集成测试 |

**修改文件:**

| 路径 | 变更 |
|---|---|
| `lib/services/local_storage.dart` | 新增 `_kDanmakuEnabled` key 与 `danmakuEnabled` / `setDanmakuEnabled` |
| `lib/features/events/wc_live_screen.dart` | 新增 `StreamController` 与 `_pushDanmu`,视频外层改 `Stack`,`topRight` 并排 `_DanmakuToggleButton` + `_ReminderButton`,全屏路由传 stream |
| `lib/widgets/live_stream_player.dart` | `_LiveFullscreenRoute` 新增 `danmakuStream` / `danmakuEnabled` 构造参数并在全屏 Stack 中叠加 `DanmakuOverlay` |
| `lib/l10n/app_zh.arb` | 新增 `wc_btn_danmaku_on` / `wc_btn_danmaku_off` |
| `lib/l10n/app_en.arb` | 同上 |

---

## Task 1: 持久化字段 `danmakuEnabled`

**Files:**
- Modify: `lib/services/local_storage.dart`
- Test: `test/services/local_storage_danmaku_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/local_storage_danmaku_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/services/local_storage.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  test('danmakuEnabled defaults to true', () {
    expect(LocalStore.danmakuEnabled, true);
  });

  test('setDanmakuEnabled persists false then true', () async {
    await LocalStore.setDanmakuEnabled(false);
    expect(LocalStore.danmakuEnabled, false);
    await LocalStore.setDanmakuEnabled(true);
    expect(LocalStore.danmakuEnabled, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/local_storage_danmaku_test.dart`
Expected: FAIL — `LocalStore.danmakuEnabled` / `setDanmakuEnabled` not defined.

- [ ] **Step 3: Implement persistence**

Modify `lib/services/local_storage.dart`:

After the existing line `const _kThemeSeed = 'theme_seed';`, add:

```dart
const _kDanmakuEnabled = 'danmaku_enabled';
```

In `class LocalStore`, after the `notifMatchReminder` block (around line 179, before `// ─── search history (last 10)`), add:

```dart
  // ─── live danmaku overlay
  static bool get danmakuEnabled => _prefs.getBool(_kDanmakuEnabled) ?? true;
  static Future<void> setDanmakuEnabled(bool v) async {
    await _prefs.setBool(_kDanmakuEnabled, v);
    localStoreNotifier.bump();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/local_storage_danmaku_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/local_storage.dart test/services/local_storage_danmaku_test.dart
git commit -m "feat(local-storage): persist danmaku overlay enabled flag"
```

---

## Task 2: `DanmakuItem` 数据类

**Files:**
- Create: `lib/widgets/danmaku_overlay.dart`
- Test: `test/widgets/danmaku_overlay_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/danmaku_overlay_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/widgets/danmaku_overlay.dart';

void main() {
  group('DanmakuItem', () {
    test('stores user, text, self', () {
      const item = DanmakuItem(user: 'Alice', text: 'gg', self: true);
      expect(item.user, 'Alice');
      expect(item.text, 'gg');
      expect(item.self, true);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: FAIL — `DanmakuItem` / file not found.

- [ ] **Step 3: Create `DanmakuItem`**

Create `lib/widgets/danmaku_overlay.dart`:

```dart
// danmaku_overlay.dart — B 站风格的直播弹幕叠层控件。
//
// 订阅一个 [Stream<DanmakuItem>],在固定轨道上从右向左匀速飘过文字。
// 与视频播放器叠加使用,外层需包 [IgnorePointer] 以免截获手势。

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 一条弹幕的数据载体。
class DanmakuItem {
  final String user;
  final String text;
  final bool self;
  const DanmakuItem({
    required this.user,
    required this.text,
    required this.self,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/danmaku_overlay.dart test/widgets/danmaku_overlay_test.dart
git commit -m "feat(danmaku): add DanmakuItem data class"
```

---

## Task 3: `DanmakuOverlay` 控件骨架(仅渲染订阅到的第一条)

**Files:**
- Modify: `lib/widgets/danmaku_overlay.dart`
- Test: `test/widgets/danmaku_overlay_test.dart`

- [ ] **Step 1: Write the failing test**

Replace the full contents of `test/widgets/danmaku_overlay_test.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiqiu_app/theme/app_tokens.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';
import 'package:kaiqiu_app/widgets/danmaku_overlay.dart';

Widget _wrap(Widget child) {
  // Use the project's real theme so context.tokens works.
  final ctrl = ThemeController();
  return MaterialApp(
    theme: ctrl.lightTheme,
    darkTheme: ctrl.darkTheme,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 240,
        child: child,
      ),
    ),
  );
}

void main() {
  group('DanmakuItem', () {
    test('stores user, text, self', () {
      const item = DanmakuItem(user: 'Alice', text: 'gg', self: true);
      expect(item.user, 'Alice');
      expect(item.text, 'gg');
      expect(item.self, true);
    });
  });

  group('DanmakuOverlay', () {
    testWidgets('renders a danmu pushed onto its stream', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      ctrl.add(const DanmakuItem(user: 'A', text: 'hello-world', self: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('hello-world'), findsOneWidget);

      // Let animations finish so the widget tree is clean on dispose.
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: FAIL — `DanmakuOverlay` not defined.

- [ ] **Step 3: Implement `DanmakuOverlay` with single-track rendering**

Replace `lib/widgets/danmaku_overlay.dart` with:

```dart
// danmaku_overlay.dart — B 站风格的直播弹幕叠层控件。
//
// 订阅一个 [Stream<DanmakuItem>],在固定轨道上从右向左匀速飘过文字。
// 与视频播放器叠加使用,外层需包 [IgnorePointer] 以免截获手势。

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class DanmakuItem {
  final String user;
  final String text;
  final bool self;
  const DanmakuItem({
    required this.user,
    required this.text,
    required this.self,
  });
}

class DanmakuOverlay extends StatefulWidget {
  final Stream<DanmakuItem> stream;
  final bool enabled;
  final int trackCount;
  final Duration speed;
  const DanmakuOverlay({
    super.key,
    required this.stream,
    this.enabled = true,
    this.trackCount = 4,
    this.speed = const Duration(seconds: 8),
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _ActiveDanmu {
  final DanmakuItem item;
  final int track;
  final AnimationController controller;
  double width = 0; // measured on first layout, 0 means "not yet measured".
  _ActiveDanmu({
    required this.item,
    required this.track,
    required this.controller,
  });
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<DanmakuItem>? _sub;
  final List<_ActiveDanmu> _active = [];

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_onItem);
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final d in _active) {
      d.controller.dispose();
    }
    _active.clear();
    super.dispose();
  }

  void _onItem(DanmakuItem item) {
    if (!widget.enabled) return;
    if (!mounted) return;
    final c = AnimationController(vsync: this, duration: widget.speed);
    final active = _ActiveDanmu(item: item, track: 0, controller: c);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _active.remove(active);
        });
        c.dispose();
      }
    });
    setState(() {
      _active.add(active);
    });
    c.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final d in _active)
              AnimatedBuilder(
                animation: d.controller,
                builder: (context, child) {
                  // x goes from w (off-screen right) to -d.width (off-screen left).
                  final x = w - (w + d.width) * d.controller.value;
                  return Positioned(
                    left: x,
                    top: 12.0 + d.track * 28.0,
                    child: child!,
                  );
                },
                child: _DanmuText(
                  item: d.item,
                  onMeasured: (width) => d.width = width,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DanmuText extends StatelessWidget {
  final DanmakuItem item;
  final ValueChanged<double> onMeasured;
  const _DanmuText({required this.item, required this.onMeasured});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: item.self ? t.accent : Colors.white,
      shadows: const [
        Shadow(color: Color(0xAA000000), blurRadius: 2, offset: Offset(1, 1)),
      ],
    );
    final textWidget = Text(item.text, style: base);
    final child = item.self
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.accentSubtle,
              border: Border.all(color: t.accent, width: 1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: textWidget,
          )
        : textWidget;
    return _MeasureSize(onMeasured: onMeasured, child: child);
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onMeasured;
  const _MeasureSize({required this.child, required this.onMeasured});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        widget.onMeasured(box.size.width);
      }
    });
    return Container(key: _key, child: widget.child);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/danmaku_overlay.dart test/widgets/danmaku_overlay_test.dart
git commit -m "feat(danmaku): render a single danmu from stream"
```

---

## Task 4: 多轨道调度 + 追尾丢弃

**Files:**
- Modify: `lib/widgets/danmaku_overlay.dart`
- Test: `test/widgets/danmaku_overlay_test.dart`

- [ ] **Step 1: Write the failing test**

Append two test cases to the `group('DanmakuOverlay', ...)` in `test/widgets/danmaku_overlay_test.dart`:

```dart
    testWidgets('4 danmus land on 4 distinct tracks', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        ctrl.add(DanmakuItem(user: 'U$i', text: 'msg$i', self: false));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      final positions = <double>{};
      for (var i = 0; i < 4; i++) {
        final f = find.text('msg$i');
        expect(f, findsOneWidget);
        final rect = tester.getRect(f);
        positions.add(rect.top.roundToDouble());
      }
      expect(positions.length, 4, reason: 'each danmu on its own track');

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('5th danmu is dropped when all tracks busy', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        ctrl.add(DanmakuItem(user: 'U$i', text: 'msg$i', self: false));
        await tester.pump();
      }
      // Immediately push a 5th; no track has freed up yet.
      ctrl.add(const DanmakuItem(user: 'X', text: 'dropped', self: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('dropped'), findsNothing);

      await tester.pump(const Duration(seconds: 10));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: FAIL — 4 danmus currently all land on track 0 (same `top`); 5th one still renders.

- [ ] **Step 3: Implement track scheduling**

In `lib/widgets/danmaku_overlay.dart`, modify `_onItem` and track layout so that:
- A new item picks the track whose **last active danmu's right edge is furthest from the right edge of the overlay** (= most space behind the tail).
- "Right edge" of an active danmu = `x_position + width`. Using the formula `x = w - (w + d.width) * t`, the right edge is `x + d.width = w - (w - 0) * t` (for width-aware case, simpler to track by "time since entry").
- If any track is empty, pick that (lowest index among empties).
- If every track's last entry still has `t < (d.width / (w + d.width))` (i.e. tail not fully inside), drop the item.

Replace the `_onItem` method and the tracking in `_ActiveDanmu` / build:

```dart
  int? _pickTrack(double overlayWidth) {
    // Group active danmus by track, take latest per track.
    final latestByTrack = <int, _ActiveDanmu>{};
    for (final d in _active) {
      final prev = latestByTrack[d.track];
      if (prev == null || d.controller.value < prev.controller.value) {
        // The one with the smaller progress (= just entered) is the "latest".
        latestByTrack[d.track] = d;
      }
    }

    // Empty tracks first.
    for (var i = 0; i < widget.trackCount; i++) {
      if (!latestByTrack.containsKey(i)) return i;
    }

    // Otherwise pick the track whose latest entry's tail is furthest past the right edge.
    // tail position = x + width = overlayWidth - (overlayWidth + width) * t + width
    //               = overlayWidth + width - (overlayWidth + width) * t
    //               = (overlayWidth + width) * (1 - t) - (overlayWidth - width) ... keep simple:
    // We want max of "how far left the tail has moved from right edge"
    //   = overlayWidth - (x + width) = (overlayWidth + width) * t - width
    int? best;
    double bestScore = -double.infinity;
    latestByTrack.forEach((track, d) {
      final tailLeftOfRight = (overlayWidth + d.width) * d.controller.value - d.width;
      if (tailLeftOfRight > bestScore) {
        bestScore = tailLeftOfRight;
        best = track;
      }
    });
    // If the best track's tail hasn't cleared the right edge yet, drop.
    if (bestScore <= 0) return null;
    return best;
  }

  void _onItem(DanmakuItem item) {
    if (!widget.enabled) return;
    if (!mounted) return;
    final rb = context.findRenderObject() as RenderBox?;
    final overlayWidth = rb?.hasSize == true ? rb!.size.width : 400.0;
    final track = _pickTrack(overlayWidth);
    if (track == null) return; // all tracks busy — drop.
    final c = AnimationController(vsync: this, duration: widget.speed);
    final active = _ActiveDanmu(item: item, track: track, controller: c);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _active.remove(active);
        });
        c.dispose();
      }
    });
    setState(() {
      _active.add(active);
    });
    c.forward();
  }
```

Note: the `top` formula in `build` already uses `d.track`, so multiple tracks render at different y positions. No change needed in `build`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/danmaku_overlay.dart test/widgets/danmaku_overlay_test.dart
git commit -m "feat(danmaku): schedule across 4 tracks, drop on congestion"
```

---

## Task 5: 有效弹幕区位置约束 + `enabled` 开关

**Files:**
- Modify: `lib/widgets/danmaku_overlay.dart`
- Test: `test/widgets/danmaku_overlay_test.dart`

- [ ] **Step 1: Write the failing test**

Append to the `group('DanmakuOverlay', ...)`:

```dart
    testWidgets('enabled: false drops incoming danmus', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(
        DanmakuOverlay(stream: ctrl.stream, enabled: false),
      ));
      await tester.pump();

      ctrl.add(const DanmakuItem(user: 'A', text: 'silenced', self: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('silenced'), findsNothing);
    });

    testWidgets('danmus render inside [80, height-40] region', (tester) async {
      final ctrl = StreamController<DanmakuItem>.broadcast();
      addTearDown(ctrl.close);

      await tester.pumpWidget(_wrap(DanmakuOverlay(stream: ctrl.stream)));
      await tester.pump();

      for (var i = 0; i < 4; i++) {
        ctrl.add(DanmakuItem(user: 'U$i', text: 'msg$i', self: false));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 50));

      for (var i = 0; i < 4; i++) {
        final r = tester.getRect(find.text('msg$i'));
        // Overlay is 240 tall; effective region [80, 200].
        expect(r.top, greaterThanOrEqualTo(80.0 - 0.5));
        expect(r.bottom, lessThanOrEqualTo(200.0 + 0.5));
      }

      await tester.pump(const Duration(seconds: 10));
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: FAIL — current `top = 12 + track * 28` starts at 12, not 80. `enabled: false` already covered in Task 3's `_onItem`, but test confirms.

- [ ] **Step 3: Implement effective-region layout**

In `lib/widgets/danmaku_overlay.dart`, replace the `build` method's `AnimatedBuilder` `top` calculation:

```dart
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const topInset = 80.0;
        const bottomInset = 40.0;
        const trackHeight = 28.0;
        final usable = (h - topInset - bottomInset).clamp(
          trackHeight,
          double.infinity,
        );
        final trackGap = widget.trackCount <= 1
            ? 0.0
            : (usable - trackHeight) / (widget.trackCount - 1);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final d in _active)
              AnimatedBuilder(
                animation: d.controller,
                builder: (context, child) {
                  final x = w - (w + d.width) * d.controller.value;
                  final y = topInset + d.track * trackGap;
                  return Positioned(
                    left: x,
                    top: y,
                    child: child!,
                  );
                },
                child: _DanmuText(
                  item: d.item,
                  onMeasured: (width) => d.width = width,
                ),
              ),
          ],
        );
      },
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/danmaku_overlay_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/danmaku_overlay.dart test/widgets/danmaku_overlay_test.dart
git commit -m "feat(danmaku): constrain tracks to effective region; honor enabled flag"
```

---

## Task 6: l10n 文案

**Files:**
- Modify: `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`

- [ ] **Step 1: Add Chinese keys**

In `lib/l10n/app_zh.arb`, after the line `"wc_btn_remind": "提醒",`, insert:

```json
  "wc_btn_danmaku_on": "弹幕 开",
  "wc_btn_danmaku_off": "弹幕 关",
```

- [ ] **Step 2: Add English keys**

In `lib/l10n/app_en.arb`, after the line `"wc_btn_remind": "Remind",`, insert:

```json
  "wc_btn_danmaku_on": "Danmaku On",
  "wc_btn_danmaku_off": "Danmaku Off",
```

- [ ] **Step 3: Regenerate l10n and verify**

Run: `flutter gen-l10n` (or `flutter pub run intl_utils:generate` — project uses `l10n.yaml` + `flutter gen-l10n`).

Run: `flutter analyze lib/l10n/generated`
Expected: No issues — new getters `l.wc_btn_danmaku_on` / `.wc_btn_danmaku_off` exist.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated
git commit -m "i18n: add danmaku toggle labels"
```

---

## Task 7: `wc_live_screen.dart` — 引入 stream + 抽出 `_pushDanmu`

**Files:**
- Modify: `lib/features/events/wc_live_screen.dart`

- [ ] **Step 1: Add imports and StreamController**

In `lib/features/events/wc_live_screen.dart`, the file already imports `dart:async`. Add:

```dart
import '../../widgets/danmaku_overlay.dart';
```

(Insert near other `widgets/` imports around line 13-17.)

- [ ] **Step 2: Add state fields**

In `_WcLiveScreenState`, just after `late Timer _tickTimer;` (~line 30), add:

```dart
  final StreamController<DanmakuItem> _danmuController =
      StreamController<DanmakuItem>.broadcast();
  late bool _danmakuOn = LocalStore.danmakuEnabled;
```

- [ ] **Step 3: Close controller in dispose**

In the existing `dispose` method, before `super.dispose();`, add:

```dart
    _danmuController.close();
```

- [ ] **Step 4: Add `_pushDanmu` helper**

Between `dispose` and `_send`, add:

```dart
  void _pushDanmu(_Danmu d) {
    setState(() {
      _danmus.insert(0, d);
      if (_danmus.length > 40) _danmus.removeLast();
    });
    _danmuController.add(
      DanmakuItem(user: d.user, text: d.text, self: d.self),
    );
  }
```

- [ ] **Step 5: Refactor `_send` to use `_pushDanmu`**

Replace the body of `_send` with:

```dart
  void _send() {
    final t = _inputC.text.trim();
    if (t.isEmpty) return;
    _pushDanmu(_Danmu(user: 'You', text: t, at: DateTime.now(), self: true));
    _inputC.clear();
  }
```

- [ ] **Step 6: Refactor bot timer to use `_pushDanmu`**

In `initState`, replace the `if (r.nextInt(3) == 0) { _danmus.insert(0, _Danmu(...)); if (_danmus.length > 40) _danmus.removeLast(); }` block inside the `setState` callback with a plain statement outside of setState but still inside the timer:

Before:
```dart
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _viewers += r.nextInt(50) - 10;
        if (_viewers < 0) _viewers = 0;
        _minute = (_minute + 1).clamp(0, 90);
        if (r.nextInt(60) == 0) {
          if (r.nextBool()) {
            _scoreA++;
          } else {
            _scoreB++;
          }
        }
        if (r.nextInt(3) == 0) {
          _danmus.insert(
            0,
            _Danmu(
              user: _botNames[r.nextInt(_botNames.length)],
              text: _botMessages[r.nextInt(_botMessages.length)],
              at: DateTime.now(),
              self: false,
            ),
          );
          if (_danmus.length > 40) _danmus.removeLast();
        }
      });
    });
```

After:
```dart
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _viewers += r.nextInt(50) - 10;
        if (_viewers < 0) _viewers = 0;
        _minute = (_minute + 1).clamp(0, 90);
        if (r.nextInt(60) == 0) {
          if (r.nextBool()) {
            _scoreA++;
          } else {
            _scoreB++;
          }
        }
      });
      if (r.nextInt(3) == 0) {
        _pushDanmu(
          _Danmu(
            user: _botNames[r.nextInt(_botNames.length)],
            text: _botMessages[r.nextInt(_botMessages.length)],
            at: DateTime.now(),
            self: false,
          ),
        );
      }
    });
```

- [ ] **Step 7: Run existing tests + analyze**

Run: `flutter analyze lib/features/events/wc_live_screen.dart`
Expected: No issues.

Run: `flutter test` (full suite — make sure nothing regressed).
Expected: All existing tests still pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/events/wc_live_screen.dart
git commit -m "refactor(wc-live): centralize danmu dispatch through StreamController"
```

---

## Task 8: `wc_live_screen.dart` — 视频层 Stack 叠加 DanmakuOverlay

**Files:**
- Modify: `lib/features/events/wc_live_screen.dart`

- [ ] **Step 1: Wrap `LiveStreamPlayer` in a `Stack`**

In the `build` method of `_WcLiveScreenState`, find the `LiveStreamPlayer(...)` child inside the outer `Column` (around line 163). Replace it with:

```dart
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  LiveStreamPlayer(
                    height: 240,
                    scoreOverlay: scoreOverlay,
                    topLeft: _BackButton(onTap: () => context.pop()),
                    topRight: _ReminderButton(
                      hasReminder: hasReminder,
                      label: l.wc_btn_remind,
                      onTap: () => _showReminderSheet(context),
                    ),
                    bottomLeftOverlay: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LivePill(),
                        const SizedBox(width: 6),
                        Label('$_minute\'', color: Colors.white),
                      ],
                    ),
                    bottomRightOverlay: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.remove_red_eye,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.wc_live_viewer_count(viewerStr),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DanmakuOverlay(
                        stream: _danmuController.stream,
                        enabled: _danmakuOn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
```

Delete the original standalone `LiveStreamPlayer(...)` block it replaced.

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/features/events/wc_live_screen.dart`
Expected: No issues.

- [ ] **Step 3: Manual smoke test**

Run: `flutter run -d chrome` (or any configured device). Navigate to the live screen. Expected:
- Video plays normally, existing score chip / back / reminder buttons still clickable.
- Bot messages periodically float across the middle band of the video, right-to-left.
- Sending a message shows the text both flying across the video (accent color) and in the list below.

- [ ] **Step 4: Commit**

```bash
git add lib/features/events/wc_live_screen.dart
git commit -m "feat(wc-live): overlay DanmakuOverlay on top of live stream player"
```

---

## Task 9: `wc_live_screen.dart` — 弹幕开关按钮

**Files:**
- Modify: `lib/features/events/wc_live_screen.dart`

- [ ] **Step 1: Add `_DanmakuToggleButton` widget**

At the bottom of the file (next to `_ReminderButton` class, around line 450), add:

```dart
class _DanmakuToggleButton extends StatelessWidget {
  final bool on;
  final String label;
  final VoidCallback onTap;
  const _DanmakuToggleButton({
    required this.on,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x80000000),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.subtitles : Icons.subtitles_off,
              size: 14,
              color: on ? context.tokens.accent : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Replace `topRight` with a Row of toggle + reminder**

In the `LiveStreamPlayer(...)` call (inside the Stack from Task 8), change the `topRight` argument from the existing `_ReminderButton(...)` to:

```dart
                    topRight: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DanmakuToggleButton(
                          on: _danmakuOn,
                          label: _danmakuOn
                              ? l.wc_btn_danmaku_on
                              : l.wc_btn_danmaku_off,
                          onTap: () async {
                            final next = !_danmakuOn;
                            setState(() => _danmakuOn = next);
                            await LocalStore.setDanmakuEnabled(next);
                          },
                        ),
                        const SizedBox(width: 8),
                        _ReminderButton(
                          hasReminder: hasReminder,
                          label: l.wc_btn_remind,
                          onTap: () => _showReminderSheet(context),
                        ),
                      ],
                    ),
```

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/features/events/wc_live_screen.dart`
Expected: No issues.

- [ ] **Step 4: Manual smoke test**

Run the app, open live screen. Tap the "弹幕 开" button — label flips to "弹幕 关", icon to `subtitles_off`, incoming messages stop flying across the video but still appear in the list below. Relaunch the app — the toggle state persists.

- [ ] **Step 5: Commit**

```bash
git add lib/features/events/wc_live_screen.dart
git commit -m "feat(wc-live): add danmaku on/off toggle next to reminder button"
```

---

## Task 10: 全屏路由支持

**Files:**
- Modify: `lib/widgets/live_stream_player.dart`, `lib/features/events/wc_live_screen.dart`

- [ ] **Step 1: Extend `_LiveFullscreenRoute` constructor**

In `lib/widgets/live_stream_player.dart`, add an import at the top:

```dart
import 'danmaku_overlay.dart';
```

Then modify `_LiveFullscreenRoute`:

```dart
class _LiveFullscreenRoute extends StatefulWidget {
  final VideoPlayerController controller;
  final bool initiallyMuted;
  final ValueChanged<bool> onMuteChanged;
  final String? scoreOverlay;
  final Stream<DanmakuItem>? danmakuStream;
  final bool danmakuEnabled;

  const _LiveFullscreenRoute({
    required this.controller,
    required this.initiallyMuted,
    required this.onMuteChanged,
    required this.scoreOverlay,
    this.danmakuStream,
    this.danmakuEnabled = true,
  });

  @override
  State<_LiveFullscreenRoute> createState() => _LiveFullscreenRouteState();
}
```

- [ ] **Step 2: Overlay DanmakuOverlay in fullscreen Stack**

In `_LiveFullscreenRouteState.build`, inside the outer `Stack`'s `children:`, after the `Center(child: AspectRatio(...))` that renders the `VideoPlayer`, add:

```dart
            if (widget.danmakuStream != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DanmakuOverlay(
                    stream: widget.danmakuStream!,
                    enabled: widget.danmakuEnabled,
                  ),
                ),
              ),
```

- [ ] **Step 3: Pipe stream through `LiveStreamPlayer` public API**

Add two new fields + constructor params to `LiveStreamPlayer`:

```dart
  final Stream<DanmakuItem>? danmakuStream;
  final bool danmakuEnabled;
```

Add to the const constructor:

```dart
    this.danmakuStream,
    this.danmakuEnabled = true,
```

In `_LiveStreamPlayerState._enterFullscreen`, pass them through:

```dart
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => _LiveFullscreenRoute(
          controller: c,
          initiallyMuted: _muted,
          onMuteChanged: (m) async {
            _muted = m;
            await c.setVolume(m ? 0 : 1);
            if (mounted) setState(() {});
          },
          scoreOverlay: widget.scoreOverlay,
          danmakuStream: widget.danmakuStream,
          danmakuEnabled: widget.danmakuEnabled,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
```

- [ ] **Step 4: Pass stream from `wc_live_screen.dart`**

In the `LiveStreamPlayer(...)` call (modified in Task 8), add two more arguments:

```dart
                    danmakuStream: _danmuController.stream,
                    danmakuEnabled: _danmakuOn,
```

- [ ] **Step 5: Run analyze + full tests**

Run: `flutter analyze`
Expected: No issues.

Run: `flutter test`
Expected: All pass.

- [ ] **Step 6: Manual fullscreen test**

Run the app, open live screen, tap fullscreen button. Verify:
- Video goes landscape.
- Bot danmaku continues to fly across the fullscreen video.
- Own sent danmu appears in accent color.
- Exit fullscreen → portrait also shows danmaku normally.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/live_stream_player.dart lib/features/events/wc_live_screen.dart
git commit -m "feat(live): show danmaku overlay in fullscreen route"
```

---

## Task 11: 页面集成测试

**Files:**
- Create: `test/features/events/wc_live_screen_test.dart`

- [ ] **Step 1: Write the integration test**

Create `test/features/events/wc_live_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/features/events/wc_live_screen.dart';
import 'package:kaiqiu_app/l10n/generated/app_localizations.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

Widget _wrap(Widget child) {
  final t = ThemeController();
  return ProviderScope(
    child: MaterialApp(
      theme: t.lightTheme,
      darkTheme: t.darkTheme,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  testWidgets('sending a message puts text into both chat list and overlay',
      (tester) async {
    await tester.pumpWidget(_wrap(const WcLiveScreen(matchId: 'm-test')));
    await tester.pump();

    final input = find.byType(TextField);
    await tester.enterText(input, 'hello-overlay');
    await tester.pump();

    // Tap the send button (GestureDetector with Icons.send inside).
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // At least two occurrences: one in the scrolling overlay, one in the
    // bubble list below.
    expect(find.text('hello-overlay'), findsNWidgets(2));

    // Drain animations.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('toggling danmaku off keeps chat list but stops overlay',
      (tester) async {
    await tester.pumpWidget(_wrap(const WcLiveScreen(matchId: 'm-test-2')));
    await tester.pump();

    // Tap the danmaku toggle button (initially "弹幕 开" — has Icons.subtitles).
    await tester.tap(find.byIcon(Icons.subtitles));
    await tester.pump();

    // Now send a message.
    await tester.enterText(find.byType(TextField), 'solo-list');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Should appear exactly once — only in the bubble list below.
    expect(find.text('solo-list'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/features/events/wc_live_screen_test.dart`
Expected: PASS (2 tests).

If `LiveStreamPlayer` fails to initialize in widget tests (network video), that's fine — the tests don't tap the video surface; the danmaku overlay and bubble list render independently of the video controller state.

- [ ] **Step 3: Commit**

```bash
git add test/features/events/wc_live_screen_test.dart
git commit -m "test(wc-live): cover danmaku send and toggle flows"
```

---

## Task 12: 最终验证 + 文档收尾

**Files:** (no code changes)

- [ ] **Step 1: Full analyze + tests**

Run: `flutter analyze`
Expected: No issues.

Run: `flutter test`
Expected: All pass (including the new 3 test files).

- [ ] **Step 2: Manual end-to-end smoke check**

Run: `flutter run` on a configured device.

- Navigate to the live screen.
- Confirm: bot danmaku flies across the video in the middle band (4 tracks), doesn't overlap the score chip / reminder / back button / LIVE pill / viewer count.
- Send a message — flies in accent color, also listed in the bubble feed below.
- Toggle `弹幕 开` → `弹幕 关` — new messages stop flying but still list below.
- Kill and relaunch the app — toggle state persists.
- Enter fullscreen — danmaku still flies.
- Exit fullscreen — danmaku still flies.

- [ ] **Step 3: Mark spec as implemented**

Edit `docs/superpowers/specs/2026-04-21-live-danmaku-overlay-design.md` — change the header `**Status:** Draft` to `**Status:** Implemented`.

- [ ] **Step 4: Final commit**

```bash
git add docs/superpowers/specs/2026-04-21-live-danmaku-overlay-design.md
git commit -m "docs: mark live-danmaku-overlay spec as implemented"
```
