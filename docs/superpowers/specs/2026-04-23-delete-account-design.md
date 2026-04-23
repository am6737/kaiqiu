# Delete Account — Design Spec

## Overview

Implement real account deletion. Currently the "delete account" button only signs the user out. This spec replaces that with a Supabase Edge Function that anonymizes preserved data and deletes the auth user, triggering cascade deletion of all associated records.

## Requirements

- No cooldown period — deletion is immediate upon confirmation.
- User must type a confirmation word before the button becomes active: "注销账号" (zh) / "DELETE" (en), determined by the app's current locale.
- Articles, goals, and feedback are anonymized (author/user set to null) and preserved; all other user data is cascade-deleted.

## Edge Function: `delete-account`

**Path:** `supabase/functions/delete-account/index.ts`

**Auth:** Extracts the caller's identity from the `Authorization: Bearer <JWT>` header. The function can only delete the authenticated user's own account.

**Steps (in order):**

1. Parse JWT from request header; create an anon Supabase client and call `auth.getUser(token)` to obtain `user.id`. Return 401 if invalid.
2. Create a service-role Supabase client.
3. Anonymize preserved records (all in one transaction-like sequence):
   - `UPDATE articles SET author_id = NULL WHERE author_id = user.id`
   - `UPDATE goals SET scorer_id = NULL WHERE scorer_id = user.id`
   - `UPDATE goals SET assist_id = NULL WHERE assist_id = user.id`
   - `UPDATE feedback SET user_id = NULL WHERE user_id = user.id`
4. Call `auth.admin.deleteUser(user.id)` — this cascade-deletes the `profiles` row and all tables with `ON DELETE CASCADE` referencing profiles or auth.users.
5. Return `{ success: true }` on success, or `{ error: message }` with appropriate HTTP status on failure.

**Cascade-deleted data (no explicit handling needed):**

profiles, posts, pickups, pickup_slots, ratings, rating_likes, comments, events, teams, user_teams, user_team_members, match_participants, conversation_members, messages, notifications, predictions, match_reminders, favorites, push_subscriptions, player_attributes, player_honors, likes, venues, venue_bookings.

## Client Changes

**File:** `lib/features/settings/account_settings_screen.dart`

Replace the current `_deleteAccount` method:

1. Show a modal bottom sheet (not an AlertDialog) containing:
   - Warning text explaining that deletion is permanent and irreversible.
   - A text field prompting the user to type the locale-specific confirmation word.
   - A confirm button that is disabled until the input matches the confirmation word exactly.
2. On confirm:
   - Show a loading indicator.
   - Call `supabase.functions.invoke('delete-account')`.
   - On success: clear local storage, show success toast, navigate to login/onboarding.
   - On failure: show error toast with the returned message.

## Internationalization

New keys added to `app_zh.arb` and `app_en.arb`:

| Key | zh | en |
|-----|----|----|
| `settings_account_delete_warning` | 注销后所有数据将被永久删除，此操作不可撤销。 | All your data will be permanently deleted. This action cannot be undone. |
| `settings_account_delete_input_hint` | 请输入「注销账号」以确认 | Type DELETE to confirm |
| `settings_account_delete_confirm_word` | 注销账号 | DELETE |

## Out of Scope

- Displaying "已注销用户" in article/goal UIs when author is null — this is a presentation concern to be handled separately.
- Cooldown / soft-delete period.
- Email notification to the user upon deletion.
