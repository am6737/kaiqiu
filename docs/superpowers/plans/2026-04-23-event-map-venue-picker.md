# Event Map Venue Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the free-text venue field in event creation with the shared map-based `LocationPickerScreen`, and display venue + navigation in the event detail page.

**Architecture:** Reuse the existing `LocationPickerScreen` (Amap + POI search) already shared by pickup and venue creation. Add `address`/`lat`/`lng` columns to the `events` table, wire them through the Dart model, creation form, preview, and detail page. The detail page gets a venue row with a navigation button that opens external map apps via the existing `MapLauncher` service.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres), Amap SDK, `url_launcher`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `supabase/migrations/0001_schema.sql` | Modify | Add `address`, `lat`, `lng` columns to `events` table |
| `supabase/seed/demo.sql` | Modify | Add demo location data to seeded events |
| `lib/models/event.dart` | Modify | Add `address`, `lat`, `lng` fields to `Event` class |
| `lib/l10n/app_zh.arb` | Modify | Add `event_overview_venue` l10n key |
| `lib/l10n/app_en.arb` | Modify | Add `event_overview_venue` l10n key |
| `lib/features/create_event/step_basic_info.dart` | Modify | Replace text input with map picker trigger |
| `lib/features/create_event/create_event_screen.dart` | Modify | Replace `_venue` controller with `_pickedLocation` state |
| `lib/features/create_event/step_preview.dart` | Modify | Show venue address in preview card |
| `lib/features/events/panels/overview_panel.dart` | Modify | Add venue + navigate row |

---

### Task 1: Database Schema — Add Location Columns to Events

**Files:**
- Modify: `supabase/migrations/0001_schema.sql:156-173`
- Modify: `supabase/seed/demo.sql:296-327`

- [ ] **Step 1: Add address/lat/lng columns to the events table definition**

In `supabase/migrations/0001_schema.sql`, find the `create table public.events` block (lines 156-173). Add three new columns after `city text,` (line 161):

```sql
create table public.events (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references public.profiles,
  name text not null,
  sub text,
  city text,
  address text,
  lat double precision,
  lng double precision,
  template text,                        -- knockout16/group8/wc/league
  team_size int default 11,
  teams_max int,
  prize_cents int,
  fee_cents int,
  deadline timestamptz,
  starts_at timestamptz,
  ends_at timestamptz,
  status text default 'registering' check (status in ('draft','registering','scheduling','ongoing','completed','done')),
  cover_url text,
  created_at timestamptz default now()
);
```

- [ ] **Step 2: Add demo location data to seeded events**

In `supabase/seed/demo.sql`, update the first events insert (line 296) to include location columns. Use real Nanning coordinates for the demo data:

```sql
insert into events (id, creator_id, name, sub, city, address, lat, lng, status, template, team_size, teams_max,
  prize_cents, deadline, starts_at, cover_url
) values
  ('11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000001',
   '2026 青秀村超', '青秀体育中心', '南宁 · 青秀区',
   '南宁市青秀区民族大道162号', 22.8170, 108.3665,
   'ongoing', 'knockout16', 11, 16,
   5000000, now() - interval '10 days', now() - interval '6 days',
   'https://images.unsplash.com/photo-1654462977797-a349656aadcf?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('11111111-1111-1111-1111-222222222222',
   null,
   '邕企杯 · 春季', '广西体育中心', '南宁 · 兴宁区',
   '南宁市兴宁区五村岭路1号', 22.8489, 108.2983,
   'ongoing', 'group8', 8, 24,
   3000000, now() - interval '20 days', now() - interval '14 days',
   'https://images.unsplash.com/photo-1517466787929-bc90951d0974?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('11111111-1111-1111-1111-333333333333',
   null,
   '邕江夜联赛', '邕江滨水公园足球场', '南宁 · 青秀',
   '南宁市青秀区邕江南岸', 22.8050, 108.3700,
   'registering', 'league', 7, 12,
   2000000, now() + interval '11 days', now() + interval '14 days',
   'https://images.unsplash.com/photo-1431324155629-1a6deb1dec8d?auto=format&fit=crop&w=1200&h=600&q=70'),
  ('11111111-1111-1111-1111-444444444444',
   null,
   '广西校友杯', '广西大学体育场', '南宁 · 西乡塘',
   '南宁市西乡塘区大学东路100号', 22.8380, 108.2900,
   'ongoing', 'knockout16', 11, 16,
   1500000, now() - interval '30 days', now() - interval '21 days',
   'https://images.unsplash.com/photo-1560272564-c83b66b1ad12?auto=format&fit=crop&w=1200&h=600&q=70');
```

The second events insert (line 322, 国际赛事直播) has no physical venue, leave it unchanged.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0001_schema.sql supabase/seed/demo.sql
git commit -m "feat(db): add address/lat/lng columns to events table"
```

---

### Task 2: Dart Model — Add Location Fields to Event

**Files:**
- Modify: `lib/models/event.dart:13-67`

- [ ] **Step 1: Add fields to Event class**

In `lib/models/event.dart`, add three fields after `city` (line 18):

```dart
class Event {
  final String id;
  final String? creatorId;
  final String name;
  final String? sub;
  final String? city;
  final String? address;
  final double? lat;
  final double? lng;
  final String? template;
  final int teamSize;
  final int? teamsMax;
  final int? prizeCents;
  final int? feeCents;
  final DateTime? deadline;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final EventStatus status;
  final String? coverUrl;
  final String? reviewMode;
```

- [ ] **Step 2: Add constructor parameters**

Add the three optional parameters after `this.city,` (line 36):

```dart
  const Event({
    required this.id,
    this.creatorId,
    required this.name,
    this.sub,
    this.city,
    this.address,
    this.lat,
    this.lng,
    this.template,
    this.teamSize = 11,
    this.teamsMax,
    this.prizeCents,
    this.feeCents,
    this.deadline,
    this.startsAt,
    this.endsAt,
    this.status = EventStatus.registering,
    this.coverUrl,
    this.reviewMode,
  });
```

- [ ] **Step 3: Add fromMap parsing**

Add three lines after `city: m['city'] as String?,` (line 55):

```dart
  factory Event.fromMap(Map<String, dynamic> m) => Event(
    id: m['id'] as String,
    creatorId: m['creator_id'] as String?,
    name: m['name'] as String,
    sub: m['sub'] as String?,
    city: m['city'] as String?,
    address: m['address'] as String?,
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    template: m['template'] as String?,
    teamSize: (m['team_size'] as int?) ?? 11,
    teamsMax: m['teams_max'] as int?,
    prizeCents: m['prize_cents'] as int?,
    feeCents: m['fee_cents'] as int?,
    deadline: m['deadline'] != null ? DateTime.parse(m['deadline']) : null,
    startsAt: m['starts_at'] != null ? DateTime.parse(m['starts_at']) : null,
    endsAt: m['ends_at'] != null ? DateTime.parse(m['ends_at']) : null,
    status: _parseEventStatus(m['status'] as String?),
    coverUrl: m['cover_url'] as String?,
    reviewMode: m['review_mode'] as String?,
  );
```

- [ ] **Step 4: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/models/event.dart 2>&1 | tail -5`

Expected: No errors in event.dart

- [ ] **Step 5: Commit**

```bash
git add lib/models/event.dart
git commit -m "feat(model): add address/lat/lng to Event"
```

---

### Task 3: Localization — Add Venue Label Key

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add l10n key to Chinese ARB**

In `lib/l10n/app_zh.arb`, find the line `"event_overview_organizer": "组织方",` (near line 189) and add the venue key just before it:

```json
  "event_overview_venue": "赛事场地",
  "event_overview_organizer": "组织方",
```

- [ ] **Step 2: Add l10n key to English ARB**

In `lib/l10n/app_en.arb`, find the line `"event_overview_organizer": "Organizer",` (near line 189) and add the venue key just before it:

```json
  "event_overview_venue": "Venue",
  "event_overview_organizer": "Organizer",
```

- [ ] **Step 3: Regenerate l10n**

Run: `cd /home/coder/workspaces/qiuju_app && flutter gen-l10n 2>&1 | tail -3`

Expected: Output indicates successful generation with no errors.

- [ ] **Step 4: Verify the new key exists in generated code**

Run: `grep 'event_overview_venue' lib/l10n/generated/app_localizations_zh.dart`

Expected: A line like `String get event_overview_venue => '赛事场地';`

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add event_overview_venue key"
```

---

### Task 4: StepBasicInfo — Replace Text Input With Map Picker

**Files:**
- Modify: `lib/features/create_event/step_basic_info.dart`

- [ ] **Step 1: Rewrite step_basic_info.dart**

Replace the entire content of `lib/features/create_event/step_basic_info.dart` with:

```dart
// step_basic_info.dart — Step 2: basic event information
import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/picked_location.dart';
import '../../theme/app_tokens.dart';
import 'event_form_fields.dart';

class StepBasicInfo extends StatelessWidget {
  final TextEditingController nameController;
  final DateTime? startDate;
  final DateTime? endDate;
  final PickedLocation? pickedLocation;
  final VoidCallback onPickLocation;
  final VoidCallback onClearLocation;
  final TextEditingController feeController;
  final TextEditingController prizeController;
  final Map<String, String?> errors;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const StepBasicInfo({
    super.key,
    required this.nameController,
    required this.startDate,
    required this.endDate,
    required this.pickedLocation,
    required this.onPickLocation,
    required this.onClearLocation,
    required this.feeController,
    required this.prizeController,
    required this.errors,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasError = errors['venue'] != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_step_basic,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          EventField(label: l.create_event_f_name, controller: nameController, errorText: errors['name']),
          Row(
            children: [
              Expanded(
                child: EventDateField(
                  label: l.create_event_f_start,
                  value: startDate,
                  errorText: errors['start'],
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EventDateField(
                  label: l.create_event_f_end,
                  value: endDate,
                  errorText: errors['end'],
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          // Venue picker (replaces EventField text input)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.create_event_f_venue,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.inkDim,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onPickLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(
                        color: hasError ? Colors.red : context.tokens.line,
                      ),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: pickedLocation != null
                              ? context.tokens.accent
                              : context.tokens.inkDim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: pickedLocation != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pickedLocation!.name,
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
                                      pickedLocation!.address,
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
                                  l.create_event_f_venue,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.tokens.inkDim,
                                  ),
                                ),
                        ),
                        if (pickedLocation != null)
                          GestureDetector(
                            onTap: onClearLocation,
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
                if (hasError) ...[
                  const SizedBox(height: 4),
                  Text(
                    errors['venue']!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: EventField(
                  label: l.create_event_f_fee,
                  controller: feeController,
                  prefix: '¥',
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: errors['fee'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EventField(
                  label: l.create_event_f_prize,
                  controller: prizeController,
                  prefix: '¥',
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: errors['prize'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/create_event/step_basic_info.dart 2>&1 | tail -5`

Expected: No errors (there will be warnings from create_event_screen.dart since it still passes `venueController` — that's fixed in Task 5).

- [ ] **Step 3: Commit**

```bash
git add lib/features/create_event/step_basic_info.dart
git commit -m "feat(create-event): replace venue text input with map picker in StepBasicInfo"
```

---

### Task 5: CreateEventScreen — Wire PickedLocation State

**Files:**
- Modify: `lib/features/create_event/create_event_screen.dart`

- [ ] **Step 1: Update imports**

Add the `PickedLocation` and `LocationPickerScreen` imports at the top, after the existing imports (after line 18):

```dart
import '../../models/picked_location.dart';
import '../pickup/location_picker.dart';
```

- [ ] **Step 2: Replace _venue controller with _pickedLocation state**

Replace:

```dart
  final _venue = TextEditingController();
```

With:

```dart
  PickedLocation? _pickedLocation;
```

- [ ] **Step 3: Remove _venue from dispose()**

In the `dispose()` method (lines 90-102), remove `_venue` from the controllers list. Change:

```dart
  @override
  void dispose() {
    for (final c in [
      _name,
      _venue,
      _fee,
      _prize,
      _teamSize,
      _maxTeams,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
```

To:

```dart
  @override
  void dispose() {
    for (final c in [
      _name,
      _fee,
      _prize,
      _teamSize,
      _maxTeams,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
```

- [ ] **Step 4: Update _loadEvent for edit mode**

In `_loadEvent()` (lines 67-87), replace:

```dart
        _venue.text = event.sub ?? '';
```

With:

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

- [ ] **Step 5: Add _pickLocation method**

Add this method after `_loadEvent()`, before `dispose()`:

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

- [ ] **Step 6: Update validation in _validateStep**

In `_validateStep()` (line 120), replace:

```dart
      if (_venue.text.trim().isEmpty) errors['venue'] = l.validation_venue_required;
```

With:

```dart
      if (_pickedLocation == null) errors['venue'] = l.validation_venue_required;
```

- [ ] **Step 7: Update StepBasicInfo call in _stepContent**

In `_stepContent()` (lines 315-331), replace the `StepBasicInfo(...)` call:

```dart
      2 => StepBasicInfo(
          nameController: _name,
          startDate: _startDate,
          endDate: _endDate,
          pickedLocation: _pickedLocation,
          onPickLocation: _pickLocation,
          onClearLocation: () => setState(() => _pickedLocation = null),
          feeController: _fee,
          prizeController: _prize,
          errors: _errors,
          onPickStart: () async {
            final dt = await _pickDateTime(initial: _startDate);
            if (dt != null) setState(() => _startDate = dt);
          },
          onPickEnd: () async {
            final dt = await _pickDateTime(initial: _endDate);
            if (dt != null) setState(() => _endDate = dt);
          },
        ),
```

- [ ] **Step 8: Update StepPreview call in _stepContent**

In `_stepContent()` (lines 344-356), update the `StepPreview(...)` call to pass the new fields:

```dart
      _ => StepPreview(
          selectedTemplate: _tpl,
          eventName: _name.text,
          venueName: _pickedLocation?.name ?? '',
          venueAddress: _pickedLocation?.address,
          prizeText: _prize.text,
          maxTeamsText: _maxTeams.text,
          startDate: _startDate,
          deadlineDate: _deadlineDate,
          coverUrl: _coverUrl,
          uploadingCover: _uploadingCover,
          onPickCover: _pickCover,
        ),
```

- [ ] **Step 9: Update payload in _submitImpl**

In `_submitImpl()` (lines 402-416), replace the payload:

```dart
      final payload = {
        'creator_id': uid,
        'name': _name.text.trim(),
        'sub': _pickedLocation?.name,
        'address': _pickedLocation?.address,
        'lat': _pickedLocation?.lat,
        'lng': _pickedLocation?.lng,
        'template': _tpl,
        'team_size': int.tryParse(_teamSize.text) ?? 11,
        'teams_max': int.tryParse(_maxTeams.text) ?? 16,
        'fee_cents': (int.tryParse(_fee.text) ?? 0) * 100,
        'prize_cents': (int.tryParse(_prize.text) ?? 0) * 100,
        'deadline': _deadlineDate?.toIso8601String(),
        'starts_at': _startDate?.toIso8601String(),
        'ends_at': _endDate?.toIso8601String(),
        'review_mode': _review,
        if (_coverUrl != null) 'cover_url': _coverUrl,
      };
```

- [ ] **Step 10: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/create_event/ 2>&1 | tail -10`

Expected: No errors in create_event_screen.dart. There may be an error in step_preview.dart about `venueAddress` — that's fixed in Task 6.

- [ ] **Step 11: Commit**

```bash
git add lib/features/create_event/create_event_screen.dart
git commit -m "feat(create-event): wire PickedLocation state and LocationPickerScreen"
```

---

### Task 6: StepPreview — Show Venue Address

**Files:**
- Modify: `lib/features/create_event/step_preview.dart`

- [ ] **Step 1: Add venueAddress parameter**

Add `venueAddress` field after `venueName` in the class (after line 14):

```dart
  final String venueName;
  final String? venueAddress;
```

Add it to the constructor (after `required this.venueName,`):

```dart
    required this.venueName,
    this.venueAddress,
```

- [ ] **Step 2: Add address display in the preview card**

In the build method, find the line `'$tplName · $venueName',` (line 202). After the `Text('$tplName · $venueName', ...)` widget and before `const SizedBox(height: 12),` (line 205), add the address line:

```dart
                      Text(
                        '$tplName · $venueName',
                        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                      ),
                      if (venueAddress != null && venueAddress!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          venueAddress!,
                          style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
```

Remove the original `const SizedBox(height: 12),` that was on line 205 to avoid duplication.

- [ ] **Step 3: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/create_event/ 2>&1 | tail -5`

Expected: No errors across create_event directory.

- [ ] **Step 4: Commit**

```bash
git add lib/features/create_event/step_preview.dart
git commit -m "feat(create-event): show venue address in StepPreview"
```

---

### Task 7: OverviewPanel — Add Venue + Navigate Row

**Files:**
- Modify: `lib/features/events/panels/overview_panel.dart`

- [ ] **Step 1: Rewrite overview_panel.dart**

Replace the entire content of `lib/features/events/panels/overview_panel.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../services/map_launcher.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class OverviewPanel extends StatelessWidget {
  final Event event;
  const OverviewPanel({super.key, required this.event});

  bool get _canNavigate => event.lat != null && event.lng != null;

  String get _locationText {
    final parts = <String>[];
    if (event.sub != null && event.sub!.isNotEmpty) parts.add(event.sub!);
    if (event.address != null &&
        event.address!.trim().isNotEmpty &&
        event.address != event.sub) {
      parts.add(event.address!);
    }
    return parts.join(' · ');
  }

  void _openNav(BuildContext context) {
    if (!_canNavigate) return;
    MapLauncher.openNavigation(
      context: context,
      lat: event.lat!,
      lng: event.lng!,
      name: event.sub ?? (event.address ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.tokens.elev1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${event.name}。',
            style: TextStyle(fontSize: 14, color: context.tokens.ink, height: 1.6),
          ),
          const SizedBox(height: 16),
          Label(l.event_overview_rules),
          const SizedBox(height: 10),
          for (final r in [
            l.event_overview_rule_format,
            l.event_overview_rule_halves,
            l.event_overview_rule_subs,
            l.event_overview_rule_cards,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.tokens.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    r,
                    style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Venue section
          if (event.sub != null && event.sub!.isNotEmpty) ...[
            Label(l.event_overview_venue),
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
                      _locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _canNavigate ? () => _openNav(context) : null,
                    style: TextButton.styleFrom(
                      foregroundColor: context.tokens.accent,
                      disabledForegroundColor: context.tokens.inkMute,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    child: Text(l.pickup_detail_navigate),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Label(l.event_overview_organizer),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.tokens.elev3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.city ?? '—',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.ink,
                      ),
                    ),
                    Label(l.event_overview_organizer_label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

Key changes from original:
- Body text: `'${event.name}。'` instead of `'${event.sub} — ${event.name}。'` (avoids duplication)
- New venue section between rules and organizer, with navigate button
- Imports `MapLauncher`
- Reuses `pickup_detail_navigate` l10n key for the navigate button
- Navigate button disabled when lat/lng is null (backward compatible with old events)

- [ ] **Step 2: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/events/panels/overview_panel.dart 2>&1 | tail -5`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/panels/overview_panel.dart
git commit -m "feat(event-detail): add venue + navigate row to OverviewPanel"
```

---

### Task 8: Full Build Verification

- [ ] **Step 1: Run full analysis**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze 2>&1 | tail -20`

Expected: No errors. Fix any issues found.

- [ ] **Step 2: Run build**

Run: `cd /home/coder/workspaces/qiuju_app && flutter build apk --debug 2>&1 | tail -10`

Expected: Build succeeds.

- [ ] **Step 3: Reset and re-seed database**

Run: `cd /home/coder/workspaces/qiuju_app && npx supabase db reset 2>&1 | tail -10`

Expected: Reset completes with seed data applied, no errors about the new columns.
