# Event Lifecycle + LiveKit Live Streaming Design

**Date:** 2026-04-22
**Status:** Approved
**Scope:** Complete event lifecycle flow + multi-party live streaming via LiveKit

## Overview

Implement end-to-end event lifecycle management with integrated multi-party live streaming using LiveKit. Each match maps to one LiveKit Room where all participants can publish and receive audio/video (many-to-many). Supabase Realtime handles score updates and chat; LiveKit handles media.

## Approach

**Match-Centric (1 match = 1 LiveKit Room).** Clean mapping to the existing data model, natural isolation between concurrent matches, and straightforward scaling.

---

## 1. Event Lifecycle State Machine

### Event-Level States

```
draft → registering → scheduling → ongoing → completed
```

| State | Meaning | Trigger |
|-------|---------|---------|
| `draft` | Unpublished draft | Created but not published |
| `registering` | Accepting team signups | Published by organizer |
| `scheduling` | Bracket/schedule being arranged | Registration deadline passed |
| `ongoing` | Matches in progress | Schedule confirmed by organizer |
| `completed` | All matches done | All matches finished |

### Match-Level States

```
upcoming → live → finished
```

| State | Meaning | Trigger |
|-------|---------|---------|
| `upcoming` | Not yet started | Default after schedule creation |
| `live` | Streaming now | Organizer starts the live room |
| `finished` | Match over | Organizer ends match and confirms score |

### Key Changes from Current

- `Match.done` (bool) replaced by `Match.status` enum (`upcoming`/`live`/`finished`)
- `Event.status` expanded from 3 values (`registering`/`ongoing`/`done`) to 5 (`draft`/`registering`/`scheduling`/`ongoing`/`completed`)
- Backward compatible: `done` field preserved in DB, `Match.fromJson` falls back to `done` if `status` is null

---

## 2. LiveKit Integration Architecture

### System Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Flutter App │────>│ Supabase Edge Fn │────>│ LiveKit Cloud│
│(livekit_client)    │  (Token generation)│     │  (SFU server)│
└─────────────┘     └──────────────────┘     └─────────────┘
       │                                            │
       │            ┌──────────────────┐            │
       └───────────>│ Supabase Realtime│<───────────┘
                    │(scores/status/chat)│
                    └──────────────────┘
```

### Channel Responsibilities

| Channel | Purpose | Technology |
|---------|---------|------------|
| LiveKit Room | Audio/video streams (multi-party) | WebRTC via LiveKit |
| Supabase Realtime | Score updates, match status, chat | PostgreSQL Changes |
| Supabase REST | Token requests, match CRUD, ratings | Edge Functions + PostgREST |

### Participant Roles & Permissions

| Role | Publish Video | Publish Audio | Room Admin | Kick |
|------|:---:|:---:|:---:|:---:|
| host (event creator) | Y | Y | Y | Y |
| participant (everyone else) | Y | Y | N | N |

### LiveKit Environment

- **Development:** LiveKit Cloud free tier (register at cloud.livekit.io)
- **Production:** Decide later (Cloud paid tier or self-hosted)

### Flutter Dependency

```yaml
livekit_client: ^2.3.0
```

---

## 3. Database Changes

### New Migration: `0010_match_livekit.sql`

```sql
-- 1. matches table extensions
ALTER TABLE matches ADD COLUMN status text DEFAULT 'upcoming'
  CHECK (status IN ('upcoming','live','finished'));
ALTER TABLE matches ADD COLUMN livekit_room text;
ALTER TABLE matches ADD COLUMN started_at timestamptz;
ALTER TABLE matches ADD COLUMN ended_at timestamptz;

-- 2. Migrate existing data
UPDATE matches SET status = 'finished' WHERE done = true;
UPDATE matches SET status = 'upcoming' WHERE done = false;

-- 3. events table status expansion
ALTER TABLE events DROP CONSTRAINT IF EXISTS events_status_check;
ALTER TABLE events ADD CONSTRAINT events_status_check
  CHECK (status IN ('draft','registering','scheduling','ongoing','completed','done'));

-- 4. Indexes for live query optimization
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_event_status ON matches(event_id, status);

-- 5. Enable Realtime on matches table
ALTER PUBLICATION supabase_realtime ADD TABLE matches;

-- 6. RLS policies
CREATE POLICY "matches_read" ON matches FOR SELECT USING (true);

CREATE POLICY "matches_update_by_creator" ON matches FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM events
    WHERE events.id = matches.event_id
    AND events.creator_id = auth.uid()
  )
);

CREATE POLICY "goals_insert_by_creator" ON goals FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM matches
    JOIN events ON events.id = matches.event_id
    WHERE matches.id = goals.match_id
    AND events.creator_id = auth.uid()
  )
);
```

---

## 4. Supabase Edge Functions

### `livekit-token`

```
POST /functions/v1/livekit-token
Authorization: Bearer <supabase-jwt>
Body: { "matchId": "..." }
Response: { "token": "...", "roomName": "match_{matchId}", "wsUrl": "wss://..." }
```

Logic:
1. Extract and verify Supabase JWT from Authorization header
2. Query `matches` table to confirm matchId exists
3. Determine role: query `events` table, if `user == event.creator_id` then `host`, else `participant`
4. Generate LiveKit AccessToken with appropriate grants:
   - host: `canPublish=true`, `canSubscribe=true`, `roomAdmin=true`
   - participant: `canPublish=true`, `canSubscribe=true`, `roomAdmin=false`
5. Room name: `match_{matchId}`
6. Token TTL: 6 hours
7. Return `{ token, roomName, wsUrl }`

### `room-info`

```
GET /functions/v1/room-info?matchId=xxx
Authorization: Bearer <supabase-jwt>
Response: { "participantCount": 12, "isActive": true }
```

Authenticated endpoint. Used by non-live pages (EventsHubScreen, MatchDetailScreen) to show viewer count without joining the room. Calls LiveKit Server API `listParticipants` internally.

### Environment Variables (Supabase Secrets)

```
LIVEKIT_API_KEY=<from LiveKit Cloud>
LIVEKIT_API_SECRET=<from LiveKit Cloud>
LIVEKIT_WS_URL=wss://<project>.livekit.cloud
```

---

## 5. Data Models

### Match Model Extension

```dart
class Match {
  // Existing fields
  final String id, eventId;
  final String? round, teamALabel, teamBLabel;
  final int? scoreA, scoreB;
  final String? pkScore;
  final DateTime? playedAt;

  // New fields
  final MatchStatus status;      // upcoming / live / finished
  final String? livekitRoom;     // "match_{id}"
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? minute;             // current match minute (int)
  final int viewers;             // current viewer count
}

enum MatchStatus { upcoming, live, finished }
```

### Event Model Extension

```dart
enum EventStatus {
  draft,
  registering,
  scheduling,
  ongoing,
  completed,
}
```

### New: LiveKitToken Model

```dart
class LiveKitToken {
  final String token;
  final String roomName;
  final String wsUrl;
}
```

---

## 6. Repository & Provider Changes

### New: LiveKitRepository

```dart
class LiveKitRepository {
  Future<LiveKitToken> getToken(String matchId);
}
```

### EventsRepository Extensions

```dart
Future<void> updateMatchStatus(String matchId, MatchStatus status);
Future<void> updateMatchScore(String matchId, int scoreA, int scoreB, int minute);
Future<void> startMatch(String matchId);      // status=live, started_at=now, livekit_room set
Future<void> endMatch(String matchId);        // status=finished, ended_at=now
Future<void> generateSchedule(String eventId); // auto-generate matches from template
Future<void> updateEventStatus(String eventId, EventStatus status);
Future<List<Match>> liveMatchesForEvent(String eventId);
```

### New Providers

```dart
final livekitTokenProvider = FutureProvider.family<LiveKitToken, String>();  // by matchId
final matchRealtimeProvider = StreamProvider.family<Match, String>();        // subscribe to match changes
final liveMatchesForEventProvider = FutureProvider.family<List<Match>, String>();
```

---

## 7. Screens & Components

### New: ScheduleMatchesScreen

- **Route:** `/event/:id/schedule`
- **Entry:** EventDetailScreen, visible when event status is `scheduling`
- **Function:** Auto-generate match skeleton from event template (knockout16/group8/wc/league), assign teams and times, confirm to transition event to `ongoing`

### New: MatchLiveRoom

- **Route:** `/event/:eventId/match/:matchId/live`
- **Entry:** MatchDetailScreen "Enter Live Room" button (when match status is `live`)
- **Replaces:** WcLiveScreen for platform events (WcLiveScreen preserved for external/World Cup matches)

**Layout:**

```
┌──────────────────────────────┐
│  <- Back    Match Info  Count │  Top bar
├──────────────────────────────┤
│                              │
│   ┌────┐ ┌────┐ ┌────┐     │
│   │Vid1│ │Vid2│ │Vid3│     │  Video grid
│   └────┘ └────┘ └────┘     │  (adaptive layout)
│   ┌────┐ ┌────┐            │
│   │Vid4│ │ Me │            │
│   └────┘ └────┘            │
│                              │
├──────────────────────────────┤
│  Team A  2 - 1  Team B  67' │  Live score bar
├──────────────────────────────┤
│  Chat messages...            │  Chat area
├──────────────────────────────┤
│  Mic  Cam  [input]    Send  │  Bottom controls
└──────────────────────────────┘
```

- **Video grid:** Participant camera feeds, adaptive 1~N layout
- **Live score bar:** Subscribes to `matchRealtimeProvider` for real-time updates
- **Chat area:** Reuses existing event chat (`eventChatMessagesProvider`)
- **Bottom controls:** Mic toggle, camera toggle, message input, send button

### New: MatchControlPanel (Bottom Drawer)

- **Visibility:** Only for host role (event creator)
- **Functions:**
  - Update score (+1/-1 buttons per team)
  - Record goal (scorer, assist, minute, penalty/own-goal flags)
  - Update match minute
  - End match (confirm final score, transition to `finished`)

### Modified: EventDetailScreen

- Bracket tab: match cards show LIVE indicator (red pulsing dot) for `status=live`
- Tapping a live match goes directly to MatchLiveRoom
- Organizer actions area: visible when current user is `creator_id`

### Modified: MatchDetailScreen

- Bottom CTA changes by match status:
  - `upcoming`: "Set Reminder" (existing)
  - `live`: "Enter Live Room" -> MatchLiveRoom
  - `finished`: "View Ratings" (existing)

### Modified: EventsHubScreen

- "Ongoing" tab: event cards show LIVE badge + viewer count if any match is currently live

---

## 8. Data Flow Sequences

### Start Match (Organizer)

```
Organizer taps "Start Match"
  -> EventsRepo.startMatch(matchId)
  -> DB: match.status='live', started_at=now, livekit_room='match_{id}'
  -> LiveKitRepo.getToken(matchId)
  -> Edge Function creates room + returns token
  -> Flutter connects to LiveKit Room as host
```

### Join Match (Participant)

```
Participant taps "Enter Live Room"
  -> LiveKitRepo.getToken(matchId)
  -> Edge Function returns token (joins existing room)
  -> Flutter connects to LiveKit Room as participant
  -> Subscribe matchRealtimeProvider(matchId) for live scores
```

### Score Update (Organizer)

```
Organizer taps "+1" in MatchControlPanel
  -> EventsRepo.updateMatchScore(matchId, scoreA, scoreB, minute)
  -> DB update -> Supabase Realtime broadcast
  -> All subscribers' matchRealtimeProvider receives update
  -> UI refreshes score bar automatically
```

### End Match (Organizer)

```
Organizer taps "End Match" -> confirmation dialog
  -> EventsRepo.endMatch(matchId)
  -> DB: match.status='finished', ended_at=now
  -> LiveKit Room: organizer disconnects
  -> Room auto-closes when last participant leaves
  -> UI transitions to post-match (ratings available)
```

---

## 9. Edge Cases

| Scenario | Handling |
|----------|----------|
| Network disconnect | LiveKit SDK auto-reconnects (up to 5 attempts); UI shows "Reconnecting..." overlay; Supabase Realtime also auto-reconnects |
| Organizer leaves mid-match | Room stays open, other participants continue; organizer can rejoin as host |
| App killed during match | On reopen, check match.status; if still `live`, show "Rejoin Live Room" button |
| Concurrent score updates | Cannot happen: RLS restricts writes to event creator only (single writer) |
| Token expired | LiveKit SDK supports token refresh callback; auto-requests new token |
| Concurrent matches | Same event can have multiple live matches, each with its own LiveKit Room |
| Zero viewers | Room auto-cleaned by LiveKit Cloud when last participant leaves |
| `done` field backward compat | `status` column added alongside `done`; `Match.fromJson` falls back to `done` if `status` is null |

### Viewer Count

- **Inside live room:** `room.participants.length` + `onParticipantConnected`/`onParticipantDisconnected` callbacks
- **Outside live room:** Edge Function `room-info` queries LiveKit API for participant count

---

## 10. Localization (i18n)

New strings for both `app_zh.arb` and `app_en.arb`:

| Key | ZH | EN |
|-----|----|----|
| `event_status_draft` | 草稿 | Draft |
| `event_status_scheduling` | 编排中 | Scheduling |
| `event_status_completed` | 已结束 | Completed |
| `match_status_live` | 直播中 | Live |
| `match_status_upcoming` | 即将开始 | Upcoming |
| `match_status_finished` | 已结束 | Finished |
| `live_room_title` | 直播间 | Live Room |
| `live_room_join` | 进入直播间 | Join Live Room |
| `live_room_start` | 开始比赛 | Start Match |
| `live_room_end` | 结束比赛 | End Match |
| `live_room_end_confirm` | 确认结束比赛并提交最终比分？ | Confirm end match and submit final score? |
| `live_room_reconnecting` | 重新连接中... | Reconnecting... |
| `live_room_participants` | {count} 人在线 | {count} online |
| `live_room_mic_on` | 麦克风已开启 | Mic on |
| `live_room_mic_off` | 麦克风已关闭 | Mic off |
| `live_room_camera_on` | 摄像头已开启 | Camera on |
| `live_room_camera_off` | 摄像头已关闭 | Camera off |
| `match_control_score` | 记分 | Score |
| `match_control_add_goal` | 记录进球 | Record Goal |
| `match_control_minute` | 比赛分钟 | Match Minute |
| `schedule_generate` | 生成赛程 | Generate Schedule |
| `schedule_confirm` | 确认赛程 | Confirm Schedule |
| `schedule_auto_hint` | 根据 {template} 模板自动生成 | Auto-generated from {template} template |

---

## 11. Implementation Scope Summary

| Category | Items |
|----------|-------|
| Database | 1 migration file (matches table extension + RLS) |
| Edge Functions | 2 (`livekit-token`, `room-info`) |
| New screens | 2 (`ScheduleMatchesScreen`, `MatchLiveRoom`) |
| New components | 1 (`MatchControlPanel` bottom drawer) |
| Modified screens | 3 (`EventDetailScreen`, `MatchDetailScreen`, `EventsHubScreen`) |
| Models | `Match` extended, `EventStatus` extended, `LiveKitToken` new |
| Repositories | `LiveKitRepository` new, `EventsRepository` extended |
| Providers | ~4 new providers |
| Dependencies | `livekit_client` package |
| i18n | ~22 new strings (zh + en) |
