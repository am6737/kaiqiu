# Event Flow Validation & Completeness Design

Date: 2026-04-23

## Problem

The event lifecycle (create → register → schedule → ongoing → completed) has significant gaps in validation, flow logic, and UX. Key issues:

1. **No required-field validation** on event creation — name, dates, venue can all be blank
2. **No validation on schedule publish** — empty team labels and times are accepted
3. **Registration flow is incomplete** — no capacity check, no deadline enforcement, registration button appears in wrong states, `_review` field not persisted
4. **No way to complete/cancel events** — missing `ongoing → completed` transition, no cancel ability
5. **No event editing** — organizer cannot modify event info after creation
6. **UX friction** — date fields are raw text input, number fields accept letters, large files need splitting

## Scope

Six modules covering the full lifecycle:

| # | Module | Files touched |
|---|--------|--------------|
| 1 | Create event validation & UX | `create_event_screen.dart` (split into 6 files) |
| 2 | Schedule publish validation | `schedule_matches_screen.dart` |
| 3 | Registration guards & validation | `event_detail_screen.dart` (bottom CTA + register sheet) |
| 4 | Event lifecycle transitions | `event_detail_screen.dart`, `events_repository.dart`, `match_control_panel.dart` |
| 5 | File splitting | `create_event/`, `events/panels/`, `events/widgets/` |
| 6 | Shared validation utility | `lib/utils/event_validators.dart` |

## Module 1: Create Event — Validation & UX

### 1.1 Step-level validation

Each "Next" button press validates the current step before advancing. Errors display inline below the field (red text), not just Toast.

**Step 2 — Basic Info:**
| Field | Rule | Error key |
|-------|------|-----------|
| Name | non-empty, trimmed | `validation_name_required` |
| Start time | non-null, must be > now | `validation_start_required`, `validation_start_future` |
| End time | non-null, must be > start | `validation_end_required`, `validation_end_after_start` |
| Venue | non-empty | `validation_venue_required` |
| Fee | if provided, must be integer >= 0 | `validation_fee_positive` |
| Prize | if provided, must be integer >= 0 | `validation_prize_positive` |

**Step 3 — Registration:**
| Field | Rule | Error key |
|-------|------|-----------|
| Deadline | non-null, must be < start time | `validation_deadline_required`, `validation_deadline_before_start` |
| Team size | integer > 0, default 11 | `validation_team_size_positive` |
| Max teams | integer >= 2 | `validation_max_teams_min` |

Step 1 (template) has a default selection, no validation needed. Step 4 (preview) is submit-only.

### 1.2 Date fields → DatePicker

Replace raw `TextField` for dates with a `GestureDetector` that opens `showDatePicker` + `showTimePicker` (same pattern already used in `schedule_matches_screen.dart`). Display the selected date in a formatted container. Store as `DateTime?` state variables instead of `TextEditingController`.

Fields affected: `_start`, `_end`, `_deadline`.

### 1.3 Number field keyboard types

Add `keyboardType: TextInputType.number` to: fee, prize, team size, max teams.

### 1.4 Persist `_review` field

Add `'review_mode': _review` to the `create()` payload in `_submitImpl`. The `Event` model gains an optional `reviewMode` field (`String?`).

### 1.5 Inline error display

Add an `_errors` map (`Map<String, String?>`) to the state. The `_Field` widget gains an optional `errorText` parameter that renders red text below the input when non-null. On each "Next" press, run validation and populate `_errors`; clear individual errors on field change.

## Module 2: Schedule Publish — Validation

### 2.1 Required team labels

Before `_confirm()`, iterate all slots. Every slot must have both `teamALabel` and `teamBLabel` non-empty. If any are missing, show a Toast listing the first offending slot (e.g., "QF #3: please fill in both teams") and abort.

### 2.2 Time soft-warning

If any slot has `playedAt == null`, show a confirmation dialog: "N matches have no scheduled time. Continue anyway?" This is a warning, not a blocker — organizers may not know times yet.

### 2.3 Team count warning

After generating slots, if the number of registered teams (from `eventTeamsCountProvider`) is less than the minimum required for the template, show a warning banner at the top: "Only X teams registered, template requires at least Y."

Minimum teams per template:
- `knockout16`: 16
- `group8`: 8
- `league`: `teamsMax` (all must be filled)
- `wc`: 8

### 2.4 League match count fix

Current formula `maxTeams * (maxTeams - 1)` assumes double round-robin. This is correct for home-and-away leagues. No change needed — just add a label in the generate prompt clarifying "double round-robin" so the organizer understands.

## Module 3: Registration — Guards & Validation

### 3.1 Show register button only during registration

In `_BottomCta`, the "Register" row should only appear when `event.status == EventStatus.registering`. For other states:
- `ongoing` / `completed`: hide register button entirely
- `scheduling`: show "Registration closed" disabled text

### 3.2 Capacity check

Before opening the register sheet, read `eventTeamsCountProvider(event.id)`. If `count >= event.teamsMax`, show Toast "Registration full" and don't open the sheet. Also update the button label to "Full" and disable it.

### 3.3 Deadline check

Before opening the register sheet, check `event.deadline`. If `DateTime.now().isAfter(event.deadline!)`, show Toast "Registration deadline passed" and don't open the sheet. Update button to "Deadline passed".

### 3.4 Required fields in register form

| Field | Rule | Error key |
|-------|------|-----------|
| Team name | non-empty | `error_required_field` (existing) |
| Contact | non-empty | `validation_contact_required` |
| Phone | non-empty, digits only, length 11 | `validation_phone_required`, `validation_phone_format` |

### 3.5 Write to teams table

On successful registration, in addition to creating a conversation and toggling favorite, insert a row into the `teams` table:
```dart
await supabase.from('teams').insert({
  'event_id': event.id,
  'captain_id': currentUserId,
  'name': teamC.text.trim(),
  'contact': contactC.text.trim(),
  'phone': phoneC.text.trim(),
});
```

Add `insertTeam(Map<String, dynamic>)` to `EventsRepository`.

### 3.6 Prevent duplicate registration

Before opening register sheet, check if the current user already has a team in this event:
```dart
final existing = await supabase
    .from('teams')
    .select('id')
    .eq('event_id', event.id)
    .eq('captain_id', currentUserId)
    .maybeSingle();
```
If exists, show "Already registered" and don't open.

## Module 4: Event Lifecycle Transitions

### 4.1 Complete event (ongoing → completed)

Add a "Complete Event" button in `_BottomCta` when `status == ongoing` and `event.creatorId == currentUserId`. Requires confirmation dialog.

### 4.2 Auto-complete prompt

In `match_control_panel.dart`, after `endMatch()` succeeds, check if all matches for this event are now finished:
```dart
final matches = await ref.read(eventsRepoProvider).matchesFor(event.id);
final allDone = matches.every((m) => m.done);
```
If `allDone`, show a dialog: "All matches are finished. Mark event as completed?" If confirmed, call `updateEventStatus(eventId, EventStatus.completed)`.

### 4.3 Cancel event

Add `cancelEvent(String eventId)` to repository — sets status to a new `cancelled` status, or deletes the row (soft-delete preferred: add `cancelled` to `EventStatus` enum).

Show "Cancel Event" option for organizer when status is `draft`, `registering`, or `scheduling`. Requires confirmation with destructive styling.

`EventStatus` enum becomes: `draft, registering, scheduling, ongoing, completed, cancelled`.

### 4.4 Edit event

Add a route `/event/:id/edit` that opens the same create-event form pre-filled with existing data. Only available to the organizer, only when status is `draft`, `registering`, or `scheduling` (not during ongoing/completed).

Add `updateEvent(String id, Map<String, dynamic> payload)` to repository.

In event detail header, show an edit icon button (pencil) for the organizer when editable.

## Module 5: File Splitting

### 5.1 Create Event split

Current: `lib/features/create_event/create_event_screen.dart` (941 lines, 1 file)

Target structure:
```
lib/features/create_event/
  create_event_screen.dart    — Wizard scaffold, step navigation, validation, submit
  step_template.dart          — Step 1: template selection grid
  step_basic_info.dart        — Step 2: name, dates, venue, fee/prize
  step_registration.dart      — Step 3: deadline, review mode, team size, max teams
  step_preview.dart           — Step 4: cover upload, preview card
  event_form_fields.dart      — Shared _Field widget, date picker wrapper
  bracket_mini_painter.dart   — _BracketMiniPainter (CustomPainter)
```

Each step widget receives callbacks and controllers from the parent. The parent owns all state.

### 5.2 Event Detail split

Current: `lib/features/events/event_detail_screen.dart` (2627 lines, 1 file)

Target structure:
```
lib/features/events/
  event_detail_screen.dart          — Main scaffold, tab switching
  panels/
    overview_panel.dart             — Event info, rules, organizer card
    bracket_panel.dart              — Bracket tree, _MatchCard, _EmptyCell
    standings_panel.dart            — StandingRow, computeStandings, table
    scorers_panel.dart              — Golden/silver/bronze boot, leaderboard
    chat_panel.dart                 — Chat messages + input
  widgets/
    event_header.dart               — Cover image, status pill, title
    kpi_strip.dart                  — Teams/matches/prize counters
    bottom_cta.dart                 — CTA buttons (organizer actions + register/watch)
    register_sheet.dart             — Registration bottom sheet form
```

### 5.3 Split rules

- Each extracted file is a self-contained widget with explicit constructor parameters
- No global mutable state shared between files — pass data via constructor or provider
- Maintain all existing import paths — `event_detail_screen.dart` re-exports panels if any external file imports inner widgets directly (check routes.dart — none do, so no re-exports needed)

## Module 6: Shared Validation Utility

File: `lib/utils/event_validators.dart`

```dart
class EventValidators {
  /// Returns error string if empty, null if valid
  static String? required(String? value, String fieldLabel) { ... }

  /// Returns error if not a valid future date
  static String? futureDate(DateTime? date, String fieldLabel) { ... }

  /// Returns error if dateA is not before dateB
  static String? dateBefore(DateTime? dateA, DateTime? dateB, String labelA, String labelB) { ... }

  /// Returns error if not a positive integer
  static String? positiveInt(String? value, String fieldLabel) { ... }

  /// Returns error if int value < min
  static String? minInt(String? value, int min, String fieldLabel) { ... }

  /// Returns error if phone format is wrong (11 digits)
  static String? phone(String? value) { ... }
}
```

Used by: create event form (step 2, step 3), register sheet, edit event form.

## New L10N Keys

### Validation errors (zh / en)
```
validation_name_required: "请输入赛事名称" / "Event name is required"
validation_start_required: "请选择开始时间" / "Start time is required"
validation_start_future: "开始时间必须在当前之后" / "Start time must be in the future"
validation_end_required: "请选择结束时间" / "End time is required"
validation_end_after_start: "结束时间必须晚于开始时间" / "End time must be after start time"
validation_venue_required: "请输入场地" / "Venue is required"
validation_fee_positive: "费用不能为负数" / "Fee cannot be negative"
validation_prize_positive: "奖金不能为负数" / "Prize cannot be negative"
validation_deadline_required: "请选择报名截止日期" / "Registration deadline is required"
validation_deadline_before_start: "报名截止日期必须早于开始时间" / "Deadline must be before start time"
validation_team_size_positive: "每队人数必须大于0" / "Team size must be greater than 0"
validation_max_teams_min: "最大队伍数不能少于2" / "Must have at least 2 teams"
validation_contact_required: "请输入联系人" / "Contact person is required"
validation_phone_required: "请输入联系电话" / "Phone number is required"
validation_phone_format: "请输入有效的手机号码" / "Please enter a valid phone number"
```

### Schedule validation
```
schedule_teams_required: "请填写所有比赛的双方队伍名称" / "Please fill in team names for all matches"
schedule_slot_missing_teams: "{round} #{index}: 请填写双方队伍" / "{round} #{index}: please fill in both teams"
schedule_time_warning: "{count}场比赛尚未设置时间，是否继续？" / "{count} matches have no scheduled time. Continue?"
schedule_teams_insufficient: "已报名{registered}支队伍，模板至少需要{required}支" / "{registered} teams registered, template requires at least {required}"
```

### Lifecycle actions
```
event_complete: "结束赛事" / "Complete Event"
event_complete_confirm: "确认将赛事标记为已完赛？此操作不可撤销。" / "Mark event as completed? This cannot be undone."
event_complete_success: "赛事已完赛" / "Event completed"
event_cancel: "取消赛事" / "Cancel Event"
event_cancel_confirm: "确认取消此赛事？已报名的队伍将收到通知。" / "Cancel this event? Registered teams will be notified."
event_cancel_success: "赛事已取消" / "Event cancelled"
event_edit: "编辑赛事" / "Edit Event"
event_edit_success: "赛事信息已更新" / "Event updated"
event_status_cancelled: "已取消" / "Cancelled"
event_registration_full: "报名已满" / "Registration full"
event_registration_closed: "报名已截止" / "Registration closed"
event_registration_deadline_passed: "报名截止日期已过" / "Registration deadline passed"
event_already_registered: "你已报名此赛事" / "Already registered"
event_all_matches_done: "所有比赛已结束，是否标记赛事为已完赛？" / "All matches finished. Mark event as completed?"
```

## Model Changes

### Event model (`lib/models/event.dart`)

Add fields:
```dart
final String? reviewMode;  // 'auto' | 'manual'
```

Add to `EventStatus` enum:
```dart
enum EventStatus { draft, registering, scheduling, ongoing, completed, cancelled }
```

Update `_parseEventStatus` to handle `'cancelled'`.

Update `Event.fromMap` to parse `review_mode`.

## Repository Changes

### EventsRepository (`lib/repositories/events_repository.dart`)

Add methods:
```dart
Future<void> updateEvent(String id, Map<String, dynamic> payload);
Future<void> cancelEvent(String eventId);
Future<void> insertTeam(Map<String, dynamic> payload);
Future<bool> isUserRegistered(String eventId, String userId);
```

## Route Changes

### routes.dart

Add:
```dart
GoRoute(
  path: '/event/:id/edit',
  builder: (_, s) => CreateEventScreen(editEventId: s.pathParameters['id']),
),
```

`CreateEventScreen` gains an optional `editEventId` parameter. When non-null, it fetches the event and pre-fills the form, and submits via `updateEvent` instead of `create`.

## Non-goals

- Push notifications to teams on event cancel/complete (future work)
- Payment integration for fee collection (future work)
- Manual review approval flow UI (tracked via `review_mode` field but admin UI is out of scope)
- Supabase RLS policies (assumed to be handled separately)
