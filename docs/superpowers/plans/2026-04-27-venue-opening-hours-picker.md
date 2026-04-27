# 场馆营业时间选择器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the manual text input for venue opening hours with a CupertinoPicker-based BottomSheet time picker.

**Architecture:** Single-file change in `create_venue_screen.dart`. Add a new private widget `_OpeningHoursPickerSheet` containing dual CupertinoPicker columns (start/end time). Replace the `_openingHours` TextEditingController with state variables and the `_TextField` widget with a tappable display row that launches the picker via `showModalBottomSheet`.

**Tech Stack:** Flutter `CupertinoPicker` (built-in, `package:flutter/cupertino.dart`), existing `AppTokens` design system.

---

### Task 1: Add state variables and remove TextEditingController

**Files:**
- Modify: `lib/features/venue/create_venue_screen.dart:24-60`

- [ ] **Step 1: Replace `_openingHours` controller with state variables**

In `_CreateVenueScreenState`, replace line 30:

```dart
final _openingHours = TextEditingController(text: '08:00-22:00');
```

with two state variables after line 33 (`_fieldType`):

```dart
String _startTime = '08:00';
String _endTime = '22:00';
```

- [ ] **Step 2: Remove `_openingHours` from dispose**

Change line 56 from:

```dart
for (final c in [_name, _desc, _phone, _price, _fieldCount, _openingHours, _customFacility]) {
```

to:

```dart
for (final c in [_name, _desc, _phone, _price, _fieldCount, _customFacility]) {
```

- [ ] **Step 3: Update `_submit` to use new state variables**

Replace lines 164-166:

```dart
'opening_hours': _openingHours.text.trim().isNotEmpty
    ? _openingHours.text.trim()
    : null,
```

with:

```dart
'opening_hours': '$_startTime-$_endTime',
```

---

### Task 2: Replace `_TextField` with tappable display row

**Files:**
- Modify: `lib/features/venue/create_venue_screen.dart:355-359`

- [ ] **Step 1: Replace the `_TextField` widget for opening hours**

Replace lines 355-359:

```dart
_TextField(
  label: '营业时间',
  controller: _openingHours,
  hint: '如 08:00-22:00',
),
```

with a tappable display row that matches the existing location picker's visual style (lines 262-332):

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Label('营业时间'),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final result = await showModalBottomSheet<(String, String)>(
            context: context,
            backgroundColor: t.elev1,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _OpeningHoursPickerSheet(
              startTime: _startTime,
              endTime: _endTime,
            ),
          );
          if (result != null && mounted) {
            setState(() {
              _startTime = result.$1;
              _endTime = result.$2;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: t.elev2,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(t.r2),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 20, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_startTime — $_endTime',
                  style: TextStyle(
                    fontSize: 14,
                    color: t.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: t.inkMute),
            ],
          ),
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 2: Add the cupertino import**

Add at the top of the file (after line 2 `import 'package:flutter/material.dart';`):

```dart
import 'package:flutter/cupertino.dart';
```

---

### Task 3: Implement `_OpeningHoursPickerSheet` widget

**Files:**
- Modify: `lib/features/venue/create_venue_screen.dart` (add new class before `_CoverPicker`)

- [ ] **Step 1: Add the `_OpeningHoursPickerSheet` StatefulWidget**

Insert the following class before the `_CoverPicker` class. This widget uses two `CupertinoPicker` columns for start and end time, with 30-minute increments from 00:00 to 24:00 (49 items). It shows a live preview with total hours and disables the confirm button when end <= start.

```dart
class _OpeningHoursPickerSheet extends StatefulWidget {
  final String startTime;
  final String endTime;
  const _OpeningHoursPickerSheet({
    required this.startTime,
    required this.endTime,
  });

  @override
  State<_OpeningHoursPickerSheet> createState() =>
      _OpeningHoursPickerSheetState();
}

class _OpeningHoursPickerSheetState extends State<_OpeningHoursPickerSheet> {
  static const _kItemExtent = 40.0;
  static const _kPickerHeight = 200.0;

  static final _timeSlots = [
    for (int h = 0; h < 24; h++) ...[
      '${h.toString().padLeft(2, '0')}:00',
      '${h.toString().padLeft(2, '0')}:30',
    ],
    '24:00',
  ];

  late int _startIndex;
  late int _endIndex;

  @override
  void initState() {
    super.initState();
    _startIndex = _timeSlots.indexOf(widget.startTime).clamp(0, _timeSlots.length - 1);
    _endIndex = _timeSlots.indexOf(widget.endTime).clamp(0, _timeSlots.length - 1);
  }

  bool get _isValid => _endIndex > _startIndex;

  String _durationLabel() {
    final totalMinutes = (_endIndex - _startIndex) * 30;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '共 $hours 小时';
    return '共 $hours 小时 $minutes 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header: cancel / title / confirm
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      '取消',
                      style: TextStyle(fontSize: 15, color: t.inkSub),
                    ),
                  ),
                  Text(
                    '营业时间',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  GestureDetector(
                    onTap: _isValid
                        ? () => Navigator.pop(
                              context,
                              (_timeSlots[_startIndex], _timeSlots[_endIndex]),
                            )
                        : null,
                    child: Text(
                      '确定',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _isValid ? t.accent : t.inkMute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Live preview
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _timeSlots[_startIndex],
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _isValid ? t.accent : t.inkMute,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '—',
                          style: TextStyle(fontSize: 24, color: t.inkDim),
                        ),
                      ),
                      Text(
                        _timeSlots[_endIndex],
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _isValid ? t.accent : t.inkMute,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isValid ? _durationLabel() : '结束时间须晚于开始时间',
                    style: TextStyle(
                      fontSize: 13,
                      color: _isValid ? t.inkSub : t.danger,
                    ),
                  ),
                ],
              ),
            ),
            // Dual pickers
            Row(
              children: [
                // Start time picker
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '开始时间',
                        style: TextStyle(fontSize: 12, color: t.inkDim),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: _kPickerHeight,
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: _startIndex,
                          ),
                          itemExtent: _kItemExtent,
                          onSelectedItemChanged: (i) =>
                              setState(() => _startIndex = i),
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                            background: t.accent.withValues(alpha: 0.08),
                          ),
                          children: [
                            for (final slot in _timeSlots)
                              Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(fontSize: 18, color: t.ink),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // End time picker
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '结束时间',
                        style: TextStyle(fontSize: 12, color: t.inkDim),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: _kPickerHeight,
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: _endIndex,
                          ),
                          itemExtent: _kItemExtent,
                          onSelectedItemChanged: (i) =>
                              setState(() => _endIndex = i),
                          selectionOverlay:
                              CupertinoPickerDefaultSelectionOverlay(
                            background: t.accent.withValues(alpha: 0.08),
                          ),
                          children: [
                            for (final slot in _timeSlots)
                              Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(fontSize: 18, color: t.ink),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify the app compiles cleanly**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/venue/create_venue_screen.dart`

Expected: No errors, no warnings.

- [ ] **Step 3: Commit all changes from Tasks 1-3**

```bash
git add lib/features/venue/create_venue_screen.dart
git commit -m "feat(venue): replace opening hours text input with CupertinoPicker bottom sheet

Replace manual text input with a tappable display row that opens a dual-column
scroll wheel picker. 30-minute increments from 00:00 to 24:00, live preview
with duration, validates end > start. Data format unchanged (HH:MM-HH:MM)."
```

---

### Task 4: Manual smoke test

**Files:** None (testing only)

- [ ] **Step 1: Launch the app and navigate to venue creation**

Run: `flutter run -d chrome` (or the running dev server)

Navigate to the venue creation screen.

- [ ] **Step 2: Verify the display row**

Confirm:
- The opening hours field shows "08:00 — 22:00" as a tappable row (not a text input)
- The row has a clock icon on the left and a chevron on the right
- The style matches the location picker row above it

- [ ] **Step 3: Verify the bottom sheet picker**

Tap the opening hours row and confirm:
- A bottom sheet slides up with a drag handle at the top
- Title bar shows "取消" / "营业时间" / "确定"
- Live preview shows the selected time range and total hours (e.g., "共 14 小时")
- Two scroll wheels for start and end time, 30-minute increments
- Scrolling either wheel updates the preview in real-time

- [ ] **Step 4: Verify validation**

Scroll the start time past the end time and confirm:
- The "确定" button turns grey/disabled
- The preview text changes to "结束时间须晚于���始时间" in red
- Tapping "确定" does nothing while invalid

- [ ] **Step 5: Verify confirm and cancel flows**

Test:
- Select a valid time (e.g., 09:00-21:00), tap "确定" → sheet closes, display row updates to "09:00 — 21:00"
- Open again, change time, tap "取消" → sheet closes, display row keeps previous value
- Open again, change time, swipe down → same as cancel

- [ ] **Step 6: Verify submission**

Fill out the full form and submit. Confirm:
- The venue is created successfully with the selected opening hours
- The venue detail page shows the correct opening hours in the info chips
