# Event Registration Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign event registration to be lightweight at signup (team name + logo + contact), with a full team management page for post-registration details (roster, intro), plus individual registration mode support.

**Architecture:** Enhance existing `bottom_cta.dart` registration sheet with logo upload and editable contact fields. Extend `team_detail_screen.dart` into an editable management page for captains. Add `registration_mode` field to events and a new `individual_registrations` table. Add `position` column to `team_members`.

**Tech Stack:** Flutter + Riverpod + Supabase (Postgres + Storage) + go_router + flutter_image_compress + image_picker

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `supabase/migrations/0001_schema.sql` | Add `registration_mode` to events, `position` to team_members, create `individual_registrations` table |
| Modify | `lib/models/event.dart` | Add `registrationMode` field to `Event`, add `position` to `TeamMember` |
| Modify | `lib/repositories/events_repository.dart` | Add individual registration CRUD methods, update `addTeamMember` signature |
| Modify | `lib/providers.dart` | Add `individualRegistrationsProvider`, update `addTeamMember` calls |
| Modify | `lib/features/events/widgets/bottom_cta.dart` | Redesign registration sheet (logo + contact fields), add individual registration sheet |
| Modify | `lib/features/events/team_detail_screen.dart` | Add captain edit mode: add/edit/remove members, edit slogan, upload logo |
| Modify | `lib/features/create_event/step_registration.dart` | Add registration mode selector |
| Modify | `lib/features/create_event/create_event_screen.dart` | Wire `_registrationMode` state + include in payload |
| Modify | `lib/features/events/panels/teams_panel.dart` | Add individual registrations section for organizer |
| Modify | `lib/l10n/app_zh.arb` | Add Chinese strings |
| Modify | `lib/l10n/app_en.arb` | Add English strings |

---

### Task 1: Database Migration

**Files:**
- Modify: `supabase/migrations/0001_schema.sql`

- [ ] **Step 1: Add `registration_mode` column to events table**

In `supabase/migrations/0001_schema.sql`, after line 187 (the `created_at` column of events), add the `registration_mode` column. Replace the events table definition:

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
  review_mode text default 'auto' check (review_mode in ('auto', 'manual')),
  registration_mode text default 'team_only' check (registration_mode in ('team_only', 'team_and_individual')),
  created_at timestamptz default now()
);
```

- [ ] **Step 2: Add `position` column to team_members table**

Update the team_members table definition to include position:

```sql
create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  jersey_number int,
  position text check (position in ('forward', 'midfielder', 'defender', 'goalkeeper')),
  role text not null default 'player' check (role in ('captain', 'player')),
  joined_at timestamptz not null default now(),
  unique (team_id, user_id)
);
```

- [ ] **Step 3: Add `individual_registrations` table**

After the team_members table and its policies, add:

```sql
create table public.individual_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  phone text,
  position text check (position in ('forward', 'midfielder', 'defender', 'goalkeeper')),
  status text default 'pending' check (status in ('pending', 'assigned', 'rejected')),
  assigned_team_id uuid references public.teams(id),
  created_at timestamptz default now(),
  unique (event_id, user_id)
);

alter table public.individual_registrations enable row level security;

create policy "individual_registrations public read" on public.individual_registrations
  for select using (true);

create policy "individual_registrations user insert" on public.individual_registrations
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "individual_registrations user delete" on public.individual_registrations
  for delete to authenticated
  using (user_id = auth.uid());

create policy "individual_registrations organizer update" on public.individual_registrations
  for update to authenticated
  using (
    exists (select 1 from public.events where id = event_id and creator_id = auth.uid())
  );
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0001_schema.sql
git commit -m "feat(db): add registration_mode, position, individual_registrations table"
```

---

### Task 2: Update Data Models

**Files:**
- Modify: `lib/models/event.dart`

- [ ] **Step 1: Add `registrationMode` field to Event class**

In `lib/models/event.dart`, add to the `Event` class constructor and `fromMap`:

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
  final String? registrationMode;

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
    this.registrationMode,
  });

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
    teamSize: _toInt(m['team_size']) ?? 11,
    teamsMax: _toInt(m['teams_max']),
    prizeCents: _toInt(m['prize_cents']),
    feeCents: _toInt(m['fee_cents']),
    deadline: m['deadline'] != null ? DateTime.parse(m['deadline']) : null,
    startsAt: m['starts_at'] != null ? DateTime.parse(m['starts_at']) : null,
    endsAt: m['ends_at'] != null ? DateTime.parse(m['ends_at']) : null,
    status: _parseEventStatus(m['status'] as String?),
    coverUrl: m['cover_url'] as String?,
    reviewMode: m['review_mode'] as String?,
    registrationMode: m['registration_mode'] as String?,
  );
}
```

- [ ] **Step 2: Add `position` field to TeamMember class**

```dart
class TeamMember {
  final String id;
  final String userId;
  final String? name;
  final String? avatarUrl;
  final int? jerseyNumber;
  final String? position;
  final String role;

  const TeamMember({
    required this.id,
    required this.userId,
    this.name,
    this.avatarUrl,
    this.jerseyNumber,
    this.position,
    this.role = 'player',
  });

  factory TeamMember.fromMap(Map<String, dynamic> m) {
    final profile =
        (m['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TeamMember(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      name: profile['name'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      jerseyNumber: _toInt(m['jersey_number']),
      position: m['position'] as String?,
      role: (m['role'] as String?) ?? 'player',
    );
  }
}
```

- [ ] **Step 3: Add `IndividualRegistration` model class**

At the end of `lib/models/event.dart`, add:

```dart
class IndividualRegistration {
  final String id;
  final String eventId;
  final String userId;
  final String name;
  final String? phone;
  final String? position;
  final String status;
  final String? assignedTeamId;
  final DateTime? createdAt;

  const IndividualRegistration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.name,
    this.phone,
    this.position,
    this.status = 'pending',
    this.assignedTeamId,
    this.createdAt,
  });

  factory IndividualRegistration.fromMap(Map<String, dynamic> m) {
    return IndividualRegistration(
      id: m['id'] as String,
      eventId: m['event_id'] as String,
      userId: m['user_id'] as String,
      name: m['name'] as String,
      phone: m['phone'] as String?,
      position: m['position'] as String?,
      status: (m['status'] as String?) ?? 'pending',
      assignedTeamId: m['assigned_team_id'] as String?,
      createdAt: m['created_at'] != null ? DateTime.parse(m['created_at']) : null,
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/models/event.dart
git commit -m "feat(models): add registrationMode to Event, position to TeamMember, IndividualRegistration model"
```

---

### Task 3: Update Repository

**Files:**
- Modify: `lib/repositories/events_repository.dart`

- [ ] **Step 1: Update `addTeamMember` to accept position**

Change the existing method signature:

```dart
Future<void> addTeamMember(String teamId, String userId, int? jerseyNumber, {String? position}) async {
  await supabase.from('team_members').insert({
    'team_id': teamId,
    'user_id': userId,
    'jersey_number': jerseyNumber,
    if (position != null) 'position': position,
  });
}
```

- [ ] **Step 2: Add `updateTeamMember` method**

After `removeTeamMember`:

```dart
Future<void> updateTeamMember(String memberId, {int? jerseyNumber, String? position}) async {
  final payload = <String, dynamic>{};
  if (jerseyNumber != null) payload['jersey_number'] = jerseyNumber;
  if (position != null) payload['position'] = position;
  if (payload.isNotEmpty) {
    await supabase.from('team_members').update(payload).eq('id', memberId);
  }
}
```

- [ ] **Step 3: Add `updateTeam` method for editing team details**

After `insertTeam`:

```dart
Future<void> updateTeam(String teamId, Map<String, dynamic> payload) async {
  await supabase.from('teams').update(payload).eq('id', teamId);
}
```

- [ ] **Step 4: Add individual registration CRUD methods**

At the end of the class (before the closing `}`):

```dart
Future<List<IndividualRegistration>> listIndividualRegistrations(String eventId) async {
  final rows = await supabase
      .from('individual_registrations')
      .select()
      .eq('event_id', eventId)
      .order('created_at');
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(IndividualRegistration.fromMap)
      .toList();
}

Future<void> insertIndividualRegistration(Map<String, dynamic> payload) async {
  await supabase.from('individual_registrations').insert(payload);
}

Future<void> cancelIndividualRegistration(String eventId, String userId) async {
  await supabase
      .from('individual_registrations')
      .delete()
      .eq('event_id', eventId)
      .eq('user_id', userId);
}

Future<bool> isUserIndividuallyRegistered(String eventId, String userId) async {
  final row = await supabase
      .from('individual_registrations')
      .select('id')
      .eq('event_id', eventId)
      .eq('user_id', userId)
      .maybeSingle();
  return row != null;
}

Future<void> assignIndividualToTeam(String registrationId, String teamId, String userId) async {
  await supabase
      .from('individual_registrations')
      .update({'status': 'assigned', 'assigned_team_id': teamId})
      .eq('id', registrationId);
  await supabase.from('team_members').insert({
    'team_id': teamId,
    'user_id': userId,
  });
}

Future<void> rejectIndividualRegistration(String registrationId) async {
  await supabase
      .from('individual_registrations')
      .update({'status': 'rejected'})
      .eq('id', registrationId);
}
```

- [ ] **Step 5: Add the import for IndividualRegistration**

At the top of the file, the import `'../models/event.dart'` already exists and will cover the new `IndividualRegistration` class.

- [ ] **Step 6: Commit**

```bash
git add lib/repositories/events_repository.dart
git commit -m "feat(repo): add individual registration CRUD, updateTeam, updateTeamMember"
```

---

### Task 4: Update Providers

**Files:**
- Modify: `lib/providers.dart`

- [ ] **Step 1: Add individual registrations provider**

After the `teamMembersProvider` (around line 195), add:

```dart
final individualRegistrationsProvider =
    FutureProvider.family<List<IndividualRegistration>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).listIndividualRegistrations(eventId);
});

final isUserIndividuallyRegisteredProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final uid = currentUserId;
  if (uid == null) return false;
  return ref.read(eventsRepoProvider).isUserIndividuallyRegistered(eventId, uid);
});
```

- [ ] **Step 2: Add the IndividualRegistration import**

The existing `import 'models/event.dart'` will cover it since `IndividualRegistration` is in the same file.

- [ ] **Step 3: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(providers): add individualRegistrations and isUserIndividuallyRegistered providers"
```

---

### Task 5: Localization Strings

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add Chinese strings to `app_zh.arb`**

Add after the existing `event_register_cancel_success` entry (around line 1147):

```json
  "event_register_logo": "队徽",
  "event_register_logo_hint": "点击上传（可跳过）",
  "event_register_contact_label": "联系人信息",
  "event_register_contact_prefill_hint": "来自你的资料，可修改",
  "event_register_post_hint": "报名后可在队伍详情中补充球员名单等信息",
  "event_register_individual_title": "个人报名",
  "event_register_individual_hint": "提交后由组委会分配队伍",
  "event_register_position": "擅长位置",
  "position_forward": "前锋",
  "position_midfielder": "中场",
  "position_defender": "后卫",
  "position_goalkeeper": "门将",
  "create_event_registration_mode": "报名模式",
  "create_event_reg_mode_team_only": "仅队伍报名",
  "create_event_reg_mode_team_and_individual": "队伍+个人",
  "team_detail_edit_slogan": "编辑简介",
  "team_detail_slogan_hint": "介绍你的队伍...",
  "team_detail_add_member": "添加球员",
  "team_detail_roster_progress": "{current}/{total}",
  "@team_detail_roster_progress": {
    "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } }
  },
  "team_detail_roster_warning": "球员名单未满（{current}/{total}）",
  "@team_detail_roster_warning": {
    "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } }
  },
  "team_detail_edit_member": "编辑球员",
  "team_detail_remove_member": "移除球员",
  "team_detail_remove_member_confirm": "确定要移除该球员吗？",
  "individual_registrations_title": "散客报名",
  "individual_registrations_empty": "暂无散客报名",
  "individual_assign_to_team": "分配到队伍",
  "individual_reject": "拒绝",
  "individual_status_assigned": "已分配",
  "individual_status_rejected": "已拒绝"
```

- [ ] **Step 2: Add English strings to `app_en.arb`**

Add the equivalent English translations in the same position:

```json
  "event_register_logo": "Team logo",
  "event_register_logo_hint": "Tap to upload (optional)",
  "event_register_contact_label": "Contact info",
  "event_register_contact_prefill_hint": "From your profile, editable",
  "event_register_post_hint": "You can add roster and details in team page after registering",
  "event_register_individual_title": "Register individually",
  "event_register_individual_hint": "Organizer will assign you to a team",
  "event_register_position": "Preferred position",
  "position_forward": "Forward",
  "position_midfielder": "Midfielder",
  "position_defender": "Defender",
  "position_goalkeeper": "Goalkeeper",
  "create_event_registration_mode": "Registration mode",
  "create_event_reg_mode_team_only": "Team only",
  "create_event_reg_mode_team_and_individual": "Team + Individual",
  "team_detail_edit_slogan": "Edit intro",
  "team_detail_slogan_hint": "Introduce your team...",
  "team_detail_add_member": "Add player",
  "team_detail_roster_progress": "{current}/{total}",
  "@team_detail_roster_progress": {
    "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } }
  },
  "team_detail_roster_warning": "Roster incomplete ({current}/{total})",
  "@team_detail_roster_warning": {
    "placeholders": { "current": { "type": "int" }, "total": { "type": "int" } }
  },
  "team_detail_edit_member": "Edit player",
  "team_detail_remove_member": "Remove player",
  "team_detail_remove_member_confirm": "Remove this player?",
  "individual_registrations_title": "Individual registrations",
  "individual_registrations_empty": "No individual registrations",
  "individual_assign_to_team": "Assign to team",
  "individual_reject": "Reject",
  "individual_status_assigned": "Assigned",
  "individual_status_rejected": "Rejected"
```

- [ ] **Step 3: Regenerate localizations**

Run:
```bash
cd /home/coder/workspaces/qiuju_app && flutter gen-l10n
```

Expected: files in `lib/l10n/generated/` are regenerated without errors.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add registration redesign strings (zh + en)"
```

---

### Task 6: Organizer Configuration — Registration Mode Selector

**Files:**
- Modify: `lib/features/create_event/step_registration.dart`
- Modify: `lib/features/create_event/create_event_screen.dart`

- [ ] **Step 1: Add `registrationMode` parameter to StepRegistration**

In `lib/features/create_event/step_registration.dart`, add the new fields:

```dart
class StepRegistration extends StatelessWidget {
  final DateTime? deadlineDate;
  final String review;
  final String registrationMode;
  final TextEditingController teamSizeController;
  final TextEditingController maxTeamsController;
  final Map<String, String?> errors;
  final ValueChanged<String> onReviewChanged;
  final ValueChanged<String> onRegistrationModeChanged;
  final VoidCallback onPickDeadline;

  const StepRegistration({
    super.key,
    required this.deadlineDate,
    required this.review,
    required this.registrationMode,
    required this.teamSizeController,
    required this.maxTeamsController,
    required this.errors,
    required this.onReviewChanged,
    required this.onRegistrationModeChanged,
    required this.onPickDeadline,
  });
```

- [ ] **Step 2: Add registration mode UI to StepRegistration build method**

After the deadline field and before the review title, add the registration mode selector. Insert after line 47 (`const SizedBox(height: 18)`), before the `EventDateField`:

```dart
// Registration mode selector — add BEFORE the deadline field
Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Label(l.create_event_registration_mode),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final opt in [
            ('team_only', l.create_event_reg_mode_team_only),
            ('team_and_individual', l.create_event_reg_mode_team_and_individual),
          ]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onRegistrationModeChanged(opt.$1),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: registrationMode == opt.$1 ? context.tokens.elev3 : context.tokens.elev2,
                    border: Border.all(
                      color: registrationMode == opt.$1 ? context.tokens.accent : context.tokens.line,
                    ),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Text(
                    opt.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: registrationMode == opt.$1 ? context.tokens.accent : context.tokens.ink,
                    ),
                  ),
                ),
              ),
            ),
            if (opt.$1 == 'team_only') const SizedBox(width: 8),
          ],
        ],
      ),
    ],
  ),
),
```

- [ ] **Step 3: Add state variable in create_event_screen.dart**

In `_CreateEventScreenState`, add after `String _review = 'auto';`:

```dart
String _registrationMode = 'team_only';
```

- [ ] **Step 4: Pass to StepRegistration widget**

Find where `StepRegistration(` is instantiated in `create_event_screen.dart` and add the new parameters:

```dart
StepRegistration(
  deadlineDate: _deadlineDate,
  review: _review,
  registrationMode: _registrationMode,
  teamSizeController: _teamSize,
  maxTeamsController: _maxTeams,
  errors: _errors,
  onReviewChanged: (v) => setState(() => _review = v),
  onRegistrationModeChanged: (v) => setState(() => _registrationMode = v),
  onPickDeadline: _pickDeadline,
),
```

- [ ] **Step 5: Include `registration_mode` in the submit payload**

In the payload map (around line 434), add:

```dart
'registration_mode': _registrationMode,
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/create_event/step_registration.dart lib/features/create_event/create_event_screen.dart
git commit -m "feat(create-event): add registration mode selector to step 3"
```

---

### Task 7: Redesign Team Registration Sheet

**Files:**
- Modify: `lib/features/events/widgets/bottom_cta.dart`

- [ ] **Step 1: Redesign `showRegisterSheet` with logo + contact fields**

Replace the existing `showRegisterSheet` method with:

```dart
Future<void> showRegisterSheet(BuildContext context, WidgetRef ref) async {
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
  final profile = ref.read(myProfileProvider).valueOrNull;
  final teamC = TextEditingController();
  final contactC = TextEditingController(text: profile?.name ?? '');
  final phoneC = TextEditingController(text: profile?.phone ?? '');
  String? logoUrl;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
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
                  fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 16),
              RegField(label: l.event_register_team_name, controller: teamC),
              // Logo upload
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(l.event_register_logo),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final url = await StorageService().pickCropCompressAndUpload(
                          bucket: 'avatars',
                          pathPrefix: 'teams',
                        );
                        if (url != null) setSheetState(() => logoUrl = url);
                      },
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: context.tokens.elev2,
                          border: Border.all(color: context.tokens.line),
                          borderRadius: BorderRadius.circular(12),
                          image: logoUrl != null
                              ? DecorationImage(image: NetworkImage(logoUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: logoUrl == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 20, color: context.tokens.inkDim),
                                  const SizedBox(height: 2),
                                  Text(
                                    l.event_register_logo_hint,
                                    style: TextStyle(fontSize: 9, color: context.tokens.inkDim),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              // Contact fields
              Label(l.event_register_contact_label),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: RegField(label: l.event_register_contact, controller: contactC)),
                  const SizedBox(width: 10),
                  Expanded(child: RegField(label: l.event_register_phone, controller: phoneC, keyboardType: TextInputType.phone)),
                ],
              ),
              const SizedBox(height: 4),
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
                  try {
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': contactC.text.trim(),
                      'phone': phoneC.text.trim(),
                      if (logoUrl != null) 'logo_url': logoUrl,
                      'status': event.reviewMode == 'manual' ? 'pending' : 'approved',
                    });
                    final newTeams = await ref.read(eventsRepoProvider).listTeams(event.id);
                    final newTeam = newTeams.where((t) => t.captainId == currentUserId).lastOrNull;
                    if (newTeam != null && currentUserId != null) {
                      await ref.read(eventsRepoProvider).addTeamMember(
                        newTeam.id, currentUserId!, null,
                      );
                    }
                    try {
                      await ref.read(messagesRepoProvider).createConversation(
                        title: 'event:${event.id}:reg:${teamC.text.trim()}',
                        kind: 'team',
                      );
                    } catch (_) {}
                    await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.event, event.id);
                    ref.invalidate(eventTeamsCountProvider(event.id));
                    ref.invalidate(isUserRegisteredProvider(event.id));
                    ref.invalidate(eventTeamsProvider(event.id));
                  } catch (e) {
                    if (ctx.mounted) showToast(ctx, '$e', error: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    showToast(context, l.event_register_success, success: true);
                    // Navigate to team detail
                    final teams = await ref.read(eventsRepoProvider).listTeams(event.id);
                    final myTeam = teams.where((t) => t.captainId == currentUserId).lastOrNull;
                    if (myTeam != null && context.mounted) {
                      context.push('/event/${event.id}/team/${myTeam.id}');
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  l.event_register_post_hint,
                  style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: Add StorageService import**

At the top of `bottom_cta.dart`, add:

```dart
import '../../../services/storage.dart';
```

- [ ] **Step 3: Add individual registration sheet method**

After `showRegisterSheet`, add:

```dart
Future<void> showIndividualRegisterSheet(BuildContext context, WidgetRef ref) async {
  final uid = currentUserId;
  if (uid != null) {
    final alreadyRegistered = await ref.read(eventsRepoProvider).isUserIndividuallyRegistered(event.id, uid);
    if (alreadyRegistered && context.mounted) {
      showToast(context, context.l10n.event_already_registered, error: true);
      return;
    }
  }

  if (!context.mounted) return;
  final l = context.l10n;
  final profile = ref.read(myProfileProvider).valueOrNull;
  final nameC = TextEditingController(text: profile?.name ?? '');
  final phoneC = TextEditingController(text: profile?.phone ?? '');
  String? selectedPosition;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: context.tokens.inkMute,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.event_register_individual_title,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: RegField(label: l.event_register_contact, controller: nameC)),
                  const SizedBox(width: 10),
                  Expanded(child: RegField(label: l.event_register_phone, controller: phoneC, keyboardType: TextInputType.phone)),
                ],
              ),
              Label(l.event_register_position),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final pos in [
                    ('forward', l.position_forward),
                    ('midfielder', l.position_midfielder),
                    ('defender', l.position_defender),
                    ('goalkeeper', l.position_goalkeeper),
                  ])
                    GestureDetector(
                      onTap: () => setSheetState(() => selectedPosition = pos.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedPosition == pos.$1 ? context.tokens.elev3 : context.tokens.elev2,
                          border: Border.all(
                            color: selectedPosition == pos.$1 ? context.tokens.accent : context.tokens.line,
                          ),
                          borderRadius: BorderRadius.circular(context.tokens.r2),
                        ),
                        child: Text(
                          pos.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selectedPosition == pos.$1 ? context.tokens.accent : context.tokens.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: l.event_register_submit,
                variant: BtnVariant.primary,
                size: BtnSize.lg,
                full: true,
                onPressed: () async {
                  if (nameC.text.trim().isEmpty || selectedPosition == null) {
                    showToast(ctx, l.error_required_field, error: true);
                    return;
                  }
                  try {
                    await ref.read(eventsRepoProvider).insertIndividualRegistration({
                      'event_id': event.id,
                      'user_id': currentUserId,
                      'name': nameC.text.trim(),
                      'phone': phoneC.text.trim(),
                      'position': selectedPosition,
                    });
                    await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.event, event.id);
                    ref.invalidate(isUserIndividuallyRegisteredProvider(event.id));
                    ref.invalidate(individualRegistrationsProvider(event.id));
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
              const SizedBox(height: 10),
              Center(
                child: Text(
                  l.event_register_individual_hint,
                  style: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Update the registration button to show both options when `team_and_individual`**

In `_buildRightButton`, when `isRegistering` is true and `disabledReason` is null, check `event.registrationMode`. If `'team_and_individual'`, show a choice dialog before opening the appropriate sheet. Replace the existing block at line 175-186:

```dart
if (isRegistering) {
  return PrimaryButton(
    label: disabledReason ?? l.event_cta_register,
    variant: disabledReason != null ? BtnVariant.secondary : BtnVariant.primary,
    size: BtnSize.lg,
    full: true,
    onPressed: disabledReason != null
        ? null
        : () {
            if (event.registrationMode == 'team_and_individual') {
              _showRegistrationModeChoice(context, ref);
            } else {
              showRegisterSheet(context, ref);
            }
          },
  );
}
```

Add helper method:

```dart
void _showRegistrationModeChoice(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  showModalBottomSheet(
    context: context,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: context.tokens.inkMute,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: l.event_register_form_title,
            variant: BtnVariant.primary,
            size: BtnSize.lg,
            full: true,
            onPressed: () {
              Navigator.pop(ctx);
              showRegisterSheet(context, ref);
            },
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: l.event_register_individual_title,
            variant: BtnVariant.secondary,
            size: BtnSize.lg,
            full: true,
            onPressed: () {
              Navigator.pop(ctx);
              showIndividualRegisterSheet(context, ref);
            },
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 5: Update `isRegistering` check to also consider individual registrations**

In the `build` method, update the `registered` check to also account for individual registration. After line 24:

```dart
final registered = LocalStore.isEventFavorited(event.id);
```

This already handles both cases since we call `toggle(FavoriteEntity.event, event.id)` in both flows.

- [ ] **Step 6: Commit**

```bash
git add lib/features/events/widgets/bottom_cta.dart
git commit -m "feat(registration): redesign team sheet with logo/contact, add individual registration"
```

---

### Task 8: Enhance Team Detail Screen — Captain Edit Mode

**Files:**
- Modify: `lib/features/events/team_detail_screen.dart`

- [ ] **Step 1: Add captain detection and edit capabilities**

The screen already displays team info and members. We need to add:
- Detect if current user is captain (`team.captainId == currentUserId`)
- Add "+" button to add members when captain
- Add edit/remove actions on each member row
- Add editable slogan section
- Show roster progress warning

Update `_Body` build method to pass `isCaptain`:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final matchesAsync = ref.watch(eventMatchesProvider(eventId));
  final isCaptain = team.captainId == currentUserId;

  // Get event for team_size
  final eventAsync = ref.watch(eventDetailProvider(eventId));
  final teamSize = eventAsync.valueOrNull?.teamSize ?? 11;

  StandingRow? standing;
  if (matchesAsync case AsyncData(value: final matches)) {
    final standings = computeStandings(matches);
    for (final s in standings) {
      if (s.team == team.name) {
        standing = s;
        break;
      }
    }
  }

  final memberCount = membersAsync.valueOrNull?.length ?? 0;

  return CustomScrollView(
    slivers: [
      SliverAppBar(
        backgroundColor: context.tokens.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.tokens.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          team.name,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink),
        ),
        pinned: true,
      ),
      SliverToBoxAdapter(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _HeroSection(team: team, memberCount: memberCount),
            if (isCaptain && memberCount < teamSize) ...[
              const SizedBox(height: 12),
              _RosterWarning(current: memberCount, total: teamSize),
            ],
            if (standing != null) ...[
              const SizedBox(height: 16),
              _StatsCard(standing: standing, label: l.team_detail_stats),
            ],
            const SizedBox(height: 16),
            _MembersSection(
              membersAsync: membersAsync,
              isCaptain: isCaptain,
              teamId: team.id,
              eventId: eventId,
              teamSize: teamSize,
            ),
            const SizedBox(height: 16),
            _SloganSection(team: team, isCaptain: isCaptain),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 2: Add `_RosterWarning` widget**

```dart
class _RosterWarning extends StatelessWidget {
  final int current;
  final int total;
  const _RosterWarning({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tokens.warnSubtle,
          border: Border.all(color: context.tokens.warn.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: context.tokens.warn),
            const SizedBox(width: 8),
            Text(
              l.team_detail_roster_warning(current, total),
              style: TextStyle(fontSize: 12, color: context.tokens.warn),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update `_MembersSection` to support captain actions**

Add `isCaptain`, `teamId`, `eventId`, `teamSize` parameters and "Add player" button:

```dart
class _MembersSection extends ConsumerWidget {
  final AsyncValue<List<TeamMember>> membersAsync;
  final bool isCaptain;
  final String teamId;
  final String eventId;
  final int teamSize;

  const _MembersSection({
    required this.membersAsync,
    required this.isCaptain,
    required this.teamId,
    required this.eventId,
    required this.teamSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Label(l.team_detail_members)),
              if (isCaptain)
                GestureDetector(
                  onTap: () => _showAddMemberSheet(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.tokens.accent,
                      borderRadius: BorderRadius.circular(context.tokens.r1),
                    ),
                    child: Text(
                      l.team_detail_add_member,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.accentInk),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('—', style: TextStyle(fontSize: 13, color: context.tokens.inkDim)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in members)
                    _MemberRow(
                      member: m,
                      isCaptain: isCaptain,
                      onRemove: () => _removeMember(context, ref, m),
                    ),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2)),
            ),
            error: (e, _) => Text('$e', style: TextStyle(fontSize: 12, color: context.tokens.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMemberSheet(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final searchC = TextEditingController();
    final jerseyC = TextEditingController();
    String? selectedPosition;
    String? selectedUserId;
    String? selectedUserName;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.tokens.inkMute, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                Text(l.team_detail_add_member, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink)),
                const SizedBox(height: 16),
                // Search user
                RegField(label: l.event_register_search_user, controller: searchC),
                if (searchC.text.trim().length >= 2)
                  Consumer(
                    builder: (_, ref2, __) {
                      final results = ref2.watch(profileSearchProvider(searchC.text.trim()));
                      return results.when(
                        data: (profiles) => Column(
                          children: [
                            for (final p in profiles.take(5))
                              GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    selectedUserId = p['id'] as String;
                                    selectedUserName = p['name'] as String?;
                                    searchC.text = selectedUserName ?? '';
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url'] as String) : null,
                                        child: p['avatar_url'] == null ? Icon(Icons.person, size: 14, color: context.tokens.inkDim) : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(p['name'] as String? ?? '—', style: TextStyle(fontSize: 13, color: context.tokens.ink)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: RegField(label: l.event_register_jersey, controller: jerseyC, keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Label(l.event_register_position),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final pos in [
                                ('forward', l.position_forward),
                                ('midfielder', l.position_midfielder),
                                ('defender', l.position_defender),
                                ('goalkeeper', l.position_goalkeeper),
                              ])
                                GestureDetector(
                                  onTap: () => setSheetState(() => selectedPosition = pos.$1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: selectedPosition == pos.$1 ? context.tokens.accentSubtle : context.tokens.elev2,
                                      border: Border.all(color: selectedPosition == pos.$1 ? context.tokens.accent : context.tokens.line),
                                      borderRadius: BorderRadius.circular(context.tokens.r1),
                                    ),
                                    child: Text(pos.$2, style: TextStyle(fontSize: 11, color: selectedPosition == pos.$1 ? context.tokens.accent : context.tokens.ink)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: l.team_detail_add_member,
                  variant: BtnVariant.primary,
                  size: BtnSize.lg,
                  full: true,
                  onPressed: () async {
                    if (selectedUserId == null) {
                      showToast(ctx, l.error_required_field, error: true);
                      return;
                    }
                    try {
                      await ref.read(eventsRepoProvider).addTeamMember(
                        teamId,
                        selectedUserId!,
                        int.tryParse(jerseyC.text),
                        position: selectedPosition,
                      );
                      ref.invalidate(teamMembersProvider(teamId));
                    } catch (e) {
                      if (ctx.mounted) showToast(ctx, '$e', error: true);
                      return;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, TeamMember member) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.team_detail_remove_member),
        content: Text(l.team_detail_remove_member_confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(eventsRepoProvider).removeTeamMember(member.id);
    ref.invalidate(teamMembersProvider(teamId));
  }
}
```

- [ ] **Step 4: Update `_MemberRow` to show position and captain remove button**

```dart
class _MemberRow extends StatelessWidget {
  final TeamMember member;
  final bool isCaptain;
  final VoidCallback? onRemove;
  const _MemberRow({required this.member, this.isCaptain = false, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: context.tokens.elev3,
            backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
            child: member.avatarUrl == null ? Icon(Icons.person, size: 16, color: context.tokens.inkDim) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name ?? '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.tokens.ink)),
                if (member.position != null)
                  Text(
                    _positionLabel(context, member.position!),
                    style: TextStyle(fontSize: 11, color: context.tokens.inkSub),
                  ),
              ],
            ),
          ),
          if (member.jerseyNumber != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: context.tokens.elev3, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '#${member.jerseyNumber}',
                style: TextStyle(fontFamily: context.tokens.fontMono, fontFamilyFallback: context.tokens.monoFallbacks, fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.inkSub),
              ),
            ),
          if (member.role == 'captain')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: context.tokens.accentSubtle, borderRadius: BorderRadius.circular(4)),
              child: Text(l.team_detail_captain, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: context.tokens.accent)),
            ),
          if (isCaptain && member.role != 'captain' && onRemove != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 16, color: context.tokens.inkDim),
            ),
          ],
        ],
      ),
    );
  }

  String _positionLabel(BuildContext context, String position) {
    final l = context.l10n;
    return switch (position) {
      'forward' => l.position_forward,
      'midfielder' => l.position_midfielder,
      'defender' => l.position_defender,
      'goalkeeper' => l.position_goalkeeper,
      _ => position,
    };
  }
}
```

- [ ] **Step 5: Add `_SloganSection` widget**

```dart
class _SloganSection extends ConsumerWidget {
  final TeamRow team;
  final bool isCaptain;
  const _SloganSection({required this.team, required this.isCaptain});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Label(l.team_detail_edit_slogan)),
              if (isCaptain)
                GestureDetector(
                  onTap: () => _editSlogan(context, ref),
                  child: Icon(Icons.edit_outlined, size: 16, color: context.tokens.inkDim),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Text(
              (team.slogan != null && team.slogan!.isNotEmpty)
                  ? team.slogan!
                  : l.team_detail_slogan_hint,
              style: TextStyle(
                fontSize: 13,
                color: (team.slogan != null && team.slogan!.isNotEmpty)
                    ? context.tokens.ink
                    : context.tokens.inkDim,
                fontStyle: (team.slogan == null || team.slogan!.isEmpty) ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSlogan(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final controller = TextEditingController(text: team.slogan ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.team_detail_edit_slogan),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: l.team_detail_slogan_hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await ref.read(eventsRepoProvider).updateTeam(team.id, {'slogan': result.trim()});
    ref.invalidate(teamDetailProvider(team.id));
  }
}
```

- [ ] **Step 6: Add required imports at the top of team_detail_screen.dart**

```dart
import '../../services/supabase.dart';
import '../../widgets/primary_button.dart';
import '../../utils/toast.dart';
import 'widgets/bottom_cta.dart'; // for RegField
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/events/team_detail_screen.dart
git commit -m "feat(team-detail): add captain edit mode — roster management, slogan editing"
```

---

### Task 9: Individual Registrations Section in Teams Panel

**Files:**
- Modify: `lib/features/events/panels/teams_panel.dart`

- [ ] **Step 1: Add `registrationMode` parameter to TeamsPanel**

```dart
class TeamsPanel extends ConsumerWidget {
  final String eventId;
  final bool isCreator;
  final String? reviewMode;
  final String? registrationMode;
  final int? teamsMax;

  const TeamsPanel({
    super.key,
    required this.eventId,
    required this.isCreator,
    this.reviewMode,
    this.registrationMode,
    this.teamsMax,
  });
```

- [ ] **Step 2: Add individual registrations section in `_buildList`**

After the team list rendering in `_buildList`, add:

```dart
if (isCreator && registrationMode == 'team_and_individual') ...[
  const SizedBox(height: 20),
  _IndividualRegistrationsSection(eventId: eventId),
],
```

- [ ] **Step 3: Create `_IndividualRegistrationsSection` widget**

```dart
class _IndividualRegistrationsSection extends ConsumerWidget {
  final String eventId;
  const _IndividualRegistrationsSection({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(individualRegistrationsProvider(eventId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(l.individual_registrations_title),
        const SizedBox(height: 8),
        async.when(
          data: (regs) {
            final pending = regs.where((r) => r.status == 'pending').toList();
            if (pending.isEmpty) {
              return Text(l.individual_registrations_empty, style: TextStyle(fontSize: 12, color: context.tokens.inkDim));
            }
            return Column(
              children: [
                for (final reg in pending) _IndividualTile(reg: reg, eventId: eventId),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _IndividualTile extends ConsumerWidget {
  final IndividualRegistration reg;
  final String eventId;
  const _IndividualTile({required this.reg, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reg.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tokens.ink)),
                if (reg.position != null)
                  Text(
                    _posLabel(context, reg.position!),
                    style: TextStyle(fontSize: 11, color: context.tokens.inkSub),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _assignToTeam(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.tokens.accent,
                borderRadius: BorderRadius.circular(context.tokens.r1),
              ),
              child: Text(l.individual_assign_to_team, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.accentInk)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              await ref.read(eventsRepoProvider).rejectIndividualRegistration(reg.id);
              ref.invalidate(individualRegistrationsProvider(eventId));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: context.tokens.danger),
                borderRadius: BorderRadius.circular(context.tokens.r1),
              ),
              child: Text(l.individual_reject, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.danger)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignToTeam(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final teams = await ref.read(eventsRepoProvider).listTeams(eventId);
    final approvedTeams = teams.where((t) => t.status == 'approved').toList();
    if (!context.mounted) return;

    final selectedTeam = await showModalBottomSheet<TeamRow>(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.individual_assign_to_team, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink)),
            const SizedBox(height: 12),
            for (final team in approvedTeams)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, team),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Text(team.name, style: TextStyle(fontSize: 14, color: context.tokens.ink)),
                ),
              ),
          ],
        ),
      ),
    );
    if (selectedTeam == null) return;

    await ref.read(eventsRepoProvider).assignIndividualToTeam(reg.id, selectedTeam.id, reg.userId);
    ref.invalidate(individualRegistrationsProvider(eventId));
    ref.invalidate(teamMembersProvider(selectedTeam.id));
  }

  String _posLabel(BuildContext context, String pos) {
    final l = context.l10n;
    return switch (pos) {
      'forward' => l.position_forward,
      'midfielder' => l.position_midfielder,
      'defender' => l.position_defender,
      'goalkeeper' => l.position_goalkeeper,
      _ => pos,
    };
  }
}
```

- [ ] **Step 4: Update the TeamsPanel call site in event_detail_screen.dart**

Find where `TeamsPanel(` is used and add `registrationMode: event.registrationMode`:

```dart
TeamsPanel(
  eventId: event.id,
  isCreator: isCreator,
  reviewMode: event.reviewMode,
  registrationMode: event.registrationMode,
  teamsMax: event.teamsMax,
),
```

- [ ] **Step 5: Add necessary imports to teams_panel.dart**

```dart
import '../../../models/event.dart';  // already imported via TeamRow
```

Make sure `IndividualRegistration` is accessible (it's in the same `event.dart` file).

- [ ] **Step 6: Commit**

```bash
git add lib/features/events/panels/teams_panel.dart lib/features/events/event_detail_screen.dart
git commit -m "feat(teams-panel): add individual registrations section for organizer"
```

---

### Task 10: Wire Everything Together & Verify

**Files:**
- Various

- [ ] **Step 1: Verify all `addTeamMember` call sites compile**

The existing call in `bottom_cta.dart` line 267 passes positional args: `addTeamMember(newTeam.id, currentUserId!, null)`. The updated signature adds `position` as a named optional parameter, so existing calls still work.

Run:
```bash
cd /home/coder/workspaces/qiuju_app && flutter analyze
```

Expected: No errors.

- [ ] **Step 2: Fix any compilation issues**

Address any issues from `flutter analyze`. Common things to check:
- Import of `IndividualRegistration` in providers.dart (should work since it's in `models/event.dart`)
- Import of `StorageService` in `bottom_cta.dart`
- The `_MembersSection` change from `StatelessWidget` to `ConsumerWidget` (needed for `ref`)

- [ ] **Step 3: Reset local Supabase and verify schema loads**

```bash
cd /home/coder/workspaces/qiuju_app && npx supabase db reset
```

Expected: Schema loads without errors, all new tables/columns are created.

- [ ] **Step 4: Run the app and smoke test**

```bash
cd /home/coder/workspaces/qiuju_app && flutter run -d chrome
```

Test:
1. Create an event → Step 3 shows new "Registration mode" selector
2. Register a team → form shows logo upload + editable contact fields
3. After registration → redirects to team detail page
4. Team detail → captain can add members with position
5. If mode is `team_and_individual`, registration button shows choice dialog

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(registration): wire registration redesign end-to-end"
```
