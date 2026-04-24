# Team Detail Page Design

## Summary

Add a full-screen team detail page accessible from the teams panel, showing team logo, slogan, captain, member roster, and match stats. Requires a new `team_members` table, schema changes to `teams`, registration form enhancements, and a new screen + route.

## Motivation

The current teams panel only shows a flat list of team cards with name/captain/status. There's no way to see the full team identity (logo, slogan) or who's on the roster. For a sports app, team identity is core.

---

## 1. Database Changes

### 1a. ALTER `teams` table

```sql
ALTER TABLE public.teams ADD COLUMN slogan text;
```

The `logo_url` column already exists but is unused in the Dart model — will be wired up.

### 1b. New `team_members` table

```sql
CREATE TABLE public.team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  jersey_number int,
  role text NOT NULL DEFAULT 'player' CHECK (role IN ('captain', 'player')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, user_id)
);

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "team_members public read" ON public.team_members FOR SELECT USING (true);
CREATE POLICY "team_members captain insert" ON public.team_members FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND captain_id = auth.uid())
  );
CREATE POLICY "team_members captain delete" ON public.team_members FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND captain_id = auth.uid())
  );
```

---

## 2. Model Changes

### 2a. Update `TeamRow`

Add two fields:

```dart
final String? logoUrl;
final String? slogan;
```

Update `fromMap`:
- `logoUrl: m['logo_url'] as String?`
- `slogan: m['slogan'] as String?`

### 2b. New `TeamMember` class

```dart
class TeamMember {
  final String id;
  final String userId;
  final String? name;
  final String? avatarUrl;
  final int? jerseyNumber;
  final String role; // 'captain' | 'player'

  const TeamMember({ ... });

  factory TeamMember.fromMap(Map<String, dynamic> m) {
    final profile = (m['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    return TeamMember(
      id: m['id'],
      userId: m['user_id'],
      name: profile['name'],
      avatarUrl: profile['avatar_url'],
      jerseyNumber: m['jersey_number'],
      role: m['role'] ?? 'player',
    );
  }
}
```

---

## 3. Repository Changes

Add to `EventsRepository`:

### `fetchTeamDetail(teamId)`

```dart
Future<TeamRow> fetchTeamDetail(String teamId) async {
  final m = await supabase
      .from('teams')
      .select('*, captain:profiles!captain_id(name, avatar_url)')
      .eq('id', teamId)
      .single();
  return TeamRow.fromMap(m);
}
```

### `listTeamMembers(teamId)`

```dart
Future<List<TeamMember>> listTeamMembers(String teamId) async {
  final rows = await supabase
      .from('team_members')
      .select('*, profile:profiles!user_id(name, avatar_url)')
      .eq('team_id', teamId)
      .order('role', ascending: true)  // captain first
      .order('jersey_number', ascending: true);
  return rows.map((m) => TeamMember.fromMap(m)).toList();
}
```

### `addTeamMember(teamId, userId, jerseyNumber)`

```dart
Future<void> addTeamMember(String teamId, String userId, int? jerseyNumber) async {
  await supabase.from('team_members').insert({
    'team_id': teamId,
    'user_id': userId,
    'jersey_number': jerseyNumber,
  });
}
```

### `removeTeamMember(memberId)`

```dart
Future<void> removeTeamMember(String memberId) async {
  await supabase.from('team_members').delete().eq('id', memberId);
}
```

---

## 4. Providers

```dart
final teamDetailProvider = FutureProvider.family<TeamRow, String>((ref, teamId) {
  return ref.read(eventsRepoProvider).fetchTeamDetail(teamId);
});

final teamMembersProvider = FutureProvider.family<List<TeamMember>, String>((ref, teamId) {
  return ref.read(eventsRepoProvider).listTeamMembers(teamId);
});
```

---

## 5. Route

Add to `routes.dart`:

```
/event/:eventId/team/:teamId → TeamDetailScreen
```

---

## 6. Team Detail Screen Layout

New file: `lib/features/events/team_detail_screen.dart`

### Structure (top to bottom):

1. **AppBar** — back button, team name in title
2. **Hero section** — large team logo (96×96 rounded square), team name (18pt bold), slogan (13pt muted italic), captain row (avatar + name + "队长" badge), member count
3. **Stats strip** — W / D / L / Pts in a horizontal card, computed from `eventMatchesProvider`. Only shown if team has played matches. Reuses `computeStandings()` from `standings_panel.dart` to find this team's row.
4. **Members list** — each row: avatar (32px circle), name, jersey number badge (`#7`), role badge for captain. Sorted: captain first, then by jersey number.

### Data fetching

- `teamDetailProvider(teamId)` for team info
- `teamMembersProvider(teamId)` for roster
- `eventMatchesProvider(eventId)` for stats (already cached if user visited competition tab)

---

## 7. Entry Points

### 7a. TeamsPanel — tap team card

Add `onTap` to `_TeamTile`:
```dart
onTap: () => context.push('/event/$eventId/team/${team.id}')
```

### 7b. StandingsPanel — keep existing bottom sheet

The standings bottom sheet shows match-focused stats (recent results, scores). It serves a different purpose than the team detail page. Keep it as-is — no changes needed.

---

## 8. Registration Form Enhancement

Modify `showRegisterSheet` in `bottom_cta.dart`:

### 8a. Add slogan field

After team name field, add:
```
RegField(label: l.event_register_slogan, controller: sloganC)
```

Include `slogan` in the insert payload.

### 8b. Add members step

After the basic info fields, add a "队员" section:
- "添加队员" button → opens user search dialog
- Selected users appear in a list with jersey number input
- On submit: after inserting team row, batch-insert team_members
- Also auto-insert captain as a team_member with role 'captain'

The user search dialog:
- Text input for name search
- Calls `supabase.from('profiles').select().ilike('name', '%query%').limit(10)`
- Shows results as tappable rows (avatar + name)
- Tapping adds to the members list

---

## 9. L10n Keys

New keys needed:

| Key | EN | ZH |
|-----|----|----|
| `team_detail_slogan` | Slogan | 口号 |
| `team_detail_members` | Members | 队员 |
| `team_detail_member_count` | {n} members | {n} 人 |
| `team_detail_stats` | Stats | 战绩 |
| `team_detail_no_matches` | No matches yet | 暂无比赛 |
| `event_register_slogan` | Slogan (optional) | 口号（选填） |
| `event_register_members` | Members | 队员 |
| `event_register_add_member` | Add member | 添加队员 |
| `event_register_search_user` | Search user | 搜索用户 |
| `event_register_jersey` | Jersey # | 球衣号 |

---

## 10. Files Changed

| Layer | File | Change |
|-------|------|--------|
| DB | New migration `0014_team_members.sql` | ALTER teams + CREATE team_members |
| Seed | `demo.sql` | Add demo team_members rows |
| Model | `lib/models/event.dart` | TeamRow +2 fields, new TeamMember class |
| Repo | `lib/repositories/events_repository.dart` | 4 new methods |
| Provider | `lib/providers.dart` | 2 new providers |
| Route | `lib/routes.dart` | New route |
| UI | New `lib/features/events/team_detail_screen.dart` | Full-screen detail page |
| UI | `lib/features/events/panels/teams_panel.dart` | Add onTap navigation |
| UI | `lib/features/events/widgets/bottom_cta.dart` | Slogan field + members step |
| L10n | `lib/l10n/app_en.arb`, `app_zh.arb` + generated | 10 new keys |
