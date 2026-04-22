# Event Lifecycle + LiveKit Live Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement end-to-end event lifecycle (draft→registering→scheduling→ongoing→completed) with multi-party LiveKit video rooms per match (upcoming→live→finished).

**Architecture:** Match-centric model — each match gets one LiveKit Room for many-to-many video. Supabase Edge Functions generate LiveKit tokens server-side. Supabase Realtime syncs scores/status; LiveKit handles audio/video streams.

**Tech Stack:** Flutter + livekit_client, Supabase (PostgreSQL + Edge Functions + Realtime), Deno (Edge Functions runtime), LiveKit Cloud

---

## File Structure

### New files
- `supabase/migrations/0010_match_livekit.sql` — DB migration for match/event status extensions + RLS
- `supabase/functions/livekit-token/index.ts` — Edge Function: generate LiveKit access tokens
- `supabase/functions/room-info/index.ts` — Edge Function: query room participant count
- `lib/models/livekit_token.dart` — LiveKitToken data class
- `lib/repositories/livekit_repository.dart` — calls Edge Functions for tokens / room info
- `lib/features/events/match_live_room.dart` — multi-party video room screen
- `lib/features/events/match_control_panel.dart` — host-only scoring bottom drawer
- `lib/features/events/schedule_matches_screen.dart` — bracket generation wizard

### Modified files
- `lib/models/event.dart` — extend EventStatus enum + MatchStatus enum + new fields
- `lib/repositories/events_repository.dart` — add match lifecycle methods
- `lib/providers.dart` — add LiveKit + realtime providers
- `lib/routes.dart` — add 2 new routes
- `lib/features/events/match_detail_screen.dart` — use MatchStatus, add "Enter Live Room" CTA
- `lib/features/events/event_detail_screen.dart` — LIVE indicator, organizer actions
- `lib/features/events/events_hub_screen.dart` — LIVE badge on ongoing events
- `lib/l10n/app_zh.arb` — new i18n strings
- `lib/l10n/app_en.arb` — new i18n strings
- `lib/config/env.dart` — add LiveKit env vars
- `pubspec.yaml` — add livekit_client dependency

---

## Task 1: Database Migration

**Files:**
- Create: `supabase/migrations/0010_match_livekit.sql`

- [ ] **Step 1: Write the migration file**

```sql
-- 0010_match_livekit.sql — Extend matches/events for LiveKit live streaming

-- 1. matches: add status + livekit fields
ALTER TABLE matches ADD COLUMN IF NOT EXISTS status text DEFAULT 'upcoming'
  CHECK (status IN ('upcoming','live','finished'));
ALTER TABLE matches ADD COLUMN IF NOT EXISTS livekit_room text;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS started_at timestamptz;
ALTER TABLE matches ADD COLUMN IF NOT EXISTS ended_at timestamptz;

-- 2. Migrate existing data from done bool → status
UPDATE matches SET status = 'finished' WHERE done = true AND status = 'upcoming';
UPDATE matches SET status = 'upcoming' WHERE done = false AND status IS NULL;

-- 3. events: expand status CHECK to include new lifecycle states
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
  CHECK (status IN ('draft','registering','scheduling','ongoing','completed','done'));

-- 4. Indexes for live-match queries
CREATE INDEX IF NOT EXISTS idx_matches_status ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_event_status ON matches(event_id, status);

-- 5. Enable Realtime on matches table
ALTER PUBLICATION supabase_realtime ADD TABLE matches;

-- 6. RLS: everyone can read matches
CREATE POLICY "matches_select_all" ON matches FOR SELECT USING (true);

-- 7. RLS: only event creator can update match rows
CREATE POLICY "matches_update_by_event_creator" ON matches FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = matches.event_id
    AND events.creator_id = auth.uid()
  )
);

-- 8. RLS: only event creator can insert matches (schedule generation)
CREATE POLICY "matches_insert_by_event_creator" ON matches FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = matches.event_id
    AND events.creator_id = auth.uid()
  )
);

-- 9. RLS: only event creator can insert goals
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'goals_insert_by_event_creator'
  ) THEN
    CREATE POLICY "goals_insert_by_event_creator" ON goals FOR INSERT WITH CHECK (
      EXISTS (
        SELECT 1 FROM matches
        JOIN events ON events.id = matches.event_id
        WHERE matches.id = goals.match_id
        AND events.creator_id = auth.uid()
      )
    );
  END IF;
END $$;
```

- [ ] **Step 2: Apply the migration locally**

Run:
```bash
supabase db reset
```

Expected: Migration applies without errors. Existing `done=true` matches should now have `status='finished'`.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0010_match_livekit.sql
git commit -m "feat(db): add match status, livekit_room, and lifecycle fields"
```

---

## Task 2: Extend Models (Event + Match + LiveKitToken)

**Files:**
- Modify: `lib/models/event.dart`
- Create: `lib/models/livekit_token.dart`

- [ ] **Step 1: Update EventStatus enum and parser**

In `lib/models/event.dart`, replace the current enum and parser (lines 2–8):

Old:
```dart
enum EventStatus { registering, ongoing, done }

EventStatus _parseEventStatus(String? s) => switch (s) {
  'ongoing' => EventStatus.ongoing,
  'done' => EventStatus.done,
  _ => EventStatus.registering,
};
```

New:
```dart
enum EventStatus { draft, registering, scheduling, ongoing, completed }

EventStatus _parseEventStatus(String? s) => switch (s) {
  'draft' => EventStatus.draft,
  'scheduling' => EventStatus.scheduling,
  'ongoing' => EventStatus.ongoing,
  'completed' || 'done' => EventStatus.completed,
  _ => EventStatus.registering,
};
```

- [ ] **Step 2: Add MatchStatus enum and update Match class**

In `lib/models/event.dart`, add `MatchStatus` enum after the `Event` class (after line 62), and replace the `Match` class (lines 64–107):

Add after line 62:
```dart
enum MatchStatus { upcoming, live, finished }

MatchStatus _parseMatchStatus(String? s, bool done) => switch (s) {
  'live' => MatchStatus.live,
  'finished' => MatchStatus.finished,
  _ => done ? MatchStatus.finished : MatchStatus.upcoming,
};
```

Replace the `Match` class with:
```dart
class Match {
  final String id;
  final String eventId;
  final String? round;
  final String? teamAId;
  final String? teamBId;
  final String? teamALabel;
  final String? teamBLabel;
  final int? scoreA;
  final int? scoreB;
  final String? pkScore;
  final DateTime? playedAt;
  final bool done;
  final MatchStatus status;
  final String? livekitRoom;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? minute;
  final int viewers;

  const Match({
    required this.id,
    required this.eventId,
    this.round,
    this.teamAId,
    this.teamBId,
    this.teamALabel,
    this.teamBLabel,
    this.scoreA,
    this.scoreB,
    this.pkScore,
    this.playedAt,
    this.done = false,
    this.status = MatchStatus.upcoming,
    this.livekitRoom,
    this.startedAt,
    this.endedAt,
    this.minute,
    this.viewers = 0,
  });

  factory Match.fromMap(Map<String, dynamic> m) {
    final done = (m['done'] as bool?) ?? false;
    return Match(
      id: m['id'] as String,
      eventId: m['event_id'] as String,
      round: m['round'] as String?,
      teamAId: m['team_a_id'] as String?,
      teamBId: m['team_b_id'] as String?,
      teamALabel: m['team_a_label'] as String?,
      teamBLabel: m['team_b_label'] as String?,
      scoreA: m['score_a'] as int?,
      scoreB: m['score_b'] as int?,
      pkScore: m['pk_score'] as String?,
      playedAt: m['played_at'] != null ? DateTime.parse(m['played_at']) : null,
      done: done,
      status: _parseMatchStatus(m['status'] as String?, done),
      livekitRoom: m['livekit_room'] as String?,
      startedAt: m['started_at'] != null ? DateTime.parse(m['started_at']) : null,
      endedAt: m['ended_at'] != null ? DateTime.parse(m['ended_at']) : null,
      minute: m['minute'] as int?,
      viewers: (m['viewers'] as int?) ?? 0,
    );
  }
}
```

- [ ] **Step 3: Create LiveKitToken model**

Create `lib/models/livekit_token.dart`:

```dart
class LiveKitToken {
  final String token;
  final String roomName;
  final String wsUrl;

  const LiveKitToken({
    required this.token,
    required this.roomName,
    required this.wsUrl,
  });

  factory LiveKitToken.fromMap(Map<String, dynamic> m) => LiveKitToken(
    token: m['token'] as String,
    roomName: m['roomName'] as String,
    wsUrl: m['wsUrl'] as String,
  );
}
```

- [ ] **Step 4: Verify the app compiles**

Run:
```bash
flutter analyze lib/models/event.dart lib/models/livekit_token.dart
```

Expected: No errors. There will be warnings in downstream files that still reference `EventStatus.done` — these are expected and will be fixed in later tasks.

- [ ] **Step 5: Commit**

```bash
git add lib/models/event.dart lib/models/livekit_token.dart
git commit -m "feat(models): extend Event/Match status enums and add LiveKitToken"
```

---

## Task 3: Add LiveKit Env Vars + Dependency

**Files:**
- Modify: `lib/config/env.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add LiveKit env vars to Env class**

In `lib/config/env.dart`, add after the `isFirebaseConfigured` getter (after line 39):

```dart
  // LiveKit (live streaming).
  static const livekitWsUrl = String.fromEnvironment('LIVEKIT_WS_URL');

  static bool get isLiveKitConfigured => livekitWsUrl.isNotEmpty;
```

- [ ] **Step 2: Add livekit_client to pubspec.yaml**

In `pubspec.yaml`, add after the `video_player` line (after line 56):

```yaml

  # LiveKit multi-party video (live streaming rooms)
  livekit_client: ^2.3.0
```

- [ ] **Step 3: Install dependencies**

Run:
```bash
flutter pub get
```

Expected: Resolves successfully with `livekit_client` added.

- [ ] **Step 4: Commit**

```bash
git add lib/config/env.dart pubspec.yaml pubspec.lock
git commit -m "feat: add livekit_client dependency and LiveKit env config"
```

---

## Task 4: Supabase Edge Functions (livekit-token + room-info)

**Files:**
- Create: `supabase/functions/livekit-token/index.ts`
- Create: `supabase/functions/room-info/index.ts`

- [ ] **Step 1: Create livekit-token Edge Function**

Create `supabase/functions/livekit-token/index.ts`:

```typescript
// livekit-token — Generate a LiveKit access token for a match room.
//
// POST /functions/v1/livekit-token
// Authorization: Bearer <supabase-jwt>
// Body: { "matchId": "uuid" }
// Response: { "token": "...", "roomName": "match_<id>", "wsUrl": "wss://..." }
//
// Deploy:
//   supabase functions deploy livekit-token
//   supabase secrets set LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=... LIVEKIT_WS_URL=...

// @ts-expect-error: Deno URL import
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// @ts-expect-error: Deno URL import
import { AccessToken } from "https://esm.sh/livekit-server-sdk@2.6.1";

// deno-lint-ignore no-explicit-any
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY")!;
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET")!;
const LIVEKIT_WS_URL = Deno.env.get("LIVEKIT_WS_URL")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405, headers: corsHeaders });
  }

  // 1. Verify caller identity from Supabase JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing auth" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
  const jwt = authHeader.replace("Bearer ", "");
  const { data: { user }, error: authError } = await supabase.auth.getUser(jwt);
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "invalid token" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  // 2. Parse body
  let matchId: string;
  try {
    const body = await req.json();
    matchId = body.matchId;
    if (!matchId) throw new Error("missing matchId");
  } catch {
    return new Response(JSON.stringify({ error: "invalid body, need { matchId }" }), {
      status: 400,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  // 3. Look up match + event to determine role
  const { data: match, error: matchErr } = await supabase
    .from("matches")
    .select("id, event_id")
    .eq("id", matchId)
    .single();
  if (matchErr || !match) {
    return new Response(JSON.stringify({ error: "match not found" }), {
      status: 404,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  const { data: event, error: eventErr } = await supabase
    .from("events")
    .select("creator_id")
    .eq("id", match.event_id)
    .single();
  if (eventErr || !event) {
    return new Response(JSON.stringify({ error: "event not found" }), {
      status: 404,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  const isHost = event.creator_id === user.id;
  const roomName = `match_${matchId}`;

  // 4. Generate LiveKit access token
  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: user.id,
    name: user.user_metadata?.name || user.email || "anonymous",
    ttl: "6h",
  });
  at.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    roomAdmin: isHost,
  });
  const token = await at.toJwt();

  return new Response(
    JSON.stringify({ token, roomName, wsUrl: LIVEKIT_WS_URL }),
    {
      status: 200,
      headers: { ...corsHeaders, "content-type": "application/json" },
    },
  );
}

serve(handler);
```

- [ ] **Step 2: Create room-info Edge Function**

Create `supabase/functions/room-info/index.ts`:

```typescript
// room-info — Query LiveKit room participant count without joining.
//
// GET /functions/v1/room-info?matchId=<uuid>
// Authorization: Bearer <supabase-jwt>
// Response: { "participantCount": 12, "isActive": true }

// @ts-expect-error: Deno URL import
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
// @ts-expect-error: Deno URL import
import { RoomServiceClient } from "https://esm.sh/livekit-server-sdk@2.6.1";

// deno-lint-ignore no-explicit-any
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LIVEKIT_API_KEY = Deno.env.get("LIVEKIT_API_KEY")!;
const LIVEKIT_API_SECRET = Deno.env.get("LIVEKIT_API_SECRET")!;
const LIVEKIT_WS_URL = Deno.env.get("LIVEKIT_WS_URL")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const livekitHost = LIVEKIT_WS_URL.replace("wss://", "https://");
const roomService = new RoomServiceClient(livekitHost, LIVEKIT_API_KEY, LIVEKIT_API_SECRET);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return new Response("method not allowed", { status: 405, headers: corsHeaders });
  }

  // 1. Verify caller
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing auth" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }
  const jwt = authHeader.replace("Bearer ", "");
  const { error: authError } = await supabase.auth.getUser(jwt);
  if (authError) {
    return new Response(JSON.stringify({ error: "invalid token" }), {
      status: 401,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  // 2. Get matchId from query string
  const url = new URL(req.url);
  const matchId = url.searchParams.get("matchId");
  if (!matchId) {
    return new Response(JSON.stringify({ error: "missing matchId param" }), {
      status: 400,
      headers: { ...corsHeaders, "content-type": "application/json" },
    });
  }

  const roomName = `match_${matchId}`;

  // 3. Query LiveKit for room participants
  try {
    const participants = await roomService.listParticipants(roomName);
    return new Response(
      JSON.stringify({
        participantCount: participants.length,
        isActive: true,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "content-type": "application/json" },
      },
    );
  } catch {
    return new Response(
      JSON.stringify({ participantCount: 0, isActive: false }),
      {
        status: 200,
        headers: { ...corsHeaders, "content-type": "application/json" },
      },
    );
  }
}

serve(handler);
```

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/livekit-token/index.ts supabase/functions/room-info/index.ts
git commit -m "feat(edge): add livekit-token and room-info Edge Functions"
```

---

## Task 5: LiveKit Repository + Events Repository Extensions

**Files:**
- Create: `lib/repositories/livekit_repository.dart`
- Modify: `lib/repositories/events_repository.dart`

- [ ] **Step 1: Create LiveKitRepository**

Create `lib/repositories/livekit_repository.dart`:

```dart
import '../models/livekit_token.dart';
import '../services/supabase.dart';

class LiveKitRepository {
  Future<LiveKitToken> getToken(String matchId) async {
    final res = await supabase.functions.invoke(
      'livekit-token',
      body: {'matchId': matchId},
    );
    if (res.status != 200) {
      throw Exception('Failed to get LiveKit token: ${res.data}');
    }
    return LiveKitToken.fromMap(res.data as Map<String, dynamic>);
  }

  Future<({int participantCount, bool isActive})> getRoomInfo(
    String matchId,
  ) async {
    final res = await supabase.functions.invoke(
      'room-info',
      method: HttpMethod.get,
      queryParameters: {'matchId': matchId},
    );
    if (res.status != 200) {
      return (participantCount: 0, isActive: false);
    }
    final data = res.data as Map<String, dynamic>;
    return (
      participantCount: (data['participantCount'] as int?) ?? 0,
      isActive: (data['isActive'] as bool?) ?? false,
    );
  }
}
```

- [ ] **Step 2: Add match lifecycle methods to EventsRepository**

In `lib/repositories/events_repository.dart`, add these methods inside the `EventsRepository` class, before the closing `}` (before `class _RatingAgg`):

```dart
  Future<void> updateEventStatus(String eventId, EventStatus status) async {
    await supabase
        .from('events')
        .update({'status': status.name})
        .eq('id', eventId);
  }

  Future<void> startMatch(String matchId) async {
    await supabase.from('matches').update({
      'status': 'live',
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'livekit_room': 'match_$matchId',
    }).eq('id', matchId);
  }

  Future<void> endMatch(String matchId, int scoreA, int scoreB) async {
    await supabase.from('matches').update({
      'status': 'finished',
      'done': true,
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'score_a': scoreA,
      'score_b': scoreB,
    }).eq('id', matchId);
  }

  Future<void> updateMatchScore(
    String matchId, {
    required int scoreA,
    required int scoreB,
    required int minute,
  }) async {
    await supabase.from('matches').update({
      'score_a': scoreA,
      'score_b': scoreB,
      'minute': minute,
    }).eq('id', matchId);
  }

  Future<List<Match>> liveMatchesForEvent(String eventId) async {
    final rows = await supabase
        .from('matches')
        .select()
        .eq('event_id', eventId)
        .eq('status', 'live');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Match.fromMap)
        .toList();
  }

  Future<void> insertMatch(Map<String, dynamic> payload) async {
    await supabase.from('matches').insert(payload);
  }

  Future<void> insertMatches(List<Map<String, dynamic>> rows) async {
    await supabase.from('matches').insert(rows);
  }
```

- [ ] **Step 3: Verify compilation**

Run:
```bash
flutter analyze lib/repositories/livekit_repository.dart lib/repositories/events_repository.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/repositories/livekit_repository.dart lib/repositories/events_repository.dart
git commit -m "feat(repo): add LiveKitRepository and match lifecycle methods"
```

---

## Task 6: Providers (LiveKit + Realtime)

**Files:**
- Modify: `lib/providers.dart`

- [ ] **Step 1: Add LiveKit repository provider and import**

In `lib/providers.dart`, add import after the existing repository imports (after line 30):

```dart
import 'repositories/livekit_repository.dart';
import 'models/livekit_token.dart';
```

Add the repository provider after the existing repo providers (after line 56, the `notificationsRepoProvider` line):

```dart
final livekitRepoProvider = Provider((_) => LiveKitRepository());
```

- [ ] **Step 2: Add LiveKit and match realtime providers**

In `lib/providers.dart`, add after the `eventChatMessagesProvider` block (after line 185):

```dart

/// LiveKit token for a match room.
final livekitTokenProvider =
    FutureProvider.family<LiveKitToken, String>((ref, matchId) async {
  return ref.read(livekitRepoProvider).getToken(matchId);
});

/// Real-time match updates via Supabase Realtime (score, status, minute).
final matchRealtimeProvider =
    StreamProvider.family<Match, String>((ref, matchId) {
  return supabase
      .from('matches')
      .stream(primaryKey: ['id'])
      .eq('id', matchId)
      .map((rows) => Match.fromMap(rows.first));
});

/// Live matches for a given event (status='live').
final liveMatchesForEventProvider =
    FutureProvider.family<List<Match>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).liveMatchesForEvent(eventId);
});
```

- [ ] **Step 3: Verify compilation**

Run:
```bash
flutter analyze lib/providers.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/providers.dart
git commit -m "feat(providers): add LiveKit token, match realtime, and live matches providers"
```

---

## Task 7: i18n Strings

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

- [ ] **Step 1: Add Chinese strings**

In `lib/l10n/app_zh.arb`, add the following entries after the `"create_event_publish_failed"` block (find the line after the `@create_event_publish_failed` metadata block ends):

```json
  "event_status_draft": "草稿",
  "event_status_scheduling": "编排中",
  "event_status_completed": "已结束",
  "match_status_live": "直播中",
  "match_status_upcoming": "即将开始",
  "match_status_finished": "已结束",
  "live_room_title": "直播间",
  "live_room_join": "进入直播间",
  "live_room_start": "开始比赛",
  "live_room_end": "结束比赛",
  "live_room_end_confirm": "确认结束比赛并提交最终比分？",
  "live_room_reconnecting": "重新连接中…",
  "live_room_participants": "{count} 人在线",
  "@live_room_participants": { "placeholders": { "count": { "type": "int" } } },
  "live_room_mic_on": "麦克风已开启",
  "live_room_mic_off": "麦克风已关闭",
  "live_room_camera_on": "摄像头已开启",
  "live_room_camera_off": "摄像头已关闭",
  "match_control_score": "记分",
  "match_control_add_goal": "记录进球",
  "match_control_minute": "比赛分钟",
  "match_control_end_match": "结束比赛",
  "schedule_title": "编排赛程",
  "schedule_generate": "生成赛程",
  "schedule_confirm": "确认赛程",
  "schedule_auto_hint": "根据 {template} 模板自动生成",
  "@schedule_auto_hint": { "placeholders": { "template": { "type": "String" } } },
  "schedule_set_time": "设置比赛时间",
  "schedule_assign_teams": "指定对阵队伍",
```

- [ ] **Step 2: Add English strings**

In `lib/l10n/app_en.arb`, add at the same location (after the `@create_event_publish_failed` metadata block):

```json
  "event_status_draft": "Draft",
  "event_status_scheduling": "Scheduling",
  "event_status_completed": "Completed",
  "match_status_live": "Live",
  "match_status_upcoming": "Upcoming",
  "match_status_finished": "Finished",
  "live_room_title": "Live Room",
  "live_room_join": "Join Live Room",
  "live_room_start": "Start Match",
  "live_room_end": "End Match",
  "live_room_end_confirm": "Confirm end match and submit final score?",
  "live_room_reconnecting": "Reconnecting…",
  "live_room_participants": "{count} online",
  "@live_room_participants": { "placeholders": { "count": { "type": "int" } } },
  "live_room_mic_on": "Mic on",
  "live_room_mic_off": "Mic off",
  "live_room_camera_on": "Camera on",
  "live_room_camera_off": "Camera off",
  "match_control_score": "Score",
  "match_control_add_goal": "Record Goal",
  "match_control_minute": "Match Minute",
  "match_control_end_match": "End Match",
  "schedule_title": "Schedule Matches",
  "schedule_generate": "Generate Schedule",
  "schedule_confirm": "Confirm Schedule",
  "schedule_auto_hint": "Auto-generated from {template} template",
  "@schedule_auto_hint": { "placeholders": { "template": { "type": "String" } } },
  "schedule_set_time": "Set match time",
  "schedule_assign_teams": "Assign teams",
```

- [ ] **Step 3: Regenerate localizations**

Run:
```bash
flutter gen-l10n
```

Expected: `lib/l10n/generated/` files regenerated without errors.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add event lifecycle and LiveKit i18n strings"
```

---

## Task 8: MatchControlPanel (Host Scoring Drawer)

**Files:**
- Create: `lib/features/events/match_control_panel.dart`

- [ ] **Step 1: Create the MatchControlPanel widget**

Create `lib/features/events/match_control_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/primary_button.dart';

class MatchControlPanel extends ConsumerStatefulWidget {
  final String matchId;
  final String eventId;
  final int initialScoreA;
  final int initialScoreB;
  final int initialMinute;
  final VoidCallback onMatchEnded;

  const MatchControlPanel({
    super.key,
    required this.matchId,
    required this.eventId,
    required this.initialScoreA,
    required this.initialScoreB,
    required this.initialMinute,
    required this.onMatchEnded,
  });

  @override
  ConsumerState<MatchControlPanel> createState() => _MatchControlPanelState();
}

class _MatchControlPanelState extends ConsumerState<MatchControlPanel> {
  late int _scoreA;
  late int _scoreB;
  late int _minute;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scoreA = widget.initialScoreA;
    _scoreB = widget.initialScoreB;
    _minute = widget.initialMinute;
  }

  Future<void> _updateScore() async {
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepoProvider).updateMatchScore(
        widget.matchId,
        scoreA: _scoreA,
        scoreB: _scoreB,
        minute: _minute,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
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
      if (mounted) widget.onMatchEnded();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: t.elev1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.match_control_score,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 16),
          // Score controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreControl(
                label: 'A',
                score: _scoreA,
                onIncrement: () {
                  setState(() => _scoreA++);
                  _updateScore();
                },
                onDecrement: _scoreA > 0
                    ? () {
                        setState(() => _scoreA--);
                        _updateScore();
                      }
                    : null,
              ),
              // Minute
              Column(
                children: [
                  Text(
                    l.match_control_minute,
                    style: TextStyle(fontSize: 11, color: t.inkSub),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _minute > 0
                            ? () {
                                setState(() => _minute--);
                                _updateScore();
                              }
                            : null,
                      ),
                      Text(
                        "$_minute'",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          setState(() => _minute++);
                          _updateScore();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              _ScoreControl(
                label: 'B',
                score: _scoreB,
                onIncrement: () {
                  setState(() => _scoreB++);
                  _updateScore();
                },
                onDecrement: _scoreB > 0
                    ? () {
                        setState(() => _scoreB--);
                        _updateScore();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: l.match_control_end_match,
            full: true,
            size: BtnSize.lg,
            variant: BtnVariant.destructive,
            busy: _busy,
            onPressed: _endMatch,
          ),
        ],
      ),
    );
  }
}

class _ScoreControl extends StatelessWidget {
  final String label;
  final int score;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  const _ScoreControl({
    required this.label,
    required this.score,
    required this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: t.inkSub)),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 28),
              onPressed: onDecrement,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, size: 28),
              color: t.accent,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
flutter analyze lib/features/events/match_control_panel.dart
```

Expected: No errors. If `BtnVariant.destructive` doesn't exist in `PrimaryButton`, replace with `BtnVariant.secondary` — check `lib/widgets/primary_button.dart` first.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/match_control_panel.dart
git commit -m "feat(ui): add MatchControlPanel for host scoring controls"
```

---

## Task 9: MatchLiveRoom Screen

**Files:**
- Create: `lib/features/events/match_live_room.dart`

- [ ] **Step 1: Create the MatchLiveRoom screen**

Create `lib/features/events/match_live_room.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import 'match_control_panel.dart';

class MatchLiveRoom extends ConsumerStatefulWidget {
  final String eventId;
  final String matchId;
  const MatchLiveRoom({
    super.key,
    required this.eventId,
    required this.matchId,
  });

  @override
  ConsumerState<MatchLiveRoom> createState() => _MatchLiveRoomState();
}

class _MatchLiveRoomState extends ConsumerState<MatchLiveRoom> {
  Room? _room;
  LocalParticipant? _localParticipant;
  bool _connecting = true;
  String? _error;
  bool _micEnabled = true;
  bool _camEnabled = true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final tokenData =
          await ref.read(livekitTokenProvider(widget.matchId).future);
      final room = Room();

      room.addListener(_onRoomEvent);

      await room.connect(
        tokenData.wsUrl,
        tokenData.token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true,
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );

      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _room = room;
        _localParticipant = room.localParticipant;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _connecting = false;
      });
    }
  }

  void _onRoomEvent() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleMic() async {
    _micEnabled = !_micEnabled;
    await _localParticipant?.setMicrophoneEnabled(_micEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCam() async {
    _camEnabled = !_camEnabled;
    await _localParticipant?.setCameraEnabled(_camEnabled);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomEvent);
    _room?.disconnect();
    super.dispose();
  }

  bool get _isHost {
    final uid = currentUserId;
    if (uid == null) return false;
    final eventAsync = ref.read(eventDetailProvider(widget.eventId));
    return eventAsync.valueOrNull?.creatorId == uid;
  }

  List<Participant> get _participants {
    final room = _room;
    if (room == null) return [];
    return [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
  }

  void _showControlPanel() {
    final matchAsync = ref.read(matchRealtimeProvider(widget.matchId));
    final match = matchAsync.valueOrNull;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchControlPanel(
        matchId: widget.matchId,
        eventId: widget.eventId,
        initialScoreA: match?.scoreA ?? 0,
        initialScoreB: match?.scoreB ?? 0,
        initialMinute: match?.minute ?? 0,
        onMatchEnded: () {
          Navigator.pop(context);
          _room?.disconnect();
          if (mounted) context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final matchAsync = ref.watch(matchRealtimeProvider(widget.matchId));

    if (_connecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                l.live_room_reconnecting,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _connecting = true;
                    _error = null;
                  });
                  _connect();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final participants = _participants;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _TopBar(
              matchAsync: matchAsync,
              participantCount: participants.length,
              onBack: () {
                _room?.disconnect();
                context.pop();
              },
              isHost: _isHost,
              onControl: _isHost ? _showControlPanel : null,
            ),
            // Video grid
            Expanded(
              child: _VideoGrid(participants: participants),
            ),
            // Score bar
            matchAsync.when(
              data: (match) => _ScoreBar(match: match),
              loading: () => const SizedBox(height: 40),
              error: (_, __) => const SizedBox(height: 40),
            ),
            // Bottom controls
            _BottomControls(
              micEnabled: _micEnabled,
              camEnabled: _camEnabled,
              onToggleMic: _toggleMic,
              onToggleCam: _toggleCam,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final AsyncValue<Match> matchAsync;
  final int participantCount;
  final VoidCallback onBack;
  final bool isHost;
  final VoidCallback? onControl;

  const _TopBar({
    required this.matchAsync,
    required this.participantCount,
    required this.onBack,
    required this.isHost,
    this.onControl,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              l.live_room_title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          if (isHost)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
              onPressed: onControl,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$participantCount',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Video grid — adaptive layout for N participants
// ─────────────────────────────────────────────────────────────
class _VideoGrid extends StatelessWidget {
  final List<Participant> participants;
  const _VideoGrid({required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    final count = participants.length;
    final crossCount = count <= 1
        ? 1
        : count <= 4
            ? 2
            : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 4 / 3,
      ),
      itemCount: count,
      itemBuilder: (ctx, i) => _ParticipantTile(participant: participants[i]),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.videoTrackPublications.values
        .where((pub) => pub.track != null && !pub.muted)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.grey[900],
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white12,
                  child: Text(
                    (participant.name ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            // Name label
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  participant.name ?? participant.identity ?? '?',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            // Mute indicator
            if (participant.isMuted)
              const Positioned(
                right: 6,
                bottom: 6,
                child: Icon(Icons.mic_off, color: Colors.redAccent, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Score bar
// ─────────────────────────────────────────────────────────────
class _ScoreBar extends StatelessWidget {
  final Match match;
  const _ScoreBar({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              match.teamALabel ?? 'Team A',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${match.scoreA ?? 0} - ${match.scoreB ?? 0}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              match.teamBLabel ?? 'Team B',
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),
          if (match.minute != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${match.minute}'",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom controls
// ─────────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final bool micEnabled;
  final bool camEnabled;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;

  const _BottomControls({
    required this.micEnabled,
    required this.camEnabled,
    required this.onToggleMic,
    required this.onToggleCam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: micEnabled ? Icons.mic : Icons.mic_off,
            active: micEnabled,
            onPressed: onToggleMic,
          ),
          const SizedBox(width: 24),
          _ControlButton(
            icon: camEnabled ? Icons.videocam : Icons.videocam_off,
            active: camEnabled,
            onPressed: onToggleCam,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white24 : Colors.redAccent,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
flutter analyze lib/features/events/match_live_room.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/match_live_room.dart
git commit -m "feat(ui): add MatchLiveRoom multi-party video screen"
```

---

## Task 10: ScheduleMatchesScreen

**Files:**
- Create: `lib/features/events/schedule_matches_screen.dart`

- [ ] **Step 1: Create the ScheduleMatchesScreen**

Create `lib/features/events/schedule_matches_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

class ScheduleMatchesScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ScheduleMatchesScreen({super.key, required this.eventId});

  @override
  ConsumerState<ScheduleMatchesScreen> createState() =>
      _ScheduleMatchesScreenState();
}

class _ScheduleMatchesScreenState
    extends ConsumerState<ScheduleMatchesScreen> {
  List<_MatchSlot> _slots = [];
  bool _generated = false;
  bool _busy = false;

  void _generate(Event event) {
    final template = event.template ?? 'knockout16';
    final slots = <_MatchSlot>[];

    switch (template) {
      case 'knockout16':
        for (var i = 0; i < 8; i++) {
          slots.add(_MatchSlot(round: 'qf', index: i));
        }
        for (var i = 0; i < 4; i++) {
          slots.add(_MatchSlot(round: 'sf', index: i));
        }
        slots.add(_MatchSlot(round: 'final', index: 0));
      case 'group8':
        for (var g = 0; g < 2; g++) {
          for (var i = 0; i < 6; i++) {
            slots.add(_MatchSlot(round: 'group', index: g * 6 + i));
          }
        }
        for (var i = 0; i < 2; i++) {
          slots.add(_MatchSlot(round: 'sf', index: i));
        }
        slots.add(_MatchSlot(round: 'final', index: 0));
      case 'league':
        final maxTeams = event.teamsMax ?? 8;
        final totalMatches = maxTeams * (maxTeams - 1);
        for (var i = 0; i < totalMatches; i++) {
          slots.add(_MatchSlot(round: 'league', index: i));
        }
      default:
        for (var i = 0; i < 15; i++) {
          slots.add(_MatchSlot(round: 'group', index: i));
        }
    }

    setState(() {
      _slots = slots;
      _generated = true;
    });
  }

  Future<void> _confirm(Event event) async {
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
        showToast(context, context.l10n.schedule_confirm, success: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.schedule_title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink),
        ),
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (event) => _generated
            ? _SlotList(
                slots: _slots,
                onSlotChanged: (i, slot) =>
                    setState(() => _slots[i] = slot),
              )
            : _GeneratePrompt(event: event, onGenerate: () => _generate(event)),
      ),
      bottomNavigationBar: _generated
          ? eventAsync.whenOrNull(
              data: (event) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PrimaryButton(
                    label: l.schedule_confirm,
                    full: true,
                    size: BtnSize.lg,
                    busy: _busy,
                    onPressed: () => _confirm(event),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _MatchSlot {
  final String round;
  final int index;
  String? teamALabel;
  String? teamBLabel;
  DateTime? playedAt;

  _MatchSlot({
    required this.round,
    required this.index,
    this.teamALabel,
    this.teamBLabel,
    this.playedAt,
  });
}

class _GeneratePrompt extends StatelessWidget {
  final Event event;
  final VoidCallback onGenerate;
  const _GeneratePrompt({required this.event, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 64, color: t.inkSub),
            const SizedBox(height: 16),
            Text(
              l.schedule_auto_hint(event.template ?? 'knockout16'),
              style: TextStyle(fontSize: 14, color: t.inkSub),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: l.schedule_generate,
              size: BtnSize.lg,
              onPressed: onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotList extends StatelessWidget {
  final List<_MatchSlot> slots;
  final void Function(int index, _MatchSlot slot) onSlotChanged;
  const _SlotList({required this.slots, required this.onSlotChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: slots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final slot = slots[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.elev1,
            borderRadius: BorderRadius.circular(t.r2),
            border: Border.all(color: t.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${slot.round.toUpperCase()} #${slot.index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Team A',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: t.ink),
                      onChanged: (v) {
                        slot.teamALabel = v.isEmpty ? null : v;
                        onSlotChanged(i, slot);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('vs',
                        style: TextStyle(fontSize: 12, color: t.inkSub)),
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Team B',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      style: TextStyle(fontSize: 13, color: t.ink),
                      onChanged: (v) {
                        slot.teamBLabel = v.isEmpty ? null : v;
                        onSlotChanged(i, slot);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDateTimePicker(ctx);
                  if (picked != null) {
                    slot.playedAt = picked;
                    onSlotChanged(i, slot);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: t.inkSub),
                      const SizedBox(width: 6),
                      Text(
                        slot.playedAt != null
                            ? _fmt(slot.playedAt!)
                            : context.l10n.schedule_set_time,
                        style: TextStyle(fontSize: 12, color: t.inkSub),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

Future<DateTime?> showDateTimePicker(BuildContext context) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now().add(const Duration(days: 1)),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 15, minute: 0),
  );
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
```

- [ ] **Step 2: Verify compilation**

Run:
```bash
flutter analyze lib/features/events/schedule_matches_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/schedule_matches_screen.dart
git commit -m "feat(ui): add ScheduleMatchesScreen for bracket generation"
```

---

## Task 11: Routes — Add New Screens

**Files:**
- Modify: `lib/routes.dart`

- [ ] **Step 1: Add imports**

In `lib/routes.dart`, add after line 10 (`import '...match_ratings_screen.dart';`):

```dart
import 'features/events/match_live_room.dart';
import 'features/events/schedule_matches_screen.dart';
```

- [ ] **Step 2: Add routes**

In `lib/routes.dart`, add after the match ratings route block (after line 123, the closing `),` of the `/event/:eventId/match/:matchId/ratings` route):

```dart
    GoRoute(
      path: '/event/:eventId/match/:matchId/live',
      builder: (_, s) => MatchLiveRoom(
        eventId: s.pathParameters['eventId']!,
        matchId: s.pathParameters['matchId']!,
      ),
    ),
    GoRoute(
      path: '/event/:id/schedule',
      builder: (_, s) =>
          ScheduleMatchesScreen(eventId: s.pathParameters['id']!),
    ),
```

- [ ] **Step 3: Verify compilation**

Run:
```bash
flutter analyze lib/routes.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/routes.dart
git commit -m "feat(routes): add match live room and schedule matches routes"
```

---

## Task 12: Modify MatchDetailScreen — Use MatchStatus + Live CTA

**Files:**
- Modify: `lib/features/events/match_detail_screen.dart`

- [ ] **Step 1: Remove the local _MatchStatus enum and _statusFor function**

In `lib/features/events/match_detail_screen.dart`, delete the following (around lines 544–551):

```dart
enum _MatchStatus { upcoming, live, done }

_MatchStatus _statusFor(Match m) {
  if (m.done) return _MatchStatus.done;
  final at = m.playedAt;
  if (at != null && at.isAfter(DateTime.now())) return _MatchStatus.upcoming;
  return _MatchStatus.live;
}
```

- [ ] **Step 2: Update _MatchDetailBody to use MatchStatus**

Replace `final status = _statusFor(match);` (line 88) with:

```dart
    final status = match.status;
```

- [ ] **Step 3: Update _HeaderCard to use MatchStatus**

Change its `status` field type from `_MatchStatus` to `MatchStatus`:

```dart
class _HeaderCard extends StatelessWidget {
  final Match match;
  final MatchStatus status;
```

- [ ] **Step 4: Update _StatusChip to use MatchStatus**

Find the `_StatusChip` class and update all references from `_MatchStatus` to `MatchStatus`. Update the status value comparisons:
- `_MatchStatus.done` → `MatchStatus.finished`
- `_MatchStatus.live` → `MatchStatus.live`
- `_MatchStatus.upcoming` → `MatchStatus.upcoming`

- [ ] **Step 5: Update _BottomCtaArea to use MatchStatus and add Live CTA**

Replace the `_BottomCtaArea` field type and update the build method. Change:
- `final _MatchStatus status;` → `final MatchStatus status;`
- `_MatchStatus.done` → `MatchStatus.finished`
- `_MatchStatus.upcoming` → `MatchStatus.upcoming`

Replace the live section (the comment `// Live (kicked off but not done) — no CTA for now.` and `return const SizedBox.shrink();`) with:

```dart
    if (widget.status == MatchStatus.live) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PrimaryButton(
          label: l.live_room_join,
          full: true,
          size: BtnSize.lg,
          onPressed: () => context.push(
            '/event/${widget.eventId}/match/${widget.match.id}/live',
          ),
        ),
      );
    }

    return const SizedBox.shrink();
```

- [ ] **Step 6: Update the `if (match.done)` check in _MatchDetailBody**

In `_MatchDetailBody.build`, replace `if (match.done)` (line 97) with:

```dart
          if (match.status == MatchStatus.finished)
```

- [ ] **Step 7: Verify compilation**

Run:
```bash
flutter analyze lib/features/events/match_detail_screen.dart
```

Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add lib/features/events/match_detail_screen.dart
git commit -m "feat(match-detail): use MatchStatus enum and add live room CTA"
```

---

## Task 13: Modify EventDetailScreen — LIVE Indicator + Organizer Actions

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart`

- [ ] **Step 1: Add LIVE dot to _MatchCard in bracket panel**

Find the `_MatchCard` widget in `event_detail_screen.dart`. In its build method, add a LIVE indicator when `match.status == MatchStatus.live`. Look for the row that shows the round label or status, and add:

```dart
if (match.status == MatchStatus.live)
  Container(
    width: 8,
    height: 8,
    margin: const EdgeInsets.only(right: 6),
    decoration: const BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
    ),
  ),
```

- [ ] **Step 2: Route live match taps to MatchLiveRoom**

In the `_MatchCard`'s `onTap` handler, change the navigation so that live matches go to the live room:

```dart
onTap: () {
  if (match.status == MatchStatus.live) {
    context.push('/event/${match.eventId}/match/${match.id}/live');
  } else {
    context.push('/event/${match.eventId}/match/${match.id}');
  }
},
```

- [ ] **Step 3: Add organizer schedule button**

In the `EventDetailScreen`, when the event status is `scheduling` and the current user is the creator, show a "Schedule Matches" button. Find the area where bottom CTAs are rendered (the `_BottomCta` widget or equivalent area). Add a condition:

```dart
if (event.status == EventStatus.scheduling && event.creatorId == currentUserId)
  PrimaryButton(
    label: context.l10n.schedule_generate,
    full: true,
    size: BtnSize.lg,
    onPressed: () => context.push('/event/${event.id}/schedule'),
  ),
```

- [ ] **Step 4: Update EventStatus.done references**

Search for any references to `EventStatus.done` in event_detail_screen.dart and replace with `EventStatus.completed`.

- [ ] **Step 5: Update `match.done` references**

Search for references to `match.done` in event_detail_screen.dart (used in bracket/standings) and replace with `match.status == MatchStatus.finished`.

- [ ] **Step 6: Verify compilation**

Run:
```bash
flutter analyze lib/features/events/event_detail_screen.dart
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(event-detail): add LIVE indicator, organizer schedule button"
```

---

## Task 14: Modify EventsHubScreen — LIVE Badge on Ongoing Events

**Files:**
- Modify: `lib/features/events/events_hub_screen.dart`

- [ ] **Step 1: Update EventStatus.done references**

Search for `EventStatus.done` in events_hub_screen.dart and replace with `EventStatus.completed`.

- [ ] **Step 2: Add LIVE badge to event cards in the ongoing tab**

In the `_LiveEventRow` widget, add a LIVE badge. Query `liveMatchesForEventProvider(event.id)` and show a badge if there are live matches:

Find the event card widget and add inside its `build` method, alongside the existing status/metadata row:

```dart
// Check for live matches in this event
final liveAsync = ref.watch(liveMatchesForEventProvider(event.id));
final hasLive = liveAsync.valueOrNull?.isNotEmpty ?? false;
```

Then add a LIVE pill next to the event name or status:

```dart
if (hasLive)
  Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.red,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
```

Note: `_LiveEventRow` needs to be converted from `StatelessWidget` to `ConsumerWidget` to access `ref.watch()`. Change:
- `class _LiveEventRow extends StatelessWidget` → `class _LiveEventRow extends ConsumerWidget`
- `Widget build(BuildContext context)` → `Widget build(BuildContext context, WidgetRef ref)`

- [ ] **Step 3: Verify compilation**

Run:
```bash
flutter analyze lib/features/events/events_hub_screen.dart
```

Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/events/events_hub_screen.dart
git commit -m "feat(events-hub): show LIVE badge on events with active matches"
```

---

## Task 15: Fix Remaining EventStatus.done References

**Files:**
- Various files that reference `EventStatus.done`

- [ ] **Step 1: Find all references**

Run:
```bash
grep -rn 'EventStatus\.done' lib/
```

Expected: Lists files still using `EventStatus.done`.

- [ ] **Step 2: Update each file**

For each file found, replace `EventStatus.done` with `EventStatus.completed`. Common locations:
- `lib/features/me/my_events_screen.dart`
- `lib/features/home/` card widgets
- Any screen that displays event status labels

Also update status label display: where the code maps `EventStatus.done` to a localized string like `l.event_status_done`, add handling for `EventStatus.completed` → `l.event_status_completed`, `EventStatus.draft` → `l.event_status_draft`, `EventStatus.scheduling` → `l.event_status_scheduling`.

- [ ] **Step 3: Verify full compilation**

Run:
```bash
flutter analyze
```

Expected: No errors across the entire project.

- [ ] **Step 4: Commit**

```bash
git add -u
git commit -m "refactor: replace EventStatus.done with completed across codebase"
```

---

## Task 16: Regenerate Localizations + Full Build Verification

**Files:**
- `lib/l10n/generated/*`

- [ ] **Step 1: Regenerate l10n**

Run:
```bash
flutter gen-l10n
```

Expected: Regenerates without errors.

- [ ] **Step 2: Full build check**

Run:
```bash
flutter build apk --debug 2>&1 | tail -20
```

Expected: Build succeeds. If there are errors, fix them and re-run.

- [ ] **Step 3: Commit generated files**

```bash
git add lib/l10n/generated/
git commit -m "chore(l10n): regenerate localization files"
```

---

## Task 17: Integration Smoke Test

- [ ] **Step 1: Run the app**

Run:
```bash
flutter run
```

Navigate through the event flow:
1. Go to Events tab → verify events load
2. Tap an event → verify 5 tabs still work
3. Check bracket tab → verify match cards render with status
4. Tap a match → verify match detail loads with correct CTA
5. If a match is live, tap "Enter Live Room" → verify LiveKit connection attempt (may fail without configured keys, that's OK)

- [ ] **Step 2: Verify Edge Functions structure**

Run:
```bash
ls -la supabase/functions/livekit-token/
ls -la supabase/functions/room-info/
```

Expected: Both directories contain `index.ts`.

- [ ] **Step 3: Final commit with any fixes**

```bash
git add -u
git commit -m "fix: address integration smoke test issues"
```

Only create this commit if there were fixes needed.
