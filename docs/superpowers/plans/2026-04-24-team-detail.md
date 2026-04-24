# Team Detail Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full-screen team detail page with logo, slogan, captain, member roster, and match stats; enhance the registration form to capture slogan and team members.

**Architecture:** New migration adds `slogan` column to `teams` and creates `team_members` table. A new `TeamDetailScreen` consumes two new providers (`teamDetailProvider`, `teamMembersProvider`) and the existing `eventMatchesProvider` for stats. Registration form in `bottom_cta.dart` gains a slogan field and a member-add section with user search.

**Tech Stack:** Flutter, Riverpod, Supabase (PostgREST), go_router, ARB l10n

---

### Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/0014_team_members.sql`

- [ ] **Step 1: Create migration file**

```sql
-- 0014_team_members.sql

-- Add slogan to teams
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS slogan text;

-- Team members
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

CREATE POLICY "team_members public read"
  ON public.team_members FOR SELECT USING (true);

CREATE POLICY "team_members captain insert"
  ON public.team_members FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND captain_id = auth.uid())
  );

CREATE POLICY "team_members captain delete"
  ON public.team_members FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND captain_id = auth.uid())
  );
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0014_team_members.sql
git commit -m "feat(db): add slogan column and team_members table"
```

---

### Task 2: Seed Data

**Files:**
- Modify: `supabase/seed/demo.sql` (after line 382, the existing teams inserts)

- [ ] **Step 1: Add team_members seed data**

Insert after the existing teams block (line 382) and before the matches section (line 385):

```sql
-- Team members for 青秀狼队 and FC 黑马 (teams with captain_id set)
-- First, get team IDs via subquery
INSERT INTO team_members (team_id, user_id, jersey_number, role)
SELECT t.id, '10000000-0000-0000-0000-000000000001', 10, 'captain'
FROM teams t WHERE t.name = '青秀狼队' AND t.event_id = '11111111-1111-1111-1111-111111111111';

INSERT INTO team_members (team_id, user_id, jersey_number, role)
SELECT t.id, '10000000-0000-0000-0000-000000000002', 7, 'player'
FROM teams t WHERE t.name = '青秀狼队' AND t.event_id = '11111111-1111-1111-1111-111111111111';

INSERT INTO team_members (team_id, user_id, jersey_number, role)
SELECT t.id, '10000000-0000-0000-0000-000000000003', 9, 'captain'
FROM teams t WHERE t.name = 'FC 黑马' AND t.event_id = '11111111-1111-1111-1111-111111111111';

INSERT INTO team_members (team_id, user_id, jersey_number, role)
SELECT t.id, '10000000-0000-0000-0000-000000000004', 11, 'player'
FROM teams t WHERE t.name = 'FC 黑马' AND t.event_id = '11111111-1111-1111-1111-111111111111';
```

Also update the existing teams insert for 青秀狼队 and FC 黑马 to include slogans:

Change the insert at line 348 to:

```sql
insert into teams (event_id, name, captain_id, status, slogan) values
  ('11111111-1111-1111-1111-111111111111', '青秀狼队', '10000000-0000-0000-0000-000000000001', 'approved', '狼行千里，志在必得'),
  ('11111111-1111-1111-1111-111111111111', 'FC 黑马',  '10000000-0000-0000-0000-000000000003', 'approved', '逆风翻盘，向阳而生');
```

Keep the remaining 14 teams without slogan (they remain unchanged, lines 351-364).

- [ ] **Step 2: Commit**

```bash
git add supabase/seed/demo.sql
git commit -m "feat(seed): add team slogans and team_members demo data"
```

---

### Task 3: Model Changes

**Files:**
- Modify: `lib/models/event.dart:218-260` (TeamRow class)

- [ ] **Step 1: Add `logoUrl` and `slogan` fields to TeamRow**

Add two fields to the class:

```dart
class TeamRow {
  final String id;
  final String eventId;
  final String name;
  final String? captainId;
  final String? captainName;
  final String? captainAvatar;
  final String? contact;
  final String? phone;
  final String? logoUrl;
  final String? slogan;
  final String status;
  final DateTime? createdAt;

  const TeamRow({
    required this.id,
    required this.eventId,
    required this.name,
    this.captainId,
    this.captainName,
    this.captainAvatar,
    this.contact,
    this.phone,
    this.logoUrl,
    this.slogan,
    this.status = 'pending',
    this.createdAt,
  });

  factory TeamRow.fromMap(Map<String, dynamic> m) {
    final captain =
        (m['captain'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TeamRow(
      id: m['id'] as String,
      eventId: m['event_id'] as String,
      name: m['name'] as String,
      captainId: m['captain_id'] as String?,
      captainName: captain['name'] as String?,
      captainAvatar: captain['avatar_url'] as String?,
      contact: m['contact'] as String?,
      phone: m['phone'] as String?,
      logoUrl: m['logo_url'] as String?,
      slogan: m['slogan'] as String?,
      status: (m['status'] as String?) ?? 'pending',
      createdAt:
          m['created_at'] != null ? DateTime.parse(m['created_at']) : null,
    );
  }
}
```

- [ ] **Step 2: Add TeamMember class**

Append after the `TeamRow` class in `lib/models/event.dart`:

```dart
class TeamMember {
  final String id;
  final String userId;
  final String? name;
  final String? avatarUrl;
  final int? jerseyNumber;
  final String role;

  const TeamMember({
    required this.id,
    required this.userId,
    this.name,
    this.avatarUrl,
    this.jerseyNumber,
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
      jerseyNumber: m['jersey_number'] as int?,
      role: (m['role'] as String?) ?? 'player',
    );
  }
}
```

- [ ] **Step 3: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/models/event.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/models/event.dart
git commit -m "feat(model): add logoUrl/slogan to TeamRow, add TeamMember class"
```

---

### Task 4: Repository Methods

**Files:**
- Modify: `lib/repositories/events_repository.dart` (after line 270, end of `isUserRegistered`)

- [ ] **Step 1: Add four new methods**

Insert before the closing `}` of `EventsRepository` (before line 271):

```dart
  Future<TeamRow> fetchTeamDetail(String teamId) async {
    final m = await supabase
        .from('teams')
        .select('*, captain:profiles!captain_id(name, avatar_url)')
        .eq('id', teamId)
        .single();
    return TeamRow.fromMap(m);
  }

  Future<List<TeamMember>> listTeamMembers(String teamId) async {
    final rows = await supabase
        .from('team_members')
        .select('*, profile:profiles!user_id(name, avatar_url)')
        .eq('team_id', teamId)
        .order('role')
        .order('jersey_number');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(TeamMember.fromMap)
        .toList();
  }

  Future<void> addTeamMember(String teamId, String userId, int? jerseyNumber) async {
    await supabase.from('team_members').insert({
      'team_id': teamId,
      'user_id': userId,
      'jersey_number': jerseyNumber,
    });
  }

  Future<void> removeTeamMember(String memberId) async {
    await supabase.from('team_members').delete().eq('id', memberId);
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final rows = await supabase
        .from('profiles')
        .select('id, name, avatar_url')
        .ilike('name', '%$query%')
        .limit(10);
    return (rows as List).cast<Map<String, dynamic>>();
  }
```

Also add the `TeamMember` import at the top of the file (it should already be available from `event.dart` if that's imported — verify the existing import).

- [ ] **Step 2: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/repositories/events_repository.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/events_repository.dart
git commit -m "feat(repo): add team detail, members, and profile search methods"
```

---

### Task 5: Providers

**Files:**
- Modify: `lib/providers.dart` (after line 185, after `isUserRegisteredProvider`)

- [ ] **Step 1: Add three new providers**

Insert after `isUserRegisteredProvider` (line 185):

```dart
final teamDetailProvider =
    FutureProvider.family<TeamRow, String>((ref, teamId) async {
  return ref.read(eventsRepoProvider).fetchTeamDetail(teamId);
});

final teamMembersProvider =
    FutureProvider.family<List<TeamMember>, String>((ref, teamId) async {
  return ref.read(eventsRepoProvider).listTeamMembers(teamId);
});

final profileSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  return ref.read(eventsRepoProvider).searchProfiles(query);
});
```

Ensure `TeamMember` is importable from the existing `models/event.dart` import at the top of `providers.dart`.

- [ ] **Step 2: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/providers.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(providers): add teamDetail, teamMembers, profileSearch providers"
```

---

### Task 6: L10n Strings

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `event_register_phone` line 229)
- Modify: `lib/l10n/app_zh.arb` (after `event_register_phone` line 229)
- Modify: `lib/l10n/generated/app_localizations.dart`
- Modify: `lib/l10n/generated/app_localizations_en.dart`
- Modify: `lib/l10n/generated/app_localizations_zh.dart`

- [ ] **Step 1: Add keys to app_en.arb**

After `"event_register_phone": "Phone",` (line 229), insert:

```json
  "event_register_slogan": "Slogan (optional)",
  "event_register_members": "Members",
  "event_register_add_member": "Add member",
  "event_register_search_user": "Search user",
  "event_register_jersey": "Jersey #",
  "team_detail_slogan": "Slogan",
  "team_detail_members": "Members",
  "team_detail_member_count": "{n} members",
  "@team_detail_member_count": {
    "placeholders": { "n": { "type": "int" } }
  },
  "team_detail_stats": "Stats",
  "team_detail_no_matches": "No matches yet",
  "team_detail_captain": "Captain",
```

- [ ] **Step 2: Add keys to app_zh.arb**

After `"event_register_phone": "电话",` (line 229), insert:

```json
  "event_register_slogan": "口号（选填）",
  "event_register_members": "队员",
  "event_register_add_member": "添加队员",
  "event_register_search_user": "搜索用户",
  "event_register_jersey": "球衣号",
  "team_detail_slogan": "口号",
  "team_detail_members": "队员",
  "team_detail_member_count": "{n} 人",
  "@team_detail_member_count": {
    "placeholders": { "n": { "type": "int" } }
  },
  "team_detail_stats": "战绩",
  "team_detail_no_matches": "暂无比赛",
  "team_detail_captain": "队长",
```

- [ ] **Step 3: Add abstract getters to app_localizations.dart**

Add after the existing `event_tab_teams` getter block:

```dart
  String get event_register_slogan;
  String get event_register_members;
  String get event_register_add_member;
  String get event_register_search_user;
  String get event_register_jersey;
  String get team_detail_slogan;
  String get team_detail_members;
  String team_detail_member_count(int n);
  String get team_detail_stats;
  String get team_detail_no_matches;
  String get team_detail_captain;
```

- [ ] **Step 4: Add EN implementations to app_localizations_en.dart**

```dart
  @override
  String get event_register_slogan => 'Slogan (optional)';

  @override
  String get event_register_members => 'Members';

  @override
  String get event_register_add_member => 'Add member';

  @override
  String get event_register_search_user => 'Search user';

  @override
  String get event_register_jersey => 'Jersey #';

  @override
  String get team_detail_slogan => 'Slogan';

  @override
  String get team_detail_members => 'Members';

  @override
  String team_detail_member_count(int n) {
    return '$n members';
  }

  @override
  String get team_detail_stats => 'Stats';

  @override
  String get team_detail_no_matches => 'No matches yet';

  @override
  String get team_detail_captain => 'Captain';
```

- [ ] **Step 5: Add ZH implementations to app_localizations_zh.dart**

```dart
  @override
  String get event_register_slogan => '口号（选填）';

  @override
  String get event_register_members => '队员';

  @override
  String get event_register_add_member => '添加队员';

  @override
  String get event_register_search_user => '搜索用户';

  @override
  String get event_register_jersey => '球衣号';

  @override
  String get team_detail_slogan => '口号';

  @override
  String get team_detail_members => '队员';

  @override
  String team_detail_member_count(int n) {
    return '$n 人';
  }

  @override
  String get team_detail_stats => '战绩';

  @override
  String get team_detail_no_matches => '暂无比赛';

  @override
  String get team_detail_captain => '队长';
```

- [ ] **Step 6: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/l10n/`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add team detail and registration member strings"
```

---

### Task 7: Route Registration

**Files:**
- Modify: `lib/routes.dart` (add import + route after `/event/:id` route at line 122)

- [ ] **Step 1: Add import**

After line 10 (`import 'features/events/event_detail_screen.dart';`), add:

```dart
import 'features/events/team_detail_screen.dart';
```

- [ ] **Step 2: Add route**

After the `/event/:id` GoRoute block (line 122), insert:

```dart
    GoRoute(
      path: '/event/:eventId/team/:teamId',
      builder: (_, s) => TeamDetailScreen(
        eventId: s.pathParameters['eventId']!,
        teamId: s.pathParameters['teamId']!,
      ),
    ),
```

- [ ] **Step 3: Commit**

```bash
git add lib/routes.dart
git commit -m "feat(routes): add /event/:eventId/team/:teamId route"
```

---

### Task 8: Team Detail Screen

**Files:**
- Create: `lib/features/events/team_detail_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/typography.dart';
import 'panels/standings_panel.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String eventId;
  final String teamId;

  const TeamDetailScreen({
    super.key,
    required this.eventId,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamId));
    final membersAsync = ref.watch(teamMembersProvider(teamId));

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: teamAsync.when(
        data: (team) => _Body(
          team: team,
          eventId: eventId,
          membersAsync: membersAsync,
        ),
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.tokens.danger)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final TeamRow team;
  final String eventId;
  final AsyncValue<List<TeamMember>> membersAsync;

  const _Body({
    required this.team,
    required this.eventId,
    required this.membersAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final matchesAsync = ref.watch(eventMatchesProvider(eventId));

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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
            ),
          ),
          pinned: true,
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _HeroSection(team: team, memberCount: memberCount),
              if (standing != null) ...[
                const SizedBox(height: 16),
                _StatsCard(standing: standing, label: l.team_detail_stats),
              ],
              const SizedBox(height: 16),
              _MembersSection(membersAsync: membersAsync),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  final TeamRow team;
  final int memberCount;

  const _HeroSection({required this.team, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: context.tokens.elev3,
            borderRadius: BorderRadius.circular(20),
            image: team.logoUrl != null
                ? DecorationImage(
                    image: NetworkImage(team.logoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: team.logoUrl == null
              ? Center(
                  child: Text(
                    team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: context.tokens.inkSub,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          team.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        if (team.slogan != null && team.slogan!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '"${team.slogan!}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: context.tokens.inkSub,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (team.captainAvatar != null)
              CircleAvatar(
                radius: 10,
                backgroundImage: NetworkImage(team.captainAvatar!),
              )
            else
              CircleAvatar(
                radius: 10,
                backgroundColor: context.tokens.elev3,
                child: Icon(Icons.person, size: 12, color: context.tokens.inkDim),
              ),
            const SizedBox(width: 6),
            Text(
              team.captainName ?? '—',
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.tokens.accentSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.team_detail_captain,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.accent,
                ),
              ),
            ),
            Text(
              '·',
              style: TextStyle(color: context.tokens.inkDim, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Text(
              l.team_detail_member_count(memberCount),
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final StandingRow standing;
  final String label;

  const _StatsCard({required this.standing, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: StatCell(
                    value: '${standing.pts}',
                    label: context.l10n.event_standings_points,
                    accent: context.tokens.accent,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${standing.w}',
                    label: context.l10n.event_standings_wins,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${standing.d}',
                    label: context.l10n.event_standings_draws,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${standing.l}',
                    label: context.l10n.event_standings_losses,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final AsyncValue<List<TeamMember>> membersAsync;

  const _MembersSection({required this.membersAsync});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.team_detail_members),
          const SizedBox(height: 8),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.tokens.inkDim,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in members) _MemberRow(member: m),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  color: context.tokens.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => Text(
              '$e',
              style: TextStyle(fontSize: 12, color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMember member;
  const _MemberRow({required this.member});

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
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Icon(Icons.person, size: 16, color: context.tokens.inkDim)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.name ?? '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.tokens.ink,
              ),
            ),
          ),
          if (member.jerseyNumber != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${member.jerseyNumber}',
                style: TextStyle(
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.inkSub,
                ),
              ),
            ),
          if (member.role == 'captain')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.tokens.accentSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.team_detail_captain,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/features/events/team_detail_screen.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/team_detail_screen.dart
git commit -m "feat(ui): add TeamDetailScreen with hero, stats, and members"
```

---

### Task 9: Teams Panel — Add Navigation

**Files:**
- Modify: `lib/features/events/panels/teams_panel.dart`

- [ ] **Step 1: Add go_router import**

Add after line 1 (`import 'package:flutter/material.dart';`):

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 2: Pass `eventId` to `_TeamTile`**

In `_buildList` (line 82), change the `_TeamTile` construction to include `eventId`:

```dart
          for (final team in sorted) _TeamTile(
            team: team,
            eventId: eventId,
            isCreator: isCreator,
            isManual: reviewMode == 'manual',
            onApprove: () => _updateStatus(context, ref, team.id, 'approved'),
            onReject: () => _confirmReject(context, ref, team.id),
          ),
```

- [ ] **Step 3: Update `_TeamTile` to accept `eventId` and handle tap**

Add `eventId` field to `_TeamTile` (line 137-150):

```dart
class _TeamTile extends StatelessWidget {
  final TeamRow team;
  final String eventId;
  final bool isCreator;
  final bool isManual;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _TeamTile({
    required this.team,
    required this.eventId,
    required this.isCreator,
    required this.isManual,
    required this.onApprove,
    required this.onReject,
  });
```

- [ ] **Step 4: Wrap the `Container` in `_TeamTile.build` with a `GestureDetector`**

In the `build` method (line 153), wrap the existing `Opacity` widget with a `GestureDetector`:

Change:
```dart
    return Opacity(
```

To:
```dart
    return GestureDetector(
      onTap: () => context.push('/event/$eventId/team/${team.id}'),
      child: Opacity(
```

And add the matching closing parenthesis `)` after the `Opacity` widget's closing.

- [ ] **Step 5: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/features/events/panels/teams_panel.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/features/events/panels/teams_panel.dart
git commit -m "feat(teams-panel): tap team card navigates to team detail"
```

---

### Task 10: Registration Form — Slogan + Members

**Files:**
- Modify: `lib/features/events/widgets/bottom_cta.dart:176-299`

- [ ] **Step 1: Add slogan controller**

After line 191 (`final phoneC = TextEditingController();`), add:

```dart
    final sloganC = TextEditingController();
    final membersNotifier = ValueNotifier<List<({String userId, String name, String? avatarUrl, int? jersey})>>([]);
```

- [ ] **Step 2: Add slogan field to form**

After the `RegField` for phone (line 233), add:

```dart
              RegField(
                label: l.event_register_slogan,
                controller: sloganC,
              ),
```

- [ ] **Step 3: Add members section**

After the slogan `RegField`, add:

```dart
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: membersNotifier,
                builder: (ctx, members, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.event_register_members,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showUserSearchDialog(ctx, membersNotifier),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.tokens.accentSubtle,
                              borderRadius: BorderRadius.circular(context.tokens.r1),
                            ),
                            child: Text(
                              l.event_register_add_member,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.tokens.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (int i = 0; i < members.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: context.tokens.elev3,
                              backgroundImage: members[i].avatarUrl != null
                                  ? NetworkImage(members[i].avatarUrl!)
                                  : null,
                              child: members[i].avatarUrl == null
                                  ? Icon(Icons.person, size: 14, color: context.tokens.inkDim)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                members[i].name,
                                style: TextStyle(fontSize: 13, color: context.tokens.ink),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontSize: 12, color: context.tokens.ink),
                                decoration: InputDecoration(
                                  hintText: l.event_register_jersey,
                                  hintStyle: TextStyle(fontSize: 11, color: context.tokens.inkDim),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(color: context.tokens.line),
                                  ),
                                ),
                                onChanged: (v) {
                                  final list = List.of(membersNotifier.value);
                                  final old = list[i];
                                  list[i] = (userId: old.userId, name: old.name, avatarUrl: old.avatarUrl, jersey: int.tryParse(v));
                                  membersNotifier.value = list;
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                final list = List.of(membersNotifier.value);
                                list.removeAt(i);
                                membersNotifier.value = list;
                              },
                              child: Icon(Icons.close, size: 16, color: context.tokens.inkDim),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
```

- [ ] **Step 4: Update the insert payload to include slogan**

In the `onPressed` handler (line 259 area), change the insert call:

```dart
                    await ref.read(eventsRepoProvider).insertTeam({
                      'event_id': event.id,
                      'captain_id': currentUserId,
                      'name': teamC.text.trim(),
                      'contact': contactC.text.trim(),
                      'phone': phoneC.text.trim(),
                      'slogan': sloganC.text.trim().isEmpty ? null : sloganC.text.trim(),
                      'status': event.reviewMode == 'manual'
                          ? 'pending'
                          : 'approved',
                    });
```

- [ ] **Step 5: After team insert, batch-insert team members**

After the `insertTeam` call and before the conversation creation, add:

```dart
                    // Fetch the newly created team to get its ID
                    final newTeams = await ref.read(eventsRepoProvider).listTeams(event.id);
                    final newTeam = newTeams.where((t) => t.captainId == currentUserId).lastOrNull;
                    if (newTeam != null) {
                      // Insert captain as member
                      if (currentUserId != null) {
                        await ref.read(eventsRepoProvider).addTeamMember(
                          newTeam.id, currentUserId!, null,
                        );
                      }
                      // Insert selected members
                      for (final m in membersNotifier.value) {
                        await ref.read(eventsRepoProvider).addTeamMember(
                          newTeam.id, m.userId, m.jersey,
                        );
                      }
                    }
```

- [ ] **Step 6: Add the user search dialog method**

Add this as a top-level function at the end of `bottom_cta.dart` (after the `RegField` class):

```dart
Future<void> _showUserSearchDialog(
  BuildContext context,
  ValueNotifier<List<({String userId, String name, String? avatarUrl, int? jersey})>> membersNotifier,
) async {
  final searchC = TextEditingController();
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.tokens.elev1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ctx.l10n.event_register_search_user,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ctx.tokens.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchC,
              style: TextStyle(fontSize: 13, color: ctx.tokens.ink),
              decoration: InputDecoration(
                hintText: ctx.l10n.common_search,
                hintStyle: TextStyle(color: ctx.tokens.inkDim),
                prefixIcon: Icon(Icons.search, size: 18, color: ctx.tokens.inkDim),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: ctx.tokens.line),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: _UserSearchResults(
                searchController: searchC,
                onSelect: (userId, name, avatarUrl) {
                  final existing = membersNotifier.value.any((m) => m.userId == userId);
                  if (!existing) {
                    membersNotifier.value = [
                      ...membersNotifier.value,
                      (userId: userId, name: name, avatarUrl: avatarUrl, jersey: null),
                    ];
                  }
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 7: Add the `_UserSearchResults` widget**

Add after `_showUserSearchDialog`:

```dart
class _UserSearchResults extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final void Function(String userId, String name, String? avatarUrl) onSelect;

  const _UserSearchResults({
    required this.searchController,
    required this.onSelect,
  });

  @override
  ConsumerState<_UserSearchResults> createState() => _UserSearchResultsState();
}

class _UserSearchResultsState extends ConsumerState<_UserSearchResults> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final q = widget.searchController.text.trim();
    if (q != _query) setState(() => _query = q);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onQueryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_query.length < 2) {
      return Center(
        child: Text(
          '…',
          style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
        ),
      );
    }
    final async = ref.watch(profileSearchProvider(_query));
    return async.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return Center(
            child: Text(
              context.l10n.empty_no_search,
              style: TextStyle(color: context.tokens.inkDim, fontSize: 13),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: profiles.length,
          itemBuilder: (ctx, i) {
            final p = profiles[i];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: context.tokens.elev3,
                backgroundImage: p['avatar_url'] != null
                    ? NetworkImage(p['avatar_url'] as String)
                    : null,
                child: p['avatar_url'] == null
                    ? Icon(Icons.person, size: 16, color: context.tokens.inkDim)
                    : null,
              ),
              title: Text(
                p['name'] as String? ?? '—',
                style: TextStyle(fontSize: 13, color: context.tokens.ink),
              ),
              onTap: () => widget.onSelect(
                p['id'] as String,
                p['name'] as String? ?? '—',
                p['avatar_url'] as String?,
              ),
            );
          },
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.tokens.accent,
          strokeWidth: 2,
        ),
      ),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 12)),
      ),
    );
  }
}
```

- [ ] **Step 8: Run analysis**

Run: `$HOME/flutter/bin/dart analyze lib/features/events/widgets/bottom_cta.dart`
Expected: No issues found

- [ ] **Step 9: Commit**

```bash
git add lib/features/events/widgets/bottom_cta.dart
git commit -m "feat(registration): add slogan field and team member selection"
```

---

### Task 11: Final Verification

- [ ] **Step 1: Run full analysis**

Run: `$HOME/flutter/bin/dart analyze lib/`
Expected: No issues found (or only pre-existing warnings)

- [ ] **Step 2: Build**

Run: `$HOME/flutter/bin/flutter build web --release --quiet`
Expected: Build completes without errors

- [ ] **Step 3: Commit any remaining fixes**

If analysis or build uncovered issues, fix and commit them.
