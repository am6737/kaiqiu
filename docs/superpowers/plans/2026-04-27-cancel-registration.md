# Cancel Event Registration (取消报名) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to cancel their event registration while the event is still in `registering` status.

**Architecture:** Add a `cancelRegistration` method to `EventsRepository`, update `BottomCta` to show a destructive "取消报名" button when `registered && registering`, and add a Supabase migration for missing RLS write policies on the `teams` table.

**Tech Stack:** Flutter, Riverpod, Supabase (PostgreSQL RLS), flutter gen-l10n

---

### Task 1: Database Migration — RLS policies for `teams` table

**Files:**
- Create: `supabase/migrations/0017_teams_captain_write.sql`

- [ ] **Step 1: Create the migration file**

```sql
-- 0017_teams_captain_write.sql
-- Add missing insert/delete RLS policies for the teams table.
-- insert: fixes the currently-unprotected team registration.
-- delete: enables cancel-registration feature.

CREATE POLICY "teams captain insert"
  ON public.teams FOR INSERT
  TO authenticated
  WITH CHECK (captain_id = auth.uid());

CREATE POLICY "teams captain delete"
  ON public.teams FOR DELETE
  TO authenticated
  USING (captain_id = auth.uid());
```

- [ ] **Step 2: Verify migration is syntactically valid**

Run: `cd /home/coder/workspaces/qiuju_app && grep -c 'CREATE POLICY' supabase/migrations/0017_teams_captain_write.sql`
Expected: `2`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0017_teams_captain_write.sql
git commit -m "feat(db): add insert/delete RLS policies for teams table"
```

---

### Task 2: Repository — add `cancelRegistration` method

**Files:**
- Modify: `lib/repositories/events_repository.dart` (after `isUserRegistered` method, ~line 270)

- [ ] **Step 1: Add `cancelRegistration` to `EventsRepository`**

In `lib/repositories/events_repository.dart`, add this method after the `isUserRegistered` method (after line 270):

```dart
  Future<void> cancelRegistration(String eventId, String userId) async {
    await supabase
        .from('teams')
        .delete()
        .eq('event_id', eventId)
        .eq('captain_id', userId);
  }
```

- [ ] **Step 2: Verify no syntax errors**

Run: `cd /home/coder/workspaces/qiuju_app && /home/coder/flutter/bin/flutter analyze lib/repositories/events_repository.dart 2>&1 | tail -5`
Expected: No errors (warnings about other files are OK)

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/events_repository.dart
git commit -m "feat(repo): add cancelRegistration method to EventsRepository"
```

---

### Task 3: i18n — add cancel registration strings

**Files:**
- Modify: `lib/l10n/app_zh.arb` (line 1129 — before closing `}`)
- Modify: `lib/l10n/app_en.arb` (line 1129 — before closing `}`)

- [ ] **Step 1: Add keys to `app_zh.arb`**

Change the last line before the closing `}` from:

```json
  "common_publish": "发布"
}
```

to:

```json
  "common_publish": "发布",
  "event_register_cancel": "取消报名",
  "event_register_cancel_confirm_title": "取消报名",
  "event_register_cancel_confirm_body": "确定要取消报名吗？队伍和成员信息将被删除且无法恢复",
  "event_register_cancel_success": "已取消报名"
}
```

- [ ] **Step 2: Add keys to `app_en.arb`**

Change the last line before the closing `}` from:

```json
  "common_publish": "Publish"
}
```

to:

```json
  "common_publish": "Publish",
  "event_register_cancel": "Cancel Registration",
  "event_register_cancel_confirm_title": "Cancel Registration",
  "event_register_cancel_confirm_body": "Are you sure? Your team and member data will be permanently deleted.",
  "event_register_cancel_success": "Registration cancelled"
}
```

- [ ] **Step 3: Regenerate l10n code**

Run: `cd /home/coder/workspaces/qiuju_app && /home/coder/flutter/bin/flutter gen-l10n`
Expected: No errors. Generated files in `lib/l10n/generated/` are updated.

- [ ] **Step 4: Verify the new getters exist**

Run: `grep -c 'event_register_cancel' /home/coder/workspaces/qiuju_app/lib/l10n/generated/app_localizations.dart`
Expected: `8` (4 keys × 2 lines each: comment + getter)

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(i18n): add cancel registration strings"
```

---

### Task 4: UI — update `BottomCta` to support cancel registration

**Files:**
- Modify: `lib/features/events/widgets/bottom_cta.dart`

- [ ] **Step 1: Update the disabled-reason logic in `build()` method**

In `lib/features/events/widgets/bottom_cta.dart`, replace lines 32-41 (the `disabledReason` block):

Old code:
```dart
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
```

New code:
```dart
    String? disabledReason;
    if (registered && !isRegistering) {
      disabledReason = l.event_already_registered;
    } else if (!registered && !isRegistering) {
      disabledReason = l.event_registration_closed;
    } else if (!registered && isFull) {
      disabledReason = l.event_registration_full;
    } else if (!registered && deadlinePassed) {
      disabledReason = l.event_registration_deadline_passed;
    }
```

The key change: when `registered && isRegistering`, `disabledReason` stays `null` — this case is now handled by the cancel button in `_buildRightButton`.

- [ ] **Step 2: Update `_buildRightButton` to show cancel button**

In `_buildRightButton`, replace the `if (isRegistering)` block at lines 161-173:

Old code:
```dart
    if (isRegistering) {
      return PrimaryButton(
        label: disabledReason ?? l.event_cta_register,
        variant: disabledReason != null ? BtnVariant.secondary : BtnVariant.primary,
        size: BtnSize.lg,
        full: true,
        onPressed: disabledReason != null
            ? null
            : () => showRegisterSheet(context, ref),
      );
    }

    return null;
```

New code:
```dart
    final canCancel = registered && isRegistering;

    if (canCancel) {
      return PrimaryButton(
        label: l.event_register_cancel,
        variant: BtnVariant.warn,
        size: BtnSize.lg,
        full: true,
        onPressed: () => _showCancelConfirmation(context, ref),
      );
    }

    if (isRegistering) {
      return PrimaryButton(
        label: disabledReason ?? l.event_cta_register,
        variant: disabledReason != null ? BtnVariant.secondary : BtnVariant.primary,
        size: BtnSize.lg,
        full: true,
        onPressed: disabledReason != null
            ? null
            : () => showRegisterSheet(context, ref),
      );
    }

    return null;
```

- [ ] **Step 3: Add the `_showCancelConfirmation` method**

Add this method to the `BottomCta` class, after `showRegisterSheet`:

```dart
  Future<void> _showCancelConfirmation(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_register_cancel_confirm_title),
        content: Text(l.event_register_cancel_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.common_confirm,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final uid = currentUserId;
      if (uid == null) return;
      await ref.read(eventsRepoProvider).cancelRegistration(event.id, uid);
      await ref.read(favoritesRepoProvider).toggle(FavoriteEntity.event, event.id);
      ref.invalidate(eventTeamsCountProvider(event.id));
      ref.invalidate(isUserRegisteredProvider(event.id));
      ref.invalidate(eventTeamsProvider(event.id));
      if (context.mounted) {
        showToast(context, l.event_register_cancel_success, success: true);
      }
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
```

- [ ] **Step 4: Verify no analysis errors**

Run: `cd /home/coder/workspaces/qiuju_app && /home/coder/flutter/bin/flutter analyze lib/features/events/widgets/bottom_cta.dart 2>&1 | tail -5`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/events/widgets/bottom_cta.dart
git commit -m "feat(ui): add cancel registration button to BottomCta"
```

---

### Task 5: Manual Smoke Test

- [ ] **Step 1: Start the dev server**

Run: `cd /home/coder/workspaces/qiuju_app && /home/coder/flutter/bin/flutter run -d chrome --web-port=8080`

- [ ] **Step 2: Test the happy path**

1. Open an event in `registering` status
2. Register a team (confirm the flow still works)
3. After registration, verify the bottom CTA shows "取消报名" in warn style
4. Tap "取消报名" → confirm dialog appears with correct text
5. Tap confirm → team is deleted, toast shows "已取消报名"
6. Button reverts to "立即报名", team count decrements

- [ ] **Step 3: Test edge cases**

1. Open an event in `scheduling`/`ongoing` status where you are registered → button should show "已报名" (disabled), NOT "取消报名"
2. Open an event in `registering` where you are NOT registered → button should show "立即报名"
3. As event creator, button should show creator-specific controls (not affected)

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -u
git commit -m "fix: address smoke test findings for cancel registration"
```
