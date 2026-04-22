# DM Chat Enhancement Design

## Summary

Improve the 1v1 DM chat experience in `ChatScreen`: fix the title flash, upgrade the header, clean up the menu, add empty-state guidance, and support long-press copy on message bubbles.

## Problem

1. Navigating to a DM chat briefly flashes "开球 · 新手大厅" as the title because `conversationByIdProvider` depends on a lazy-loaded `conversationsProvider`.
2. The "查看成员" (view members) menu item is shown in DM chats where it has no purpose.
3. The DM header is identical to group chat — no avatar, no way to view the peer's profile.
4. First-time DM shows an empty white screen with no context about who you're talking to.
5. Messages cannot be copied via long press.

## Design

### 1. Fix Title Flash

**File:** `lib/features/messages/chat_screen.dart` (lines 200-207)

Replace the current title logic:

```dart
// Before: falls back to chat_default_group_title while loading
title = peer?.name ?? context.l10n.chat_default_group_title;

// After: distinguish loading from loaded-but-empty
if (conv == null) {
  title = '…';  // conversations list still loading
} else if (conv.kind == 'dm') {
  final peerAsync = ref.watch(dmPeerProfileProvider(widget.convId));
  title = peerAsync.when(
    data: (p) => p?.name ?? '…',
    loading: () => '…',
    error: (_, __) => '…',
  );
} else {
  title = conv.title ?? context.l10n.chat_default_group_title;
}
```

`chat_default_group_title` is now only used for group chats with no explicit title.

### 2. DM Header Upgrade

**File:** `lib/features/messages/chat_screen.dart` — header Row

When `conv?.kind == 'dm'` and we have a resolved peer profile:

- Insert `Avatar(peerName, size: 28)` + `SizedBox(width: 8)` before the title text
- Wrap avatar + title in a `GestureDetector` that calls `showUserCardSheet(context, ref, userId: peerId)`
- `peerId` comes from `dmPeerProfileProvider` — when loading or null, skip the avatar and show only `'…'`
- Group chats: no change

Reuses existing `Avatar` and `showUserCardSheet` components.

### 3. Hide "View Members" in DM

**File:** `lib/features/messages/chat_screen.dart` — `_showMoreMenu()`

Read `conv?.kind` from the widget state. Only render the "查看成员" `ListTile` when `kind != 'dm'`.

### 4. Empty Chat Guidance (DM only)

**File:** `lib/features/messages/chat_screen.dart` — message list area

When `conv?.kind == 'dm'` and `list.isEmpty`:

```
┌──────────────────────────────┐
│                              │
│         [72px Avatar]        │
│           张三                │
│       CM · 北京 · 朝阳       │
│                              │
│     你们还没聊过，打个招呼吧   │
│                              │
└──────────────────────────────┘
```

- Centered in the `Expanded` message area
- Avatar: `Avatar(profile.name, size: 72)` from `dmPeerProfileProvider`
- Meta line: position · city · district (same logic as `UserCardSheet`)
- Hint text in `inkDim` color
- While peer profile is loading, show a small `CircularProgressIndicator`
- Group chats or non-empty lists: render the normal `ListView`

**New l10n keys:**

| Key | EN | ZH |
|-----|----|----|
| `chat_dm_empty_title` | Haven't chatted yet | 你们还没聊过 |
| `chat_dm_empty_subtitle` | Say hello! | 打个招呼吧 |

### 5. Long-Press Copy on Bubbles

**File:** `lib/features/messages/chat_screen.dart` — `_Bubble`

Wrap text bubbles in a `GestureDetector` with `onLongPress` that copies `msg.body` to clipboard and shows a brief toast. Image bubbles: copy the image URL on long press.

Uses `Clipboard.setData` from `flutter/services.dart`.

**New l10n key:**

| Key | EN | ZH |
|-----|----|----|
| `chat_copied` | Copied | 已复制 |

## Files Changed

| File | Change |
|------|--------|
| `lib/features/messages/chat_screen.dart` | All 5 changes above |
| `lib/l10n/app_en.arb` | Add 3 new keys |
| `lib/l10n/app_zh.arb` | Add 3 new keys |

## Out of Scope

- Read receipts, message recall, emoji reactions (future work, needs schema changes)
- Group chat header changes
- New routes or screens
