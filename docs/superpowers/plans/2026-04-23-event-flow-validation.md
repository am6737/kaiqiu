# Event Flow Validation & Completeness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all validation gaps, flow logic issues, and UX friction in the event lifecycle from creation through completion.

**Architecture:** Six sequential modules. Module 6 (validators) is implemented first because Modules 1-4 depend on it. Module 5 (file splitting) is done last since it restructures files that Modules 1-4 modify. Each module produces a working, committable state.

**Tech Stack:** Flutter/Dart, Riverpod, Supabase, go_router, ARB l10n

**Spec:** `docs/superpowers/specs/2026-04-23-event-flow-validation-design.md`

---

## File Structure

### New files
```
lib/utils/event_validators.dart                          — Shared validation functions
lib/features/create_event/step_template.dart             — Step 1 widget
lib/features/create_event/step_basic_info.dart           — Step 2 widget
lib/features/create_event/step_registration.dart         — Step 3 widget
lib/features/create_event/step_preview.dart              — Step 4 widget
lib/features/create_event/event_form_fields.dart         — Shared field widgets + date picker
lib/features/create_event/bracket_mini_painter.dart      — CustomPainter extracted
lib/features/events/panels/overview_panel.dart            — Overview tab
lib/features/events/panels/bracket_panel.dart             — Bracket tab + MatchCard + EmptyCell
lib/features/events/panels/standings_panel.dart           — Standings tab + computeStandings
lib/features/events/panels/scorers_panel.dart             — Scorers tab
lib/features/events/panels/chat_panel.dart                — Chat tab + input
lib/features/events/widgets/event_header.dart             — Header with cover/status/title
lib/features/events/widgets/kpi_strip.dart                — KPI counters
lib/features/events/widgets/bottom_cta.dart               — CTA buttons + organizer actions
lib/features/events/widgets/register_sheet.dart           — Registration bottom sheet
```

### Modified files
```
lib/models/event.dart                                    — Add reviewMode, cancelled status
lib/repositories/events_repository.dart                  — Add updateEvent, cancelEvent, insertTeam, isUserRegistered
lib/providers.dart                                       — Add isUserRegisteredProvider
lib/l10n/app_zh.arb                                      — Add ~30 new l10n keys
lib/l10n/app_en.arb                                      — Add ~30 new l10n keys
lib/features/create_event/create_event_screen.dart       — Validation + date pickers + edit mode + split
lib/features/events/schedule_matches_screen.dart         — Validation before confirm
lib/features/events/event_detail_screen.dart             — Split into sub-files + flow guards
lib/features/events/match_control_panel.dart             — Auto-complete prompt after endMatch
lib/routes.dart                                          — Add /event/:id/edit route
```

---

### Task 1: Add L10N Keys

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

All subsequent tasks depend on these keys existing. Add them all upfront.

- [ ] **Step 1: Add validation keys to app_zh.arb**

Add the following entries before the closing `}` of `lib/l10n/app_zh.arb`:

```json
"validation_name_required": "请输入赛事名称",
"validation_start_required": "请选择开始时间",
"validation_start_future": "开始时间必须在当前之后",
"validation_end_required": "请选择结束时间",
"validation_end_after_start": "结束时间必须晚于开始时间",
"validation_venue_required": "请输入场地",
"validation_fee_positive": "费用不能为负数",
"validation_prize_positive": "奖金不能为负数",
"validation_deadline_required": "请选择报名截止日期",
"validation_deadline_before_start": "报名截止日期必须早于开始时间",
"validation_team_size_positive": "每队人数必须大于0",
"validation_max_teams_min": "最大队伍数不能少于2",
"validation_contact_required": "请输入联系人",
"validation_phone_required": "请输入联系电话",
"validation_phone_format": "请输入有效的手机号码",

"schedule_teams_required": "请填写所有比赛的双方队伍名称",
"schedule_slot_missing_teams": "{round} #{index}: 请填写双方队伍",
"@schedule_slot_missing_teams": { "placeholders": { "round": {}, "index": {} } },
"schedule_time_warning_title": "部分比赛未设置时间",
"schedule_time_warning_body": "{count}场比赛尚未设置时间，是否继续？",
"@schedule_time_warning_body": { "placeholders": { "count": {} } },
"schedule_teams_insufficient": "已报名{registered}支队伍，模板至少需要{required}支",
"@schedule_teams_insufficient": { "placeholders": { "registered": {}, "required": {} } },

"event_complete": "结束赛事",
"event_complete_confirm": "确认将赛事标记为已完赛？此操作不可撤销。",
"event_complete_success": "赛事已完赛",
"event_cancel": "取消赛事",
"event_cancel_confirm": "确认取消此赛事？已报名的队伍将收到通知。",
"event_cancel_success": "赛事已取消",
"event_edit": "编辑赛事",
"event_edit_success": "赛事信息已更新",
"event_status_cancelled": "已取消",
"event_registration_full": "报名已满",
"event_registration_closed": "报名已截止",
"event_registration_deadline_passed": "报名截止日期已过",
"event_already_registered": "你已报名此赛事",
"event_all_matches_done": "所有比赛已结束，是否标记赛事为已完赛？"
```

- [ ] **Step 2: Add validation keys to app_en.arb**

Add the following entries before the closing `}` of `lib/l10n/app_en.arb`:

```json
"validation_name_required": "Event name is required",
"validation_start_required": "Start time is required",
"validation_start_future": "Start time must be in the future",
"validation_end_required": "End time is required",
"validation_end_after_start": "End time must be after start time",
"validation_venue_required": "Venue is required",
"validation_fee_positive": "Fee cannot be negative",
"validation_prize_positive": "Prize cannot be negative",
"validation_deadline_required": "Registration deadline is required",
"validation_deadline_before_start": "Deadline must be before start time",
"validation_team_size_positive": "Team size must be greater than 0",
"validation_max_teams_min": "Must have at least 2 teams",
"validation_contact_required": "Contact person is required",
"validation_phone_required": "Phone number is required",
"validation_phone_format": "Please enter a valid phone number",

"schedule_teams_required": "Please fill in team names for all matches",
"schedule_slot_missing_teams": "{round} #{index}: please fill in both teams",
"@schedule_slot_missing_teams": { "placeholders": { "round": {}, "index": {} } },
"schedule_time_warning_title": "Some matches have no time",
"schedule_time_warning_body": "{count} matches have no scheduled time. Continue?",
"@schedule_time_warning_body": { "placeholders": { "count": {} } },
"schedule_teams_insufficient": "{registered} teams registered, template requires at least {required}",
"@schedule_teams_insufficient": { "placeholders": { "registered": {}, "required": {} } },

"event_complete": "Complete Event",
"event_complete_confirm": "Mark event as completed? This cannot be undone.",
"event_complete_success": "Event completed",
"event_cancel": "Cancel Event",
"event_cancel_confirm": "Cancel this event? Registered teams will be notified.",
"event_cancel_success": "Event cancelled",
"event_edit": "Edit Event",
"event_edit_success": "Event updated",
"event_status_cancelled": "Cancelled",
"event_registration_full": "Registration full",
"event_registration_closed": "Registration closed",
"event_registration_deadline_passed": "Registration deadline passed",
"event_already_registered": "Already registered",
"event_all_matches_done": "All matches finished. Mark event as completed?"
```

- [ ] **Step 3: Regenerate l10n**

Run: `flutter gen-l10n`

Expected: Generated files updated in `lib/l10n/generated/`.

- [ ] **Step 4: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors related to missing l10n keys.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add validation and lifecycle l10n keys for event flow"
```

---

### Task 2: Model & Repository Changes

**Files:**
- Modify: `lib/models/event.dart`
- Modify: `lib/repositories/events_repository.dart`
- Modify: `lib/providers.dart`

- [ ] **Step 1: Add `cancelled` to EventStatus and `reviewMode` to Event**

In `lib/models/event.dart`:

Change the enum:
```dart
enum EventStatus { draft, registering, scheduling, ongoing, completed, cancelled }
```

Update `_parseEventStatus`:
```dart
EventStatus _parseEventStatus(String? s) => switch (s) {
  'draft' => EventStatus.draft,
  'scheduling' => EventStatus.scheduling,
  'ongoing' => EventStatus.ongoing,
  'completed' || 'done' => EventStatus.completed,
  'cancelled' => EventStatus.cancelled,
  _ => EventStatus.registering,
};
```

Add `reviewMode` field to `Event` class:
```dart
class Event {
  final String id;
  final String? creatorId;
  final String name;
  final String? sub;
  final String? city;
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

  const Event({
    required this.id,
    this.creatorId,
    required this.name,
    this.sub,
    this.city,
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

  factory Event.fromMap(Map<String, dynamic> m) => Event(
    id: m['id'] as String,
    creatorId: m['creator_id'] as String?,
    name: m['name'] as String,
    sub: m['sub'] as String?,
    city: m['city'] as String?,
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
}
```

- [ ] **Step 2: Add repository methods**

In `lib/repositories/events_repository.dart`, add these methods to the `EventsRepository` class (before the closing `}`):

```dart
Future<void> updateEvent(String id, Map<String, dynamic> payload) async {
  await supabase.from('events').update(payload).eq('id', id);
}

Future<void> cancelEvent(String eventId) async {
  await supabase
      .from('events')
      .update({'status': 'cancelled'})
      .eq('id', eventId);
}

Future<void> insertTeam(Map<String, dynamic> payload) async {
  await supabase.from('teams').insert(payload);
}

Future<bool> isUserRegistered(String eventId, String userId) async {
  final row = await supabase
      .from('teams')
      .select('id')
      .eq('event_id', eventId)
      .eq('captain_id', userId)
      .maybeSingle();
  return row != null;
}
```

- [ ] **Step 3: Add isUserRegisteredProvider**

In `lib/providers.dart`, add after the `eventTeamsCountProvider`:

```dart
final isUserRegisteredProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final uid = currentUserId;
  if (uid == null) return false;
  return ref.read(eventsRepoProvider).isUserRegistered(eventId, uid);
});
```

Import `currentUserId` if not already imported (it comes from `services/supabase.dart` which is already imported in providers.dart).

- [ ] **Step 4: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors. The `cancelled` status is additive, so existing switch statements will still compile (they use `_` default cases).

- [ ] **Step 5: Commit**

```bash
git add lib/models/event.dart lib/repositories/events_repository.dart lib/providers.dart
git commit -m "feat(event): add cancelled status, reviewMode field, and registration repository methods"
```

---

### Task 3: Shared Validation Utility

**Files:**
- Create: `lib/utils/event_validators.dart`

- [ ] **Step 1: Create the event validators file**

Create `lib/utils/event_validators.dart`:

```dart
import '../l10n/generated/app_localizations.dart';

class EventValidators {
  static String? requiredText(String? value, String errorMsg) {
    if ((value ?? '').trim().isEmpty) return errorMsg;
    return null;
  }

  static String? futureDate(DateTime? date, String requiredMsg, String futureMsg) {
    if (date == null) return requiredMsg;
    if (!date.isAfter(DateTime.now())) return futureMsg;
    return null;
  }

  static String? dateAfter(DateTime? date, DateTime? after, String requiredMsg, String afterMsg) {
    if (date == null) return requiredMsg;
    if (after != null && !date.isAfter(after)) return afterMsg;
    return null;
  }

  static String? dateBefore(DateTime? date, DateTime? before, String requiredMsg, String beforeMsg) {
    if (date == null) return requiredMsg;
    if (before != null && !date.isBefore(before)) return beforeMsg;
    return null;
  }

  static String? nonNegativeInt(String? value, String errorMsg) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null || n < 0) return errorMsg;
    return null;
  }

  static String? positiveInt(String? value, String errorMsg) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return errorMsg;
    final n = int.tryParse(s);
    if (n == null || n <= 0) return errorMsg;
    return null;
  }

  static String? minInt(String? value, int min, String errorMsg) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return errorMsg;
    final n = int.tryParse(s);
    if (n == null || n < min) return errorMsg;
    return null;
  }

  static String? phone(String? value, String requiredMsg, String formatMsg) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return requiredMsg;
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(s)) return formatMsg;
    return null;
  }
}
```

- [ ] **Step 2: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/utils/event_validators.dart
git commit -m "feat(utils): add EventValidators for event form validation"
```

---

### Task 4: Create Event — Step-level Validation & Date Pickers

**Files:**
- Modify: `lib/features/create_event/create_event_screen.dart`

This is the largest single task. We modify the existing file to add:
1. Step-level validation on "Next" press
2. Date fields using DatePicker instead of raw text
3. Number field keyboard types
4. Persist `_review` field
5. Inline error display
6. Edit mode support (optional `editEventId`)

- [ ] **Step 1: Replace date TextEditingControllers with DateTime? state vars and add errors map + edit support**

In `lib/features/create_event/create_event_screen.dart`, replace the state class fields and add edit mode:

Change `CreateEventScreen` to accept optional edit ID:
```dart
class CreateEventScreen extends ConsumerStatefulWidget {
  final String? editEventId;
  const CreateEventScreen({super.key, this.editEventId});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}
```

Replace the state variable block in `_CreateEventScreenState`:
```dart
class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  bool _submitting = false;
  int _step = 1;
  String _tpl = 'knockout16';
  final _name = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _venue = TextEditingController();
  final _fee = TextEditingController();
  final _prize = TextEditingController();
  DateTime? _deadlineDate;
  final _teamSize = TextEditingController();
  final _maxTeams = TextEditingController();
  String _review = 'auto';
  String? _coverUrl;
  bool _uploadingCover = false;
  Map<String, String?> _errors = {};
  bool _editMode = false;
```

Remove `_start`, `_end`, `_deadline` from the `dispose()` method (they are no longer TextEditingControllers). Update the dispose:
```dart
@override
void dispose() {
  for (final c in [_name, _venue, _fee, _prize, _teamSize, _maxTeams]) {
    c.dispose();
  }
  super.dispose();
}
```

Add `initState` for edit mode:
```dart
@override
void initState() {
  super.initState();
  if (widget.editEventId != null) {
    _editMode = true;
    _loadEvent();
  }
}

Future<void> _loadEvent() async {
  try {
    final event = await ref.read(eventsRepoProvider).fetch(widget.editEventId!);
    setState(() {
      _tpl = event.template ?? 'knockout16';
      _name.text = event.name;
      _startDate = event.startsAt;
      _endDate = event.endsAt;
      _venue.text = event.sub ?? '';
      _fee.text = event.feeCents != null ? '${event.feeCents! ~/ 100}' : '';
      _prize.text = event.prizeCents != null ? '${event.prizeCents! ~/ 100}' : '';
      _deadlineDate = event.deadline;
      _teamSize.text = '${event.teamSize}';
      _maxTeams.text = event.teamsMax != null ? '${event.teamsMax}' : '';
      _review = event.reviewMode ?? 'auto';
      _coverUrl = event.coverUrl;
    });
  } catch (e) {
    if (mounted) showToast(context, '$e', error: true);
  }
}
```

- [ ] **Step 2: Add step-level validation method**

Add this method to `_CreateEventScreenState`:

```dart
bool _validateStep(int step) {
  final l = context.l10n;
  final errors = <String, String?>{};

  if (step == 2) {
    if (_name.text.trim().isEmpty) errors['name'] = l.validation_name_required;
    if (_startDate == null) {
      errors['start'] = l.validation_start_required;
    } else if (!_startDate!.isAfter(DateTime.now())) {
      errors['start'] = l.validation_start_future;
    }
    if (_endDate == null) {
      errors['end'] = l.validation_end_required;
    } else if (_startDate != null && !_endDate!.isAfter(_startDate!)) {
      errors['end'] = l.validation_end_after_start;
    }
    if (_venue.text.trim().isEmpty) errors['venue'] = l.validation_venue_required;
    final feeVal = _fee.text.trim();
    if (feeVal.isNotEmpty) {
      final n = int.tryParse(feeVal);
      if (n == null || n < 0) errors['fee'] = l.validation_fee_positive;
    }
    final prizeVal = _prize.text.trim();
    if (prizeVal.isNotEmpty) {
      final n = int.tryParse(prizeVal);
      if (n == null || n < 0) errors['prize'] = l.validation_prize_positive;
    }
  } else if (step == 3) {
    if (_deadlineDate == null) {
      errors['deadline'] = l.validation_deadline_required;
    } else if (_startDate != null && !_deadlineDate!.isBefore(_startDate!)) {
      errors['deadline'] = l.validation_deadline_before_start;
    }
    final tsVal = _teamSize.text.trim();
    if (tsVal.isNotEmpty) {
      final n = int.tryParse(tsVal);
      if (n == null || n <= 0) errors['teamSize'] = l.validation_team_size_positive;
    }
    final mtVal = _maxTeams.text.trim();
    if (mtVal.isNotEmpty) {
      final n = int.tryParse(mtVal);
      if (n == null || n < 2) errors['maxTeams'] = l.validation_max_teams_min;
    }
  }

  setState(() => _errors = errors);
  return errors.isEmpty;
}
```

- [ ] **Step 3: Update the "Next" / "Publish" button to call validation**

Replace the `onPressed` callback in the bottom sheet's `Expanded` `PrimaryButton`:

```dart
onPressed: _submitting
    ? null
    : () {
        if (_step < 4) {
          if (_step == 1 || _validateStep(_step)) {
            setState(() => _step++);
          }
        } else {
          _submit();
        }
      },
```

- [ ] **Step 4: Add date picker helper and update _Field to support errorText**

Add a date picker helper method to `_CreateEventScreenState`:

```dart
Future<DateTime?> _pickDateTime({DateTime? initial}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );
  if (date == null || !mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial ?? const TimeOfDay(hour: 15, minute: 0) as DateTime? ?? DateTime.now()),
  );
  if (time == null) return DateTime(date.year, date.month, date.day);
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _fmtDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
```

Update the `_Field` widget to support `errorText`:

```dart
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final bool mono;
  final TextInputType? keyboardType;
  final String? errorText;
  const _Field({
    required this.label,
    required this.controller,
    this.prefix,
    this.mono = false,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(
                color: errorText != null ? context.tokens.danger : context.tokens.line,
              ),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: N(prefix!, size: 15, color: context.tokens.inkDim),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: context.tokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: mono ? context.tokens.fontMono : null,
                      fontFamilyFallback: mono ? context.tokens.monoFallbacks : null,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText!,
                style: TextStyle(fontSize: 11, color: context.tokens.danger),
              ),
            ),
        ],
      ),
    );
  }
}
```

Add a `_DateField` widget for date inputs:

```dart
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(
                  color: errorText != null ? context.tokens.danger : context.tokens.line,
                ),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: context.tokens.inkSub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value != null
                          ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')} ${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
                          : '',
                      style: TextStyle(
                        color: value != null ? context.tokens.ink : context.tokens.inkDim,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText!,
                style: TextStyle(fontSize: 11, color: context.tokens.danger),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Update _step2 to use DateField and error display**

Replace the `_step2()` method:

```dart
Widget _step2() {
  final l = context.l10n;
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
        _Field(label: l.create_event_f_name, controller: _name, errorText: _errors['name']),
        Row(
          children: [
            Expanded(
              child: _DateField(
                label: l.create_event_f_start,
                value: _startDate,
                errorText: _errors['start'],
                onTap: () async {
                  final dt = await _pickDateTime(initial: _startDate);
                  if (dt != null) setState(() { _startDate = dt; _errors.remove('start'); });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DateField(
                label: l.create_event_f_end,
                value: _endDate,
                errorText: _errors['end'],
                onTap: () async {
                  final dt = await _pickDateTime(initial: _endDate ?? _startDate);
                  if (dt != null) setState(() { _endDate = dt; _errors.remove('end'); });
                },
              ),
            ),
          ],
        ),
        _Field(label: l.create_event_f_venue, controller: _venue, errorText: _errors['venue']),
        Row(
          children: [
            Expanded(
              child: _Field(
                label: l.create_event_f_fee,
                controller: _fee,
                prefix: '¥',
                mono: true,
                keyboardType: TextInputType.number,
                errorText: _errors['fee'],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Field(
                label: l.create_event_f_prize,
                controller: _prize,
                prefix: '¥',
                mono: true,
                keyboardType: TextInputType.number,
                errorText: _errors['prize'],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 6: Update _step3 to use DateField, keyboardType, and errors**

Replace the `_step3()` method:

```dart
Widget _step3() {
  final l = context.l10n;
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.create_event_step_registration,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 18),
        _DateField(
          label: l.create_event_f_deadline,
          value: _deadlineDate,
          errorText: _errors['deadline'],
          onTap: () async {
            final dt = await _pickDateTime(initial: _deadlineDate ?? _startDate);
            if (dt != null) setState(() { _deadlineDate = dt; _errors.remove('deadline'); });
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Label(l.create_event_review_title),
        ),
        Row(
          children: [
            for (final opt in [
              ('auto', l.create_event_review_auto),
              ('manual', l.create_event_review_manual),
            ]) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _review = opt.$1),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _review == opt.$1 ? context.tokens.elev3 : context.tokens.elev2,
                      border: Border.all(
                        color: _review == opt.$1 ? context.tokens.accent : context.tokens.line,
                      ),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _review == opt.$1 ? context.tokens.accent : context.tokens.ink,
                      ),
                    ),
                  ),
                ),
              ),
              if (opt.$1 == 'auto') const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Field(
                label: l.create_event_f_teamsize,
                controller: _teamSize,
                mono: true,
                keyboardType: TextInputType.number,
                errorText: _errors['teamSize'],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Field(
                label: l.create_event_f_maxteams,
                controller: _maxTeams,
                mono: true,
                keyboardType: TextInputType.number,
                errorText: _errors['maxTeams'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tokens.elev2,
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(context.tokens.r2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, size: 14, color: context.tokens.warn),
                  const SizedBox(width: 8),
                  Label(l.create_event_organizer_tip_title, color: context.tokens.warn),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.create_event_organizer_tip_body,
                style: TextStyle(fontSize: 12, color: context.tokens.inkSub, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 7: Update _step4 preview to use DateTime state vars**

In `_step4()`, update references from `_start.text` to `_startDate`, etc:

Replace the `_previewStat` calls in `_step4()`:
```dart
_previewStat(
  l.home_event_kickoff,
  _startDate != null
      ? '${_startDate!.month}/${_startDate!.day}'
      : '-',
),
```

Replace the `Label` at the bottom:
```dart
Label(
  l.create_event_preview_registered_of_max(
    _maxTeams.text.isNotEmpty ? _maxTeams.text : '16',
    _deadlineDate != null
        ? '${_deadlineDate!.month}/${_deadlineDate!.day}'
        : '-',
  ),
),
```

Also update the config check banner — replace the existing green `Container` with:
```dart
Builder(builder: (_) {
  final hasName = _name.text.trim().isNotEmpty;
  final hasStart = _startDate != null;
  final hasEnd = _endDate != null;
  final hasVenue = _venue.text.trim().isNotEmpty;
  final hasDeadline = _deadlineDate != null;
  final configOk = hasName && hasStart && hasEnd && hasVenue && hasDeadline;
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: configOk ? context.tokens.accentSubtle : context.tokens.elev2,
      border: Border.all(color: configOk ? const Color(0x6600FF85) : context.tokens.warn),
      borderRadius: BorderRadius.circular(context.tokens.r2),
    ),
    child: Row(
      children: [
        Icon(
          configOk ? Icons.check : Icons.warning_amber,
          size: 14,
          color: configOk ? context.tokens.accent : context.tokens.warn,
        ),
        const SizedBox(width: 8),
        Text(
          configOk ? l.create_event_preview_config_ok : l.error_required_field,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: configOk ? context.tokens.accent : context.tokens.warn,
          ),
        ),
      ],
    ),
  );
}),
```

- [ ] **Step 8: Update _submitImpl to use DateTime vars and persist reviewMode**

Replace `_submitImpl()`:

```dart
Future<void> _submitImpl() async {
  final l = context.l10n;
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return;
  try {
    final payload = {
      'name': _name.text.trim(),
      'sub': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
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

    if (_editMode && widget.editEventId != null) {
      await ref.read(eventsRepoProvider).updateEvent(widget.editEventId!, payload);
      ref.invalidate(eventDetailProvider(widget.editEventId!));
      if (!mounted) return;
      showToast(context, l.event_edit_success, success: true);
    } else {
      payload['creator_id'] = uid;
      await ref.read(eventsRepoProvider).create(payload);
      ref.invalidate(liveEventsProvider(EventStatus.registering));
      ref.invalidate(myHostedEventsProvider);
      if (!mounted) return;
      showToast(context, l.create_event_published, success: true);
    }
    context.go('/events');
  } catch (e) {
    if (!mounted) return;
    showToast(context, l.create_event_publish_failed('$e'), error: true);
  } finally {
    if (mounted) setState(() => _submitting = false);
  }
}
```

Update the title in the `build` method to show "Edit" vs "Create":
```dart
Text(
  _editMode ? l.event_edit : l.create_event_title,
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: context.tokens.ink,
  ),
),
```

- [ ] **Step 9: Fix _pickDateTime helper (correct TimeOfDay initialization)**

Replace the `_pickDateTime` method with the corrected version:

```dart
Future<DateTime?> _pickDateTime({DateTime? initial}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );
  if (date == null || !mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: initial != null
        ? TimeOfDay(hour: initial.hour, minute: initial.minute)
        : const TimeOfDay(hour: 15, minute: 0),
  );
  if (time == null) return DateTime(date.year, date.month, date.day);
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
```

- [ ] **Step 10: Add edit route to routes.dart**

In `lib/routes.dart`, add the import change and route. After the `/create-event` route:

```dart
GoRoute(
  path: '/event/:id/edit',
  builder: (_, s) => CreateEventScreen(editEventId: s.pathParameters['id']),
),
```

- [ ] **Step 11: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors.

- [ ] **Step 12: Commit**

```bash
git add lib/features/create_event/create_event_screen.dart lib/routes.dart
git commit -m "feat(create-event): add step validation, date pickers, edit mode, and reviewMode persistence"
```

---

### Task 5: Schedule Publish — Validation

**Files:**
- Modify: `lib/features/events/schedule_matches_screen.dart`

- [ ] **Step 1: Add validation before _confirm**

In `lib/features/events/schedule_matches_screen.dart`, replace the `_confirm` method:

```dart
Future<void> _confirm(Event event) async {
  final l = context.l10n;

  // Validate all slots have both team labels
  for (int i = 0; i < _slots.length; i++) {
    final s = _slots[i];
    if ((s.teamALabel ?? '').trim().isEmpty || (s.teamBLabel ?? '').trim().isEmpty) {
      showToast(
        context,
        l.schedule_slot_missing_teams(s.round.toUpperCase(), '${s.index + 1}'),
        error: true,
      );
      return;
    }
  }

  // Soft-warn about missing times
  final noTime = _slots.where((s) => s.playedAt == null).length;
  if (noTime > 0) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.schedule_time_warning_title),
        content: Text(l.schedule_time_warning_body('$noTime')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
  }

  setState(() => _busy = true);
  try {
    final rows = _slots.map((s) => {
      'event_id': event.id,
      'round': s.round,
      'team_a_label': s.teamALabel,
      'team_b_label': s.teamBLabel,
      'played_at': s.playedAt?.toUtc().toIso8601String(),
      'status': 'upcoming',
      'done': false,
    }).toList();
    await ref.read(eventsRepoProvider).insertMatches(rows);
    await ref
        .read(eventsRepoProvider)
        .updateEventStatus(event.id, EventStatus.ongoing);
    ref.invalidate(eventMatchesProvider(event.id));
    ref.invalidate(eventDetailProvider(event.id));
    if (mounted) {
      showToast(context, l.schedule_confirm, success: true);
      context.pop();
    }
  } catch (e) {
    if (mounted) showToast(context, '$e', error: true);
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

- [ ] **Step 2: Add team count warning after generate**

Update `_generate` to show a warning if registered teams are insufficient. Replace `_generate`:

```dart
void _generate(Event event) {
  final template = event.template ?? 'knockout16';
  final slots = <_MatchSlot>[];

  switch (template) {
    case 'knockout16':
      for (var i = 0; i < 8; i++) slots.add(_MatchSlot(round: 'qf', index: i));
      for (var i = 0; i < 4; i++) slots.add(_MatchSlot(round: 'sf', index: i));
      slots.add(_MatchSlot(round: 'final', index: 0));
    case 'group8':
      for (var g = 0; g < 2; g++) {
        for (var i = 0; i < 6; i++) slots.add(_MatchSlot(round: 'group', index: g * 6 + i));
      }
      for (var i = 0; i < 2; i++) slots.add(_MatchSlot(round: 'sf', index: i));
      slots.add(_MatchSlot(round: 'final', index: 0));
    case 'league':
      final maxTeams = event.teamsMax ?? 8;
      final totalMatches = maxTeams * (maxTeams - 1);
      for (var i = 0; i < totalMatches; i++) slots.add(_MatchSlot(round: 'league', index: i));
    default:
      for (var i = 0; i < 15; i++) slots.add(_MatchSlot(round: 'group', index: i));
  }

  setState(() {
    _slots = slots;
    _generated = true;
  });

  // Check team count
  final minTeams = switch (template) {
    'knockout16' => 16,
    'group8' => 8,
    'wc' => 8,
    'league' => event.teamsMax ?? 8,
    _ => 8,
  };
  final teamsCount = ref.read(eventTeamsCountProvider(event.id)).valueOrNull ?? 0;
  if (teamsCount < minTeams && mounted) {
    showToast(
      context,
      context.l10n.schedule_teams_insufficient('$teamsCount', '$minTeams'),
    );
  }
}
```

- [ ] **Step 3: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/events/schedule_matches_screen.dart
git commit -m "feat(schedule): add team label validation, time soft-warning, and team count check"
```

---

### Task 6: Registration Guards & Validation

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart` (bottom CTA and register sheet sections, lines ~2400-2627)

- [ ] **Step 1: Update _BottomCta to guard registration by status, capacity, deadline, and duplicate**

Replace the `_BottomCta` class (lines 2401-2584) in `lib/features/events/event_detail_screen.dart`:

```dart
class _BottomCta extends ConsumerWidget {
  final Event event;
  const _BottomCta({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final registered = LocalStore.isEventFavorited(event.id);
    final isCreator = event.creatorId != null && event.creatorId == currentUserId;
    final teamsCount = ref.watch(eventTeamsCountProvider(event.id)).valueOrNull ?? 0;
    final isFull = event.teamsMax != null && teamsCount >= event.teamsMax!;
    final deadlinePassed = event.deadline != null && DateTime.now().isAfter(event.deadline!);
    final isRegistering = event.status == EventStatus.registering;

    String? disabledReason;
    if (registered) {
      disabledReason = l.event_already_registered;
    } else if (!isRegistering) {
      disabledReason = l.event_registration_closed;
    } else if (isFull) {
      disabledReason = l.event_registration_full;
    } else if (deadlinePassed) {
      disabledReason = l.event_registration_deadline_passed;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCreator) ...[
            if (event.status == EventStatus.registering)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrimaryButton(
                  label: l.event_close_registration,
                  full: true,
                  size: BtnSize.lg,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.event_close_registration),
                        content: Text(l.event_close_registration_confirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.scheduling);
                    ref.invalidate(eventDetailProvider(event.id));
                  },
                ),
              ),
            if (event.status == EventStatus.scheduling)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrimaryButton(
                  label: l.schedule_generate,
                  full: true,
                  size: BtnSize.lg,
                  onPressed: () => context.push('/event/${event.id}/schedule'),
                ),
              ),
            if (event.status == EventStatus.ongoing)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrimaryButton(
                  label: l.event_complete,
                  full: true,
                  size: BtnSize.lg,
                  variant: BtnVariant.warn,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l.event_complete),
                        content: Text(l.event_complete_confirm),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.completed);
                    ref.invalidate(eventDetailProvider(event.id));
                    if (context.mounted) showToast(context, l.event_complete_success, success: true);
                  },
                ),
              ),
            if (event.status == EventStatus.draft ||
                event.status == EventStatus.registering ||
                event.status == EventStatus.scheduling) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: l.event_edit,
                        variant: BtnVariant.ghost,
                        size: BtnSize.lg,
                        full: true,
                        onPressed: () => context.push('/event/${event.id}/edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: l.event_cancel,
                        variant: BtnVariant.warn,
                        size: BtnSize.lg,
                        full: true,
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l.event_cancel),
                              content: Text(l.event_cancel_confirm),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          await ref.read(eventsRepoProvider).cancelEvent(event.id);
                          ref.invalidate(eventDetailProvider(event.id));
                          ref.invalidate(myHostedEventsProvider);
                          if (context.mounted) {
                            showToast(context, l.event_cancel_success, success: true);
                            context.go('/events');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  variant: BtnVariant.ghost,
                  size: BtnSize.lg,
                  full: true,
                  onPressed: () => context.push('/worldcup/live/${event.id}'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tv, size: 16, color: context.tokens.ink),
                      const SizedBox(width: 6),
                      Text(
                        l.event_cta_watch_live,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isRegistering) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: disabledReason ?? l.event_cta_register,
                    variant: disabledReason != null ? BtnVariant.secondary : BtnVariant.primary,
                    size: BtnSize.lg,
                    full: true,
                    onPressed: disabledReason != null
                        ? null
                        : () => _showRegisterSheet(context, ref),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRegisterSheet(BuildContext context, WidgetRef ref) async {
    // Double-check duplicate registration
    final uid = currentUserId;
    if (uid != null) {
      final alreadyRegistered = await ref.read(eventsRepoProvider).isUserRegistered(event.id, uid);
      if (alreadyRegistered && context.mounted) {
        showToast(context, context.l10n.event_already_registered, error: true);
        return;
      }
    }

    if (!context.mounted) return;
    final l = context.l10n;
    final teamC = TextEditingController();
    final contactC = TextEditingController();
    final phoneC = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
                l.event_register_form_title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 16),
              _RegField(label: l.event_register_team_name, controller: teamC),
              _RegField(label: l.event_register_contact, controller: contactC),
              _RegField(
                label: l.event_register_phone,
                controller: phoneC,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: l.event_register_submit,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: () async {
                  if (teamC.text.trim().isEmpty) {
                    showToast(ctx, l.error_required_field, error: true);
                    return;
                  }
                  if (contactC.text.trim().isEmpty) {
                    showToast(ctx, l.validation_contact_required, error: true);
                    return;
                  }
                  if (phoneC.text.trim().isEmpty) {
                    showToast(ctx, l.validation_phone_required, error: true);
                    return;
                  }
                  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(phoneC.text.trim())) {
                    showToast(ctx, l.validation_phone_format, error: true);
                    return;
                  }
                  try {
                    // Write to teams table
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': contactC.text.trim(),
                      'phone': phoneC.text.trim(),
                    });
                    // Also create conversation for communication
                    try {
                      await ref
                          .read(messagesRepoProvider)
                          .createConversation(
                            title: 'event:${event.id}:reg:${teamC.text.trim()}',
                            kind: 'team',
                          );
                    } catch (_) {}
                    await ref
                        .read(favoritesRepoProvider)
                        .toggle(FavoriteEntity.event, event.id);
                    ref.invalidate(eventTeamsCountProvider(event.id));
                    ref.invalidate(isUserRegisteredProvider(event.id));
                  } catch (e) {
                    if (ctx.mounted) showToast(ctx, '$e', error: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    showToast(context, l.event_register_success, success: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update _Header to show cancelled status and edit button**

In the `_Header` widget, update the status switch to handle `cancelled`:

```dart
final (dotColor, pillColor, pillText) = switch (event.status) {
  EventStatus.ongoing => (context.tokens.accent, context.tokens.accent, l.event_status_ongoing),
  EventStatus.registering => (context.tokens.warn, context.tokens.warn, l.event_status_registering),
  EventStatus.completed => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
  EventStatus.scheduling => (context.tokens.warn, context.tokens.warn, l.event_status_scheduling),
  EventStatus.cancelled => (context.tokens.danger, context.tokens.danger, l.event_status_cancelled),
  _ => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
};
```

- [ ] **Step 3: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(event-detail): add registration guards, capacity check, deadline check, cancel/complete/edit actions"
```

---

### Task 7: Auto-complete Prompt After Match End

**Files:**
- Modify: `lib/features/events/match_control_panel.dart`

- [ ] **Step 1: Add auto-complete check after endMatch**

In `lib/features/events/match_control_panel.dart`, add the import:

```dart
import '../../models/event.dart';
```

Replace the `_endMatch` method:

```dart
Future<void> _endMatch() async {
  final l = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.live_room_end),
      content: Text(l.live_room_end_confirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.common_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.common_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !mounted) return;

  setState(() => _busy = true);
  try {
    await ref
        .read(eventsRepoProvider)
        .endMatch(widget.matchId, _scoreA, _scoreB);

    // Check if all matches for this event are now done
    if (mounted) {
      final matches = await ref.read(eventsRepoProvider).matchesFor(widget.eventId);
      final allDone = matches.every((m) => m.done || m.id == widget.matchId);
      if (allDone && mounted) {
        final completeEvent = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.event_complete),
            content: Text(l.event_all_matches_done),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.common_cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l.common_confirm),
              ),
            ],
          ),
        );
        if (completeEvent == true) {
          await ref.read(eventsRepoProvider).updateEventStatus(
            widget.eventId,
            EventStatus.completed,
          );
          ref.invalidate(eventDetailProvider(widget.eventId));
        }
      }
    }

    if (mounted) widget.onMatchEnded();
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

- [ ] **Step 2: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/match_control_panel.dart
git commit -m "feat(match-control): prompt to complete event when all matches are finished"
```

---

### Task 8: Split Create Event Screen

**Files:**
- Create: `lib/features/create_event/bracket_mini_painter.dart`
- Create: `lib/features/create_event/event_form_fields.dart`
- Create: `lib/features/create_event/step_template.dart`
- Create: `lib/features/create_event/step_basic_info.dart`
- Create: `lib/features/create_event/step_registration.dart`
- Create: `lib/features/create_event/step_preview.dart`
- Modify: `lib/features/create_event/create_event_screen.dart`

- [ ] **Step 1: Extract _BracketMiniPainter**

Create `lib/features/create_event/bracket_mini_painter.dart`:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class BracketMiniPainter extends CustomPainter {
  final String variant;
  final bool active;
  final Color inkSub;
  final Color inkMute;
  final Color accent;
  BracketMiniPainter(this.variant, this.active, {required this.inkSub, required this.inkMute, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final c = active ? accent : inkSub;
    final cDim = active ? accent : inkMute;
    final scale = size.width / 48;
    canvas.save();
    canvas.scale(scale);

    final stroke = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final dim = Paint()..color = cDim;
    final dimStroke = Paint()
      ..color = cDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4;

    if (variant == 'group8') {
      for (final y in [6.0, 14.0]) {
        canvas.drawRect(Rect.fromLTWH(4, y, 16, 6), stroke);
        canvas.drawRect(Rect.fromLTWH(4, y + 24, 16, 6), stroke);
      }
      canvas.drawLine(const Offset(24, 24), const Offset(44, 24), dimStroke);
      canvas.drawRect(const Rect.fromLTWH(30, 20, 14, 8), stroke);
    } else if (variant == 'knockout16') {
      for (final y in [4.0, 10.0, 18.0, 24.0, 32.0, 38.0]) {
        canvas.drawRect(Rect.fromLTWH(2, y, 10, 3), dim);
      }
      for (final y in [8.0, 22.0, 36.0]) {
        canvas.drawRect(Rect.fromLTWH(14, y, 10, 3), dim);
      }
      for (final y in [16.0, 30.0]) {
        canvas.drawRect(Rect.fromLTWH(26, y, 10, 3), dim);
      }
      canvas.drawRect(const Rect.fromLTWH(38, 24, 10, 3), dim);
    } else if (variant == 'wc') {
      for (int col = 0; col < 4; col++) {
        for (final y in [4.0, 12.0, 20.0, 28.0]) {
          canvas.drawRect(Rect.fromLTWH(2 + col * 6, y, 4, 2), dim);
        }
      }
      canvas.drawLine(const Offset(28, 24), const Offset(46, 24), stroke);
      canvas.drawRect(const Rect.fromLTWH(34, 20, 10, 8), stroke);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(4, 6, 40, 36), const Radius.circular(2)),
        stroke,
      );
      for (final y in [12.0, 18.0, 24.0, 30.0, 36.0]) {
        canvas.drawLine(Offset(4, y), Offset(44, y), dimStroke);
      }
      for (final x in [14.0, 24.0, 34.0]) {
        canvas.drawLine(Offset(x, 6), Offset(x, 42), dimStroke);
      }
      canvas.drawRect(const Rect.fromLTWH(4, 6, 10, 6), dim);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BracketMiniPainter old) =>
      old.variant != variant || old.active != active;
}
```

- [ ] **Step 2: Extract _Field and _DateField into event_form_fields.dart**

Create `lib/features/create_event/event_form_fields.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/typography.dart';

class EventField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final bool mono;
  final TextInputType? keyboardType;
  final String? errorText;
  const EventField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix,
    this.mono = false,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(
                color: errorText != null ? context.tokens.danger : context.tokens.line,
              ),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: N(prefix!, size: 15, color: context.tokens.inkDim),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: context.tokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: mono ? context.tokens.fontMono : null,
                      fontFamilyFallback: mono ? context.tokens.monoFallbacks : null,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText!,
                style: TextStyle(fontSize: 11, color: context.tokens.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class EventDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  const EventDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(
                  color: errorText != null ? context.tokens.danger : context.tokens.line,
                ),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: context.tokens.inkSub),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value != null
                          ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')} '
                            '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}'
                          : '',
                      style: TextStyle(
                        color: value != null ? context.tokens.ink : context.tokens.inkDim,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText!,
                style: TextStyle(fontSize: 11, color: context.tokens.danger),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Extract step widgets**

Create `lib/features/create_event/step_template.dart`, `step_basic_info.dart`, `step_registration.dart`, `step_preview.dart`. Each receives its data via constructor params and calls parent callbacks for state changes.

Since each step widget is substantial, extract them from the current `_step1()` through `_step4()` methods. The parent screen passes controllers, DateTime? values, errors map, and callbacks.

Example for `step_template.dart`:
```dart
import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/typography.dart';
import 'bracket_mini_painter.dart';

class StepTemplate extends StatelessWidget {
  final String selectedTemplate;
  final ValueChanged<String> onTemplateChanged;
  const StepTemplate({super.key, required this.selectedTemplate, required this.onTemplateChanged});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tpls = [
      ('group8', l.create_event_tpl_group8, l.create_event_tpl_group8_desc),
      ('knockout16', l.create_event_tpl_knockout16, l.create_event_tpl_knockout16_desc),
      ('wc', l.create_event_tpl_wc, l.create_event_tpl_wc_desc),
      ('league', l.create_event_tpl_league, l.create_event_tpl_league_desc),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.create_event_tpl_title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.tokens.ink, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text(l.create_event_tpl_subtitle, style: TextStyle(fontSize: 13, color: context.tokens.inkSub)),
          const SizedBox(height: 18),
          for (final t in tpls) ...[
            GestureDetector(
              onTap: () => onTemplateChanged(t.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selectedTemplate == t.$1 ? context.tokens.elev3 : context.tokens.elev2,
                  border: Border.all(color: selectedTemplate == t.$1 ? context.tokens.accent : context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r3),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48, height: 48,
                      child: CustomPaint(
                        painter: BracketMiniPainter(t.$1, selectedTemplate == t.$1, inkSub: context.tokens.inkSub, inkMute: context.tokens.inkMute, accent: context.tokens.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.tokens.ink)),
                          const SizedBox(height: 3),
                          Text(t.$3, style: TextStyle(fontSize: 12, color: context.tokens.inkSub)),
                        ],
                      ),
                    ),
                    Container(
                      width: 20, height: 20, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedTemplate == t.$1 ? context.tokens.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: selectedTemplate == t.$1 ? context.tokens.accent : context.tokens.line, width: 1.5),
                      ),
                      child: selectedTemplate == t.$1 ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Update create_event_screen.dart to import and use extracted widgets**

Replace `_stepContent()` and remove the inline `_step1()` through `_step4()` methods, `_BracketMiniPainter`, and inline `_Field`/`_DateField`:

```dart
import 'step_template.dart';
import 'step_basic_info.dart';
import 'step_registration.dart';
import 'step_preview.dart';
import 'event_form_fields.dart';
```

```dart
Widget _stepContent() {
  return switch (_step) {
    1 => StepTemplate(
      selectedTemplate: _tpl,
      onTemplateChanged: (v) => setState(() => _tpl = v),
    ),
    2 => StepBasicInfo(
      nameController: _name,
      startDate: _startDate,
      endDate: _endDate,
      venueController: _venue,
      feeController: _fee,
      prizeController: _prize,
      errors: _errors,
      onPickStart: () async {
        final dt = await _pickDateTime(initial: _startDate);
        if (dt != null) setState(() { _startDate = dt; _errors.remove('start'); });
      },
      onPickEnd: () async {
        final dt = await _pickDateTime(initial: _endDate ?? _startDate);
        if (dt != null) setState(() { _endDate = dt; _errors.remove('end'); });
      },
    ),
    3 => StepRegistration(
      deadlineDate: _deadlineDate,
      review: _review,
      teamSizeController: _teamSize,
      maxTeamsController: _maxTeams,
      errors: _errors,
      onReviewChanged: (v) => setState(() => _review = v),
      onPickDeadline: () async {
        final dt = await _pickDateTime(initial: _deadlineDate ?? _startDate);
        if (dt != null) setState(() { _deadlineDate = dt; _errors.remove('deadline'); });
      },
    ),
    _ => StepPreview(
      nameController: _name,
      startDate: _startDate,
      endDate: _endDate,
      deadlineDate: _deadlineDate,
      venueController: _venue,
      prizeController: _prize,
      maxTeamsController: _maxTeams,
      template: _tpl,
      coverUrl: _coverUrl,
      uploadingCover: _uploadingCover,
      onPickCover: _pickCover,
    ),
  };
}
```

- [ ] **Step 5: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors. All widgets render as before, just from separate files.

- [ ] **Step 6: Commit**

```bash
git add lib/features/create_event/
git commit -m "refactor(create-event): split into step_template, step_basic_info, step_registration, step_preview, form_fields, painter"
```

---

### Task 9: Split Event Detail Screen

**Files:**
- Create: `lib/features/events/panels/overview_panel.dart`
- Create: `lib/features/events/panels/bracket_panel.dart`
- Create: `lib/features/events/panels/standings_panel.dart`
- Create: `lib/features/events/panels/scorers_panel.dart`
- Create: `lib/features/events/panels/chat_panel.dart`
- Create: `lib/features/events/widgets/event_header.dart`
- Create: `lib/features/events/widgets/kpi_strip.dart`
- Create: `lib/features/events/widgets/bottom_cta.dart`
- Create: `lib/features/events/widgets/register_sheet.dart`
- Modify: `lib/features/events/event_detail_screen.dart`

- [ ] **Step 1: Create panels/ and widgets/ directories**

```bash
mkdir -p lib/features/events/panels lib/features/events/widgets
```

- [ ] **Step 2: Extract each panel and widget**

Extract the following classes from `event_detail_screen.dart` into their own files. Each file gets the necessary imports (model, providers, theme, l10n, etc.):

| Class(es) | Target file |
|-----------|-------------|
| `_Header` | `widgets/event_header.dart` → rename to `EventHeader` |
| `_KpiStrip` | `widgets/kpi_strip.dart` → rename to `KpiStrip` |
| `_BottomCta`, `_RegField` | `widgets/bottom_cta.dart` → rename to `BottomCta`, `RegField` |
| `_OverviewPanel` | `panels/overview_panel.dart` → rename to `OverviewPanel` |
| `_BracketPanel`, `_BracketLayout`, `_EmptyCell`, `_MatchCard` | `panels/bracket_panel.dart` → rename to `BracketPanel`, etc. |
| `_StandingsPanel`, `_StandingsTable`, `_StandingsHero`, `_StandingsHeroSide`, `StandingRow`, `computeStandings`, `_showTeamSheet`, `_TeamSheet`, `_TeamMatchRow` | `panels/standings_panel.dart` |
| `_ScorersPanel` and sub-widgets | `panels/scorers_panel.dart` |
| `_ChatPanel`, `_ChatInput`, `_Msg` | `panels/chat_panel.dart` |
| `_Tabs`, `_PanelLoading`, `_PanelError` | keep in `event_detail_screen.dart` (small helpers) |

Each extracted widget:
- Changes from `_Private` to `Public` naming
- Gets its own imports
- Uses explicit constructor parameters (no globals)

- [ ] **Step 3: Update event_detail_screen.dart to import extracted widgets**

Replace the inline class definitions with imports:

```dart
import 'panels/overview_panel.dart';
import 'panels/bracket_panel.dart';
import 'panels/standings_panel.dart';
import 'panels/scorers_panel.dart';
import 'panels/chat_panel.dart';
import 'widgets/event_header.dart';
import 'widgets/kpi_strip.dart';
import 'widgets/bottom_cta.dart';
```

Update references: `_Header` → `EventHeader`, `_KpiStrip` → `KpiStrip`, `_BottomCta` → `BottomCta`, etc.

The main `event_detail_screen.dart` should be approximately 200-250 lines: scaffold, tab switching, `_Tabs`, `_PanelLoading`, `_PanelError`.

- [ ] **Step 4: Verify build**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -20`

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/events/
git commit -m "refactor(event-detail): split into panels/ and widgets/ sub-files"
```

---

### Task 10: Final Verification

**Files:** None (verification only)

- [ ] **Step 1: Full analysis**

Run: `flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tail -30`

Expected: No errors.

- [ ] **Step 2: Smoke build**

Run: `flutter build apk --debug 2>&1 | tail -20`

Expected: BUILD SUCCESSFUL.

- [ ] **Step 3: Verify all l10n keys resolve**

Run: `flutter gen-l10n 2>&1`

Expected: No errors about missing keys or placeholders.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git status
# Only commit if there are changes
git commit -m "fix: resolve final build issues from event flow validation"
```
