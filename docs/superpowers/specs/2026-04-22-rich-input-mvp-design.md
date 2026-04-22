# Rich Input MVP Design

## Goal

Add emoji picker and image sending to chat/comment inputs across the app, via a shared `RichInput` widget.

## Scope

| Feature | In MVP | Rationale |
|---------|--------|-----------|
| Emoji picker | Yes (all 4 input areas) | Low cost, high UX lift |
| Image sending | Yes (DM + event chat only) | StorageService + Message.kind='image' already exist |
| Sticker packs | No | Needs content library + admin panel, low ROI for MVP |

## Architecture

### 1. Shared Widget: `RichInput`

**File**: `lib/widgets/rich_input.dart`

A composable input bar that replaces the scattered TextField + send button patterns across the app.

```dart
RichInput({
  required TextEditingController controller,
  required VoidCallback onSend,
  bool sending = false,
  bool showAttachments = false,     // show "+" button for image/location/invite
  VoidCallback? onPickImage,        // called when image attachment tapped
  VoidCallback? onPickLocation,     // called when location attachment tapped  
  VoidCallback? onInvite,           // called when invite attachment tapped
  String? hintText,
  int minLines = 1,
  int maxLines = 4,
})
```

**Internal layout:**

```
Chat mode (showAttachments=true):
┌──────────────────────────────────────────┐
│  [+]  [ text input          ]  [😀] [➤] │
├──────────────────────────────────────────┤
│  ┌──────────────────────────────────┐    │
│  │  Emoji picker panel (toggleable) │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘

Simple mode (showAttachments=false):
┌──────────────────────────────────────────┐
│  [ text input               ]  [😀] [➤] │
├──────────────────────────────────────────┤
│  (emoji panel when open)                 │
└──────────────────────────────────────────┘
```

**Emoji toggle behavior:**
- Tap 😀 when keyboard is open → dismiss keyboard, show emoji panel (same height as keyboard)
- Tap 😀 when emoji panel is open → dismiss panel, show keyboard
- Tap text field when emoji panel is open → dismiss panel, show keyboard
- Select emoji → insert at cursor position in text field
- Panel categories: Recent, Smileys, Animals, Food, Sports, etc.

### 2. Emoji Picker

**Package**: `emoji_picker_flutter` (most mature Flutter emoji picker)

**Integration points:**
- `RichInput` manages the toggle state internally
- Uses `MediaQuery.of(context).viewInsets.bottom` to match keyboard height
- Persists recently-used emojis via `SharedPreferences` (built into the package)

**Styling**: Match app theme tokens — `elev1` background, `ink` text color, `accent` for selected category indicator.

### 3. Image Messages (Chat only)

**Upload flow:**
1. User taps "+" → attachment sheet → "Image"
2. Call `StorageService.pickCropCompressAndUpload(bucket: 'chat-images', pathPrefix: convId, square: false)`
3. On success, call `MessagesRepository.send(convId, imageUrl, kind: 'image')`

**MessagesRepository.send changes:**
```dart
// Before:
Future<Message> send(String convId, String body) async { ... }

// After:
Future<Message> send(String convId, String body, {String kind = 'text'}) async {
  final row = await supabase.from('messages').insert({
    'conv_id': convId,
    'sender_id': currentUserId,
    'body': body,
    'kind': kind,   // <-- new
  }).select().single();
  return Message.fromMap(row);
}
```

**Bubble rendering:**
- `kind == 'image'` → render `CachedNetworkImage` with rounded corners, max width 200, placeholder shimmer
- Tap image → full-screen viewer (simple `Dialog` with `InteractiveViewer`)
- `kind == 'text'` → existing text bubble (unchanged)

### 4. Database / Storage

**No schema changes needed.** The `messages` table already has:
- `kind text DEFAULT 'text'` — supports 'text', 'image', 'system'
- `body text` — stores image URL for image messages

**New Supabase Storage bucket:** `chat-images` (public, same config as existing `avatars` bucket).

### 5. Integration Per Screen

#### DM Chat (`chat_screen.dart`)
- Replace bottom input bar (lines 336-415) with `RichInput(showAttachments: true, ...)`
- Move `_showAttachmentSheet` logic: image → actual upload, location/invite → keep placeholder
- Update `_Bubble` widget to handle `kind == 'image'`

#### Event Chat (`event_detail_screen.dart`)
- Replace `_ChatInput` build method with `RichInput(showAttachments: true, ...)`
- Update `_Msg` widget to handle `kind == 'image'`

#### Live Danmaku (`wc_live_screen.dart`)
- Replace bottom input bar with `RichInput(showAttachments: false, ...)`
- No image support needed

#### Post-Match Rating (`post_match_rating_screen.dart` + `rate_player_sheet.dart`)
- These use multi-line comment fields, not a chat bar
- Add an emoji button (😀) to the `InputDecoration.suffixIcon`
- Tapping it shows the same emoji panel below the text field
- Implementation: wrap the TextField + emoji panel in a Column, manage toggle state locally

### 6. File Changes Summary

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `emoji_picker_flutter` dependency |
| `lib/widgets/rich_input.dart` | **New** — shared input widget with emoji panel |
| `lib/repositories/messages_repository.dart` | Add `kind` param to `send()` |
| `lib/features/messages/chat_screen.dart` | Use `RichInput`, update bubble for images |
| `lib/features/events/event_detail_screen.dart` | Use `RichInput` in `_ChatInput`, update `_Msg` for images |
| `lib/features/events/wc_live_screen.dart` | Use `RichInput` (no image) |
| `lib/features/rating/post_match_rating_screen.dart` | Add emoji button + panel to comment field |
| `lib/features/rating/widgets/rate_player_sheet.dart` | Add emoji button + panel to comment field |

### 7. Out of Scope

- Sticker packs / GIF search
- @mentions / #hashtags
- Rich text formatting (bold, italic)
- Link previews
- Video messages
- Voice messages
- Location sharing (keep placeholder)
- Game invite sharing (keep placeholder)
