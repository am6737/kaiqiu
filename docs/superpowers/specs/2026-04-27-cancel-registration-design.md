# Cancel Event Registration (取消报名)

## Problem

Users who registered for an event cannot cancel their registration. Once registered, the bottom CTA shows "已报名" in a disabled state with no way to undo.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| When can users cancel? | Only during `registering` phase | Once scheduling starts, withdrawing breaks match arrangements |
| Confirmation required? | Yes, confirmation dialog | Cancellation deletes the team and all members — prevent accidental taps |
| UI entry point | Bottom CTA button | Reuse the currently-wasted disabled button area; no extra UI needed |
| Data handling | Hard delete | Casual pickup games don't need audit trails; `ON DELETE CASCADE` on `team_members` makes this clean |

## User Flow

1. User opens event detail for an event they have registered for
2. Event is in `registering` status
3. Bottom CTA displays "取消报名" button (destructive style)
4. User taps button
5. Confirmation dialog appears: "确定要取消报名吗？队伍和成员信息将被删除且无法恢复"
6. User confirms
7. System deletes the team row (members cascade), removes favorites marker, clears LocalStore
8. Providers refresh: button reverts to "立即报名", team count decrements, team list updates
9. Toast: "已取消报名"

If the event is NOT in `registering` status, the bottom CTA continues to show "已报名" in disabled state (current behavior).

## Changes Required

### 1. Repository — `events_repository.dart`

Add `cancelRegistration(String eventId, String userId)`:

```dart
Future<void> cancelRegistration(String eventId, String userId) async {
  await supabase
      .from('teams')
      .delete()
      .eq('event_id', eventId)
      .eq('captain_id', userId);
}
```

`team_members` rows are automatically removed via `ON DELETE CASCADE`.

### 2. UI — `bottom_cta.dart`

Current logic when `registered == true`: show disabled "已报名" button.

New logic:

```
if registered && event.status == registering:
    show "取消报名" button (enabled, destructive style)
    onTap → show confirmation dialog → call cancelRegistration flow
else if registered:
    show "已报名" button (disabled, current behavior)
```

Cancel flow on confirm:
1. Call `eventsRepository.cancelRegistration(eventId, userId)`
2. Call `favoritesRepository.toggle(FavoriteEntity.event, eventId)` to remove favorite
3. Invalidate providers: `eventTeamsCountProvider`, `isUserRegisteredProvider`, `eventTeamsProvider`
4. Show success toast

Button styling: use `Colors.red` / destructive theme color to distinguish from the primary "立即报名" action.

### 3. i18n — `app_zh.arb` / `app_en.arb`

New keys following existing `event_register_*` naming:

| Key | zh | en |
|-----|----|----|
| `event_register_cancel` | 取消报名 | Cancel Registration |
| `event_register_cancel_confirm_title` | 取消报名 | Cancel Registration |
| `event_register_cancel_confirm_body` | 确定要取消报名吗？队伍和成员信息将被删除且无法恢复 | Are you sure? Your team and member data will be permanently deleted. |
| `event_register_cancel_success` | 已取消报名 | Registration cancelled |

### 4. Database Migration — `0017_teams_captain_write.sql`

The `teams` table currently has RLS enabled but only a `select` policy. A new migration adds `insert` and `delete` policies for the captain:

```sql
-- Allow authenticated users to insert teams where they are the captain
CREATE POLICY "teams captain insert"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (captain_id = auth.uid());

-- Allow captains to delete their own teams
CREATE POLICY "teams captain delete"
  ON public.teams FOR DELETE
  TO authenticated
  USING (captain_id = auth.uid());
```

Notes:
- `team_members` has `ON DELETE CASCADE` on `team_id` — members are cleaned up automatically
- `event_teams_count` view auto-reflects the deletion
- The `insert` policy also fixes the currently-missing RLS for team registration

## Edge Cases

| Case | Handling |
|------|----------|
| Event transitions out of `registering` while user is on the page | Button becomes disabled "已报名" on next provider refresh |
| Network failure during deletion | Standard error toast; no partial state since it's a single DELETE |
| User is the only team registered | Works the same — team count goes to 0 |
| Concurrent cancellation (double tap) | Second DELETE is a no-op (no matching row); toggle favorites is idempotent |

## Out of Scope

- Cancellation by non-captain team members (current model: only captain owns the registration)
- Notification to team members when captain cancels
- Cancellation cooldown or rate limiting
