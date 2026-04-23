# Delete Account Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fake account deletion (sign-out only) with a real Supabase Edge Function that anonymizes preserved data and deletes the auth user.

**Architecture:** A new `delete-account` Edge Function authenticates via JWT, anonymizes articles/goals/feedback rows, then calls `auth.admin.deleteUser()` which cascade-deletes all other user data. The Flutter client replaces the simple AlertDialog with a bottom sheet requiring typed confirmation ("注销账号" / "DELETE" based on locale).

**Tech Stack:** Deno (Edge Function), Supabase JS SDK v2, Flutter, go_router, shared_preferences

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `supabase/functions/delete-account/index.ts` | Edge Function: JWT auth → anonymize → delete user |
| Modify | `lib/l10n/app_zh.arb` (lines 526-528) | Add 3 new i18n keys for delete confirmation UI |
| Modify | `lib/l10n/app_en.arb` (lines 526-528) | Add 3 new i18n keys for delete confirmation UI |
| Modify | `lib/l10n/generated/app_localizations.dart` | Regenerate: add abstract getters |
| Modify | `lib/l10n/generated/app_localizations_zh.dart` | Regenerate: add zh implementations |
| Modify | `lib/l10n/generated/app_localizations_en.dart` | Regenerate: add en implementations |
| Modify | `lib/services/local_storage.dart` | Add `LocalStore.clearAll()` static method |
| Modify | `lib/features/settings/account_settings_screen.dart` (lines 375-413) | Replace `_deleteAccount` with bottom sheet + Edge Function call |

---

### Task 1: Create the Edge Function

**Files:**
- Create: `supabase/functions/delete-account/index.ts`

- [ ] **Step 1: Create the Edge Function file**

```ts
// delete-account — Permanently delete the authenticated user's account.
//
// POST /functions/v1/delete-account
// Authorization: Bearer <supabase-jwt>
// Body: (none)
// Response: { "success": true } | { "error": "..." }
//
// Deploy:
//   supabase functions deploy delete-account

// @ts-expect-error: Deno URL import
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
// @ts-expect-error: Deno URL import
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// deno-lint-ignore no-explicit-any
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supaAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

async function handler(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  // 1. Authenticate caller
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "missing auth" }, 401);

  const jwt = authHeader.replace("Bearer ", "");
  const {
    data: { user },
    error: authError,
  } = await supaAdmin.auth.getUser(jwt);
  if (authError || !user) return json({ error: "invalid token" }, 401);

  const uid = user.id;

  // 2. Anonymize preserved records
  const anonymize = [
    supaAdmin.from("articles").update({ author_id: null }).eq("author_id", uid),
    supaAdmin.from("goals").update({ scorer_id: null }).eq("scorer_id", uid),
    supaAdmin.from("goals").update({ assist_id: null }).eq("assist_id", uid),
    supaAdmin.from("feedback").update({ user_id: null }).eq("user_id", uid),
  ];
  const results = await Promise.all(anonymize);
  for (const r of results) {
    if (r.error) {
      console.error("[delete-account] anonymize failed:", r.error);
      return json({ error: "failed to anonymize data" }, 500);
    }
  }

  // 3. Delete auth user (cascades profiles + all ON DELETE CASCADE rows)
  const { error: deleteError } = await supaAdmin.auth.admin.deleteUser(uid);
  if (deleteError) {
    console.error("[delete-account] deleteUser failed:", deleteError);
    return json({ error: "failed to delete user" }, 500);
  }

  return json({ success: true });
}

serve(handler);
```

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/delete-account/index.ts
git commit -m "feat(edge): add delete-account function"
```

---

### Task 2: Add i18n keys

**Files:**
- Modify: `lib/l10n/app_zh.arb` (after line 528)
- Modify: `lib/l10n/app_en.arb` (after line 528)

- [ ] **Step 1: Add Chinese i18n keys**

In `lib/l10n/app_zh.arb`, replace the existing block (lines 526-528):

```
  "settings_account_delete": "注销账号",
  "settings_account_delete_confirm": "注销后所有数据将不可恢复，是否继续？",
  "settings_account_delete_done": "账号已注销",
```

with:

```
  "settings_account_delete": "注销账号",
  "settings_account_delete_confirm": "注销后所有数据将不可恢复，是否继续？",
  "settings_account_delete_done": "账号已注销",
  "settings_account_delete_warning": "注销后所有数据将被永久删除，此操作不可撤销。",
  "settings_account_delete_input_hint": "请输入「注销账号」以确认",
  "settings_account_delete_confirm_word": "注销账号",
```

- [ ] **Step 2: Add English i18n keys**

In `lib/l10n/app_en.arb`, replace the existing block (lines 526-528):

```
  "settings_account_delete": "Delete account",
  "settings_account_delete_confirm": "Your data will be permanently removed. Continue?",
  "settings_account_delete_done": "Account deleted",
```

with:

```
  "settings_account_delete": "Delete account",
  "settings_account_delete_confirm": "Your data will be permanently removed. Continue?",
  "settings_account_delete_done": "Account deleted",
  "settings_account_delete_warning": "All your data will be permanently deleted. This action cannot be undone.",
  "settings_account_delete_input_hint": "Type DELETE to confirm",
  "settings_account_delete_confirm_word": "DELETE",
```

- [ ] **Step 3: Regenerate l10n**

Run:
```bash
flutter gen-l10n
```

This updates `lib/l10n/generated/app_localizations.dart`, `app_localizations_zh.dart`, and `app_localizations_en.dart` with the 3 new getters:
- `settings_account_delete_warning`
- `settings_account_delete_input_hint`
- `settings_account_delete_confirm_word`

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add delete-account confirmation strings"
```

---

### Task 3: Add `LocalStore.clearAll()`

**Files:**
- Modify: `lib/services/local_storage.dart`

- [ ] **Step 1: Add the clearAll method**

Add the following static method to `LocalStore` class, after the `setRemember` method (after line 281):

```dart
  static Future<void> clearAll() async {
    await _prefs.clear();
    localStoreNotifier.bump();
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/local_storage.dart
git commit -m "feat(storage): add LocalStore.clearAll for account deletion"
```

---

### Task 4: Replace `_deleteAccount` in account settings

**Files:**
- Modify: `lib/features/settings/account_settings_screen.dart` (lines 375-413)

- [ ] **Step 1: Add dart:convert import**

At the top of `account_settings_screen.dart`, add this import (after line 3, the `go_router` import):

```dart
import 'dart:convert';
```

- [ ] **Step 2: Replace the `_deleteAccount` method**

Replace the entire `_deleteAccount` method (lines 375-413) with:

```dart
  Future<void> _deleteAccount(BuildContext context) async {
    final l = context.l10n;
    final confirmWord = l.settings_account_delete_confirm_word;
    final controller = TextEditingController();

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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: _DeleteAccountSheet(
            confirmWord: confirmWord,
            controller: controller,
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Add the `_DeleteAccountSheet` StatefulWidget**

Add the following widget class at the bottom of the file, before the closing of the file (after the `_PwField` widget, after line 452):

```dart
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  final String confirmWord;
  final TextEditingController controller;
  const _DeleteAccountSheet({
    required this.confirmWord,
    required this.controller,
  });

  @override
  ConsumerState<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  bool _loading = false;

  bool get _matched =>
      widget.controller.text.trim() == widget.confirmWord;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  Future<void> _submit() async {
    if (!_matched || _loading) return;
    setState(() => _loading = true);
    try {
      final res = await supabase.functions.invoke('delete-account');
      final body = res.data is String ? jsonDecode(res.data as String) : res.data;
      if (body is Map && body['error'] != null) {
        if (mounted) {
          showToast(context, '${body['error']}', error: true);
          setState(() => _loading = false);
        }
        return;
      }
      await LocalStore.clearAll();
      if (mounted) {
        final l = context.l10n;
        showToast(context, l.settings_account_delete_done, success: true);
        context.go('/sign-in');
      }
    } catch (e) {
      if (mounted) {
        showToast(context, '$e', error: true);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.settings_account_delete,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l.settings_account_delete_warning,
          style: TextStyle(
            fontSize: 13,
            color: context.tokens.danger,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.settings_account_delete_input_hint,
          style: TextStyle(
            fontSize: 13,
            color: context.tokens.inkSub,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.tokens.elev2,
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(context.tokens.r2),
          ),
          child: TextField(
            controller: widget.controller,
            enabled: !_loading,
            style: TextStyle(color: context.tokens.ink, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : PrimaryButton(
                label: l.settings_account_delete,
                variant: BtnVariant.warn,
                size: BtnSize.lg,
                full: true,
                disabled: !_matched,
                onPressed: _matched ? _submit : null,
              ),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify the build compiles**

Run:
```bash
flutter analyze lib/features/settings/account_settings_screen.dart
```

Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/account_settings_screen.dart
git commit -m "feat(settings): implement real account deletion with confirmation"
```
