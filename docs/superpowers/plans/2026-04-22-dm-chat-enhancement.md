# DM Chat Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve the 1v1 DM chat experience — fix title flash, upgrade header with avatar, hide irrelevant menu items, add empty-state guidance, and enable long-press copy.

**Architecture:** All changes are in `chat_screen.dart` plus 3 new l10n keys. No new files, routes, or schema changes. Reuses existing `Avatar`, `showUserCardSheet`, and `dmPeerProfileProvider`.

**Tech Stack:** Flutter, Riverpod, go_router, Supabase (existing providers only)

---

### Task 1: Add l10n Keys

**Files:**
- Modify: `lib/l10n/app_en.arb:410` (after `chat_cleared`)
- Modify: `lib/l10n/app_zh.arb:410` (after `chat_cleared`)

- [ ] **Step 1: Add keys to app_en.arb**

Insert after the `"chat_cleared": "Cleared",` line (line 410):

```json
  "chat_dm_empty_title": "Haven't chatted yet",
  "chat_dm_empty_subtitle": "Say hello!",
  "chat_copied": "Copied",
```

- [ ] **Step 2: Add keys to app_zh.arb**

Insert after the `"chat_cleared": "已清空",` line (line 410):

```json
  "chat_dm_empty_title": "你们还没聊过",
  "chat_dm_empty_subtitle": "打个招呼吧",
  "chat_copied": "已复制",
```

- [ ] **Step 3: Run code generation**

Run: `cd /home/coder/workspaces/qiuju_app && /home/coder/flutter/bin/flutter gen-l10n`
Expected: Succeeds with no errors. `app_localizations_en.dart` and `app_localizations_zh.dart` are regenerated with the new getters.

- [ ] **Step 4: Verify new keys compile**

Run: `/home/coder/flutter/bin/dart analyze lib/l10n/`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/
git commit -m "feat(l10n): add DM empty-state and copy l10n keys"
```

---

### Task 2: Fix Title Flash

**Files:**
- Modify: `lib/features/messages/chat_screen.dart:196-207` (inside `build()`)

The current title logic (lines 200-207) falls back to `chat_default_group_title` while the conversation list loads. Replace it to show `'…'` during loading.

- [ ] **Step 1: Replace title resolution logic**

In `lib/features/messages/chat_screen.dart`, replace lines 200-207:

```dart
    final conv = ref.watch(conversationByIdProvider(widget.convId));
    String title;
    if (conv?.kind == 'dm') {
      final peer = ref.watch(dmPeerProfileProvider(widget.convId)).valueOrNull;
      title = peer?.name ?? context.l10n.chat_default_group_title;
    } else {
      title = conv?.title ?? context.l10n.chat_default_group_title;
    }
```

With:

```dart
    final conv = ref.watch(conversationByIdProvider(widget.convId));
    final isDm = conv?.kind == 'dm';
    final peerAsync = isDm
        ? ref.watch(dmPeerProfileProvider(widget.convId))
        : const AsyncValue<Profile?>.data(null);
    final peerProfile = peerAsync.valueOrNull;

    String title;
    if (conv == null) {
      title = '…';
    } else if (isDm) {
      title = peerAsync.when(
        data: (p) => p?.name ?? '…',
        loading: () => '…',
        error: (_, __) => '…',
      );
    } else {
      title = conv.title ?? context.l10n.chat_default_group_title;
    }
```

This also requires adding the Profile import. Add at the top of the file:

```dart
import '../../models/profile.dart';
```

- [ ] **Step 2: Verify it compiles**

Run: `/home/coder/flutter/bin/dart analyze lib/features/messages/chat_screen.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "fix(chat): show placeholder instead of default title while loading"
```

---

### Task 3: DM Header Upgrade

**Files:**
- Modify: `lib/features/messages/chat_screen.dart:222-260` (header Container)

Add an import for `showUserCardSheet` and `Avatar` (Avatar is already imported), then upgrade the header Row to show the peer's avatar in DM mode, tappable to open the user card sheet.

- [ ] **Step 1: Add import for showUserCardSheet**

At the top of `lib/features/messages/chat_screen.dart`, add:

```dart
import '../../widgets/user_card_sheet.dart';
```

- [ ] **Step 2: Replace the header title area**

In the header Row (inside the `Container` with `padding: const EdgeInsets.fromLTRB(16, 8, 16, 10)`), replace the `Expanded` widget that shows the title text (the section between the back button and the more button):

Replace:

```dart
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.ink,
                      ),
                    ),
                  ),
```

With:

```dart
                  Expanded(
                    child: GestureDetector(
                      onTap: isDm && peerProfile != null
                          ? () => showUserCardSheet(context, ref, userId: peerProfile.id)
                          : null,
                      child: Row(
                        children: [
                          if (isDm && peerProfile != null) ...[
                            Avatar(peerProfile.name, size: 28),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.tokens.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
```

- [ ] **Step 3: Verify it compiles**

Run: `/home/coder/flutter/bin/dart analyze lib/features/messages/chat_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "feat(chat): show peer avatar in DM header with tap-to-view profile"
```

---

### Task 4: Hide "View Members" in DM

**Files:**
- Modify: `lib/features/messages/chat_screen.dart:54-168` (`_showMoreMenu()`)

The `conv` variable is already available in `build()` but `_showMoreMenu` is a method on `_ChatScreenState`. We need to pass the conversation kind or read it inside the method.

- [ ] **Step 1: Pass isDm into _showMoreMenu**

Change the method signature and the call site.

Change the method from:

```dart
  Future<void> _showMoreMenu() async {
```

To:

```dart
  Future<void> _showMoreMenu({required bool isDm}) async {
```

Then wrap the "查看成员" ListTile (the first ListTile in the Column, lines 77-86) in a condition:

Replace:

```dart
            ListTile(
              leading: Icon(Icons.people_outline, color: context.tokens.inkSub),
              title: Text(
                l.chat_more_members,
                style: TextStyle(color: context.tokens.ink),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                showToast(context, l.chat_more_members);
              },
            ),
```

With:

```dart
            if (!isDm)
              ListTile(
                leading: Icon(Icons.people_outline, color: context.tokens.inkSub),
                title: Text(
                  l.chat_more_members,
                  style: TextStyle(color: context.tokens.ink),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showToast(context, l.chat_more_members);
                },
              ),
```

- [ ] **Step 2: Update the call site**

In the `build()` method, find the `GestureDetector` that calls `_showMoreMenu` (around line 251):

Replace:

```dart
                  GestureDetector(
                    onTap: _showMoreMenu,
```

With:

```dart
                  GestureDetector(
                    onTap: () => _showMoreMenu(isDm: isDm),
```

- [ ] **Step 3: Verify it compiles**

Run: `/home/coder/flutter/bin/dart analyze lib/features/messages/chat_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "fix(chat): hide view-members option in DM conversations"
```

---

### Task 5: Empty Chat Guidance

**Files:**
- Modify: `lib/features/messages/chat_screen.dart:261-285` (message list Expanded area)

When the conversation is a DM and the message list is empty, show a centered card with the peer's avatar, name, meta info, and a hint instead of an empty ListView.

- [ ] **Step 1: Replace the message list area**

In the `build()` method, find the `Expanded` widget that shows `messagesAsync.when(...)` (around line 261). Replace:

```dart
            Expanded(
              child: messagesAsync.when(
                data: (list) => ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _Bubble(msg: list[i], isMe: list[i].senderId == me),
                ),
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.tokens.accent,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '${context.l10n.error_load_failed}: $e',
                    style: TextStyle(color: context.tokens.inkSub),
                  ),
                ),
              ),
            ),
```

With:

```dart
            Expanded(
              child: messagesAsync.when(
                data: (list) {
                  if (isDm && list.isEmpty) {
                    return _DmEmptyState(peerAsync: peerAsync);
                  }
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) =>
                        _Bubble(msg: list[i], isMe: list[i].senderId == me),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: context.tokens.accent,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    '${context.l10n.error_load_failed}: $e',
                    style: TextStyle(color: context.tokens.inkSub),
                  ),
                ),
              ),
            ),
```

- [ ] **Step 2: Add the _DmEmptyState widget**

Add this widget class at the bottom of `chat_screen.dart`, before the closing of the file (after the `_Bubble` class):

```dart
class _DmEmptyState extends StatelessWidget {
  final AsyncValue<Profile?> peerAsync;
  const _DmEmptyState({required this.peerAsync});

  @override
  Widget build(BuildContext context) {
    return peerAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(
          color: context.tokens.accent,
          strokeWidth: 2,
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        final metaParts = [
          if ((profile.position ?? '').isNotEmpty) profile.position!,
          if ((profile.city ?? '').isNotEmpty) profile.city!,
          if ((profile.district ?? '').isNotEmpty) profile.district!,
        ];
        final metaLine = metaParts.isNotEmpty ? metaParts.join(' · ') : null;

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(profile.name, size: 72),
                const SizedBox(height: 12),
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.ink,
                  ),
                ),
                if (metaLine != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    metaLine,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.inkDim,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.chat_dm_empty_title,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.tokens.inkSub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.chat_dm_empty_subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.inkDim,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `/home/coder/flutter/bin/dart analyze lib/features/messages/chat_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "feat(chat): add DM empty-state with peer profile card"
```

---

### Task 6: Long-Press Copy on Bubbles

**Files:**
- Modify: `lib/features/messages/chat_screen.dart` — `_Bubble` class

Add a `flutter/services.dart` import for `Clipboard`, then wrap both text and image bubbles with `onLongPress` to copy content.

- [ ] **Step 1: Add import**

At the top of `lib/features/messages/chat_screen.dart`, add:

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 2: Wrap text bubble with long-press copy**

In the `_Bubble` class `build()` method, find the text bubble `Container` (the `else` branch, around line 369-385). Replace:

```dart
    } else {
      bubble = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isMe ? context.tokens.accent : context.tokens.elev2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          msg.body ?? '',
          style: TextStyle(
            fontSize: 14,
            color: isMe ? Colors.black : context.tokens.ink,
            height: 1.4,
          ),
        ),
      );
    }
```

With:

```dart
    } else {
      bubble = GestureDetector(
        onLongPress: () {
          if (msg.body != null) {
            Clipboard.setData(ClipboardData(text: msg.body!));
            showToast(context, context.l10n.chat_copied, success: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isMe ? context.tokens.accent : context.tokens.elev2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            msg.body ?? '',
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.black : context.tokens.ink,
              height: 1.4,
            ),
          ),
        ),
      );
    }
```

- [ ] **Step 3: Add long-press copy to image bubble**

In the `_Bubble` class, find the image bubble (the `if (msg.kind == 'image' ...)` branch, around line 337). The image is already wrapped in a `GestureDetector` with `onTap`. Add `onLongPress` to it.

Replace:

```dart
      bubble = GestureDetector(
        onTap: () => _showFullImage(context, msg.body!),
        child: ClipRRect(
```

With:

```dart
      bubble = GestureDetector(
        onTap: () => _showFullImage(context, msg.body!),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: msg.body!));
          showToast(context, context.l10n.chat_copied, success: true);
        },
        child: ClipRRect(
```

- [ ] **Step 4: Verify it compiles**

Run: `/home/coder/flutter/bin/dart analyze lib/features/messages/chat_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "feat(chat): add long-press copy for text and image bubbles"
```

---

### Task 7: Final Verification

- [ ] **Step 1: Full project analysis**

Run: `/home/coder/flutter/bin/dart analyze lib/`
Expected: No issues found (or only pre-existing warnings unrelated to our changes).

- [ ] **Step 2: Verify all l10n keys resolve**

Run: `/home/coder/flutter/bin/flutter gen-l10n`
Expected: Succeeds with no errors.
