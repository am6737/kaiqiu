# Rich Input MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add emoji picker and image sending to chat/comment input fields via a shared `RichInput` widget.

**Architecture:** A new `RichInput` widget encapsulates the text field + emoji toggle + optional attachment button + send button. Emoji panel uses `emoji_picker_flutter` package. Image messages reuse existing `StorageService` and store the URL in `messages.body` with `kind='image'`. The widget is integrated into 4 screens: DM chat, event chat, live danmaku, and post-match rating.

**Tech Stack:** Flutter, emoji_picker_flutter, cached_network_image (already in project), Supabase Storage, Riverpod

---

## Task 1: Add `emoji_picker_flutter` dependency

**Files:**
- Modify: `pubspec.yaml:36` (after the Images section)

- [ ] **Step 1: Add dependency to pubspec.yaml**

In `pubspec.yaml`, after the `cached_network_image` line (line 36), add:

```yaml
  # Emoji picker (rich input MVP)
  emoji_picker_flutter: ^4.3.0
```

- [ ] **Step 2: Install the dependency**

Run: `flutter pub get`
Expected: `exit code 0`, no dependency conflicts

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat(deps): add emoji_picker_flutter for rich input"
```

---

## Task 2: Add `kind` parameter to `MessagesRepository.send()`

**Files:**
- Modify: `lib/repositories/messages_repository.dart:73-80`

- [ ] **Step 1: Update the `send` method signature and body**

In `lib/repositories/messages_repository.dart`, replace lines 73-80:

```dart
  /// Insert a text message. Returns the new row.
  Future<Message> send(String convId, String body) async {
    final row = await supabase
        .from('messages')
        .insert({'conv_id': convId, 'sender_id': currentUserId, 'body': body})
        .select()
        .single();
    return Message.fromMap(row);
  }
```

with:

```dart
  /// Insert a message. Returns the new row.
  Future<Message> send(String convId, String body, {String kind = 'text'}) async {
    final row = await supabase
        .from('messages')
        .insert({
          'conv_id': convId,
          'sender_id': currentUserId,
          'body': body,
          'kind': kind,
        })
        .select()
        .single();
    return Message.fromMap(row);
  }
```

- [ ] **Step 2: Verify no compile errors**

Run: `flutter analyze lib/repositories/messages_repository.dart`
Expected: No errors — the new parameter is optional with a default.

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/messages_repository.dart
git commit -m "feat(messages): add kind parameter to send()"
```

---

## Task 3: Create the shared `RichInput` widget

**Files:**
- Create: `lib/widgets/rich_input.dart`

- [ ] **Step 1: Create `lib/widgets/rich_input.dart`**

```dart
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class RichInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final bool showAttachments;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickLocation;
  final VoidCallback? onInvite;
  final String? hintText;
  final int minLines;
  final int maxLines;

  const RichInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.sending = false,
    this.showAttachments = false,
    this.onPickImage,
    this.onPickLocation,
    this.onInvite,
    this.hintText,
    this.minLines = 1,
    this.maxLines = 4,
  });

  @override
  State<RichInput> createState() => _RichInputState();
}

class _RichInputState extends State<RichInput> {
  bool _emojiOpen = false;
  final FocusNode _focusNode = FocusNode();
  double _keyboardHeight = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _emojiOpen = true);
    }
  }

  void _onTapTextField() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    if (kb > 0) _keyboardHeight = kb;
    final panelHeight = _keyboardHeight > 0 ? _keyboardHeight : 260.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: context.tokens.elev1,
            border: Border(
              top: BorderSide(color: context.tokens.line, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: !_emojiOpen,
            child: Row(
              children: [
                if (widget.showAttachments) ...[
                  GestureDetector(
                    onTap: _showAttachmentSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.tokens.elev2,
                        border: Border.all(color: context.tokens.line),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: context.tokens.inkSub,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      onTap: _onTapTextField,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.tokens.ink,
                        height: 1.4,
                      ),
                      minLines: widget.minLines,
                      maxLines: widget.maxLines,
                      onSubmitted: (_) => widget.onSend(),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(color: context.tokens.inkDim),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _toggleEmoji,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _emojiOpen ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      size: 24,
                      color: context.tokens.inkSub,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.sending ? null : widget.onSend,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.sending
                          ? context.tokens.elev3
                          : context.tokens.accent,
                      shape: BoxShape.circle,
                    ),
                    child: widget.sending
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: context.tokens.inkSub,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            size: 16,
                            color: context.tokens.accentInk,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_emojiOpen)
          SizedBox(
            height: panelHeight,
            child: EmojiPicker(
              textEditingController: widget.controller,
              onEmojiSelected: (_, __) {},
              config: Config(
                height: panelHeight,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28 *
                      (defaultTargetPlatform == TargetPlatform.iOS
                          ? 1.2
                          : 1.0),
                  backgroundColor: context.tokens.elev1,
                ),
                categoryViewConfig: CategoryViewConfig(
                  indicatorColor: context.tokens.accent,
                  iconColorSelected: context.tokens.accent,
                  iconColor: context.tokens.inkDim,
                  backgroundColor: context.tokens.elev1,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: context.tokens.elev1,
                  buttonIconColor: context.tokens.inkSub,
                  hintText: 'Search emoji...',
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (widget.onPickImage != null)
                  _AttBtn(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onPickImage!();
                    },
                  ),
                if (widget.onPickLocation != null)
                  _AttBtn(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onPickLocation!();
                    },
                  ),
                if (widget.onInvite != null)
                  _AttBtn(
                    icon: Icons.sports_soccer,
                    label: 'Invite',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      widget.onInvite!();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AttBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: context.tokens.ink),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.tokens.inkSub),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/widgets/rich_input.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/rich_input.dart
git commit -m "feat: create shared RichInput widget with emoji picker"
```

---

## Task 4: Integrate `RichInput` into DM chat screen + image sending + image bubble

**Files:**
- Modify: `lib/features/messages/chat_screen.dart`

- [ ] **Step 1: Update imports**

In `lib/features/messages/chat_screen.dart`, add after the existing imports (after line 14):

```dart
import '../../services/storage.dart';
import '../../widgets/rich_input.dart';
import 'package:cached_network_image/cached_network_image.dart';
```

- [ ] **Step 2: Add image pick method and replace `_showAttachmentSheet` + `_sendSystem`**

Replace lines 168-242 (the `_showAttachmentSheet` and `_sendSystem` methods) with:

```dart
  Future<void> _pickAndSendImage() async {
    final url = await StorageService().pickCropCompressAndUpload(
      bucket: 'chat-images',
      pathPrefix: widget.convId,
      square: false,
    );
    if (url == null || !mounted) return;
    try {
      await ref.read(messagesRepoProvider).send(widget.convId, url, kind: 'image');
    } catch (e) {
      if (mounted) {
        showToast(context, '${context.l10n.chat_send_failed}：$e', error: true);
      }
    }
  }

  void _sendPlaceholder(String label) {
    final l = context.l10n;
    ref.read(messagesRepoProvider).send(
      widget.convId,
      '${l.chat_attachment_system_placeholder} · $label',
    );
  }
```

- [ ] **Step 3: Replace the send bar (lines 336-415) with `RichInput`**

Replace the bottom send bar Container (lines 336-415, starting from `// Send bar` comment through the closing `)` of that Container) with:

```dart
            // Send bar
            RichInput(
              controller: _input,
              onSend: _send,
              sending: _sending,
              showAttachments: true,
              onPickImage: _pickAndSendImage,
              onPickLocation: () => _sendPlaceholder(context.l10n.chat_attachment_location),
              onInvite: () => _sendPlaceholder(context.l10n.chat_attachment_invite),
              hintText: context.l10n.chat_hint,
            ),
```

- [ ] **Step 4: Update `_Bubble` to render image messages**

In the `_Bubble` class, replace the `bubble` variable assignment (lines 486-501, from `final bubble = Container(` through its closing `);`) with:

```dart
    final Widget bubble;
    if (msg.kind == 'image' && msg.body != null) {
      bubble = GestureDetector(
        onTap: () => _showFullImage(context, msg.body!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 260),
            child: CachedNetworkImage(
              imageUrl: msg.body!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 160,
                height: 120,
                color: context.tokens.elev3,
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.tokens.accent,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 160,
                height: 80,
                color: context.tokens.elev3,
                child: Icon(Icons.broken_image, color: context.tokens.inkDim),
              ),
            ),
          ),
        ),
      );
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

- [ ] **Step 5: Add `_showFullImage` static method at the end of `_Bubble`**

Add this method inside the `_Bubble` class, before the closing `}`:

```dart
  static void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 6: Remove the now-unused `_AttBtn` class**

Delete the `_AttBtn` class (lines 423-452) — it is now provided by `RichInput`.

- [ ] **Step 7: Verify compile**

Run: `flutter analyze lib/features/messages/chat_screen.dart`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/features/messages/chat_screen.dart
git commit -m "feat(chat): integrate RichInput with emoji picker and image sending"
```

---

## Task 5: Integrate `RichInput` into event chat

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart:2210-2355`

- [ ] **Step 1: Add imports at the top of the file**

After the existing imports (around line 25), add:

```dart
import '../../services/storage.dart';
import '../../widgets/rich_input.dart';
import 'package:cached_network_image/cached_network_image.dart';
```

- [ ] **Step 2: Replace `_ChatInput` build method body**

Replace the entire `build` method in `_ChatInputState` (lines 2248-2302) with:

```dart
  @override
  Widget build(BuildContext context) {
    return RichInput(
      controller: _inputC,
      onSend: _send,
      sending: _sending,
      showAttachments: true,
      onPickImage: _pickAndSendImage,
      hintText: context.l10n.event_chat_hint,
    );
  }
```

- [ ] **Step 3: Add `_pickAndSendImage` method to `_ChatInputState`**

Add this method after `_send()` (after line 2245):

```dart
  Future<void> _pickAndSendImage() async {
    final convId = await ref.read(
      eventChatConvProvider(widget.eventId).future,
    );
    final url = await StorageService().pickCropCompressAndUpload(
      bucket: 'chat-images',
      pathPrefix: convId,
      square: false,
    );
    if (url == null || !mounted) return;
    try {
      await ref.read(messagesRepoProvider).send(convId, url, kind: 'image');
    } catch (e) {
      if (mounted) {
        showToast(context, context.l10n.chat_send_failed, error: true);
      }
    }
  }
```

- [ ] **Step 4: Update `_Msg` to render image messages**

In the `_Msg` widget's `build` method, replace the text body widget (the `Text(msg.body ?? '', ...)` around line 2342-2349) with:

```dart
                if (msg.kind == 'image' && msg.body != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180, maxHeight: 220),
                        child: CachedNetworkImage(
                          imageUrl: msg.body!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 140,
                            height: 100,
                            color: context.tokens.elev3,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: context.tokens.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 140,
                            height: 60,
                            color: context.tokens.elev3,
                            child: Icon(Icons.broken_image, color: context.tokens.inkDim),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    msg.body ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.ink,
                      height: 1.5,
                    ),
                  ),
```

- [ ] **Step 5: Verify compile**

Run: `flutter analyze lib/features/events/event_detail_screen.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(event-chat): integrate RichInput with emoji and image support"
```

---

## Task 6: Integrate `RichInput` into live danmaku screen

**Files:**
- Modify: `lib/features/events/wc_live_screen.dart:338-392`

- [ ] **Step 1: Add import**

After the existing imports (around line 19), add:

```dart
import '../../widgets/rich_input.dart';
```

- [ ] **Step 2: Replace the bottom input bar**

Replace lines 338-392 (the bottom `Container` with the TextField + send button) with:

```dart
            RichInput(
              controller: _inputC,
              onSend: _send,
              hintText: l.wc_live_input_hint,
            ),
```

- [ ] **Step 3: Verify compile**

Run: `flutter analyze lib/features/events/wc_live_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/features/events/wc_live_screen.dart
git commit -m "feat(danmaku): integrate RichInput with emoji picker"
```

---

## Task 7: Add emoji support to post-match rating comment field

**Files:**
- Modify: `lib/features/rating/post_match_rating_screen.dart`

This screen uses a different layout pattern — the comment field is inside a scrollable card, not a fixed bottom bar. We add an emoji button as `suffixIcon` and an emoji panel that appears below the card.

- [ ] **Step 1: Add imports**

After the existing imports, add:

```dart
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
```

- [ ] **Step 2: Add state variables for emoji**

In the `_PostMatchRatingScreenState` class, add these fields alongside the existing ones:

```dart
  bool _emojiOpen = false;
  final _commentFocus = FocusNode();
  final _commentControllers = <String, TextEditingController>{};
```

- [ ] **Step 3: Add dispose for the new controllers**

In the `dispose()` method, add before `super.dispose()`:

```dart
    _commentFocus.dispose();
    for (final c in _commentControllers.values) {
      c.dispose();
    }
```

- [ ] **Step 4: Add helper to get or create controller per player**

Add this method to the state class:

```dart
  TextEditingController _commentCtrlFor(String name) {
    return _commentControllers.putIfAbsent(name, () {
      final ctrl = TextEditingController(text: _comments[name] ?? '');
      ctrl.addListener(() => _comments[name] = ctrl.text);
      return ctrl;
    });
  }
```

- [ ] **Step 5: Replace the comment TextField**

Replace the comment TextField block (lines 329-356) with:

```dart
                        TextField(
                          key: ValueKey('comment-${p.displayName}'),
                          controller: _commentCtrlFor(p.displayName),
                          focusNode: _commentFocus,
                          onTap: () {
                            if (_emojiOpen) setState(() => _emojiOpen = false);
                          },
                          minLines: 3,
                          maxLines: 4,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.tokens.ink,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: isYou
                                ? context.l10n.rate_self_hint
                                : context.l10n.rate_other_hint,
                            hintStyle: TextStyle(color: context.tokens.inkDim),
                            filled: true,
                            fillColor: context.tokens.elev3,
                            contentPadding: const EdgeInsets.all(12),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                if (_emojiOpen) {
                                  setState(() => _emojiOpen = false);
                                  _commentFocus.requestFocus();
                                } else {
                                  _commentFocus.unfocus();
                                  setState(() => _emojiOpen = true);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  _emojiOpen
                                      ? Icons.keyboard
                                      : Icons.emoji_emotions_outlined,
                                  size: 22,
                                  color: context.tokens.inkSub,
                                ),
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: context.tokens.line),
                              borderRadius: BorderRadius.circular(context.tokens.r2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: context.tokens.line),
                              borderRadius: BorderRadius.circular(context.tokens.r2),
                            ),
                          ),
                        ),
```

- [ ] **Step 6: Add emoji panel below the scrollable content**

Find the location in the build method where the main Column of the Scaffold body ends. Before the closing of the body's Column, add the emoji panel. This should be placed after the `Expanded(child: PageView(...))` and before the bottom navigation, as a conditional widget:

```dart
                if (_emojiOpen)
                  SizedBox(
                    height: 260,
                    child: EmojiPicker(
                      textEditingController: _commentCtrlFor(
                        _players[_idx].displayName,
                      ),
                      onEmojiSelected: (_, __) {},
                      config: Config(
                        height: 260,
                        checkPlatformCompatibility: true,
                        emojiViewConfig: EmojiViewConfig(
                          columns: 8,
                          emojiSizeMax: 28 *
                              (defaultTargetPlatform == TargetPlatform.iOS
                                  ? 1.2
                                  : 1.0),
                          backgroundColor: context.tokens.elev1,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          indicatorColor: context.tokens.accent,
                          iconColorSelected: context.tokens.accent,
                          iconColor: context.tokens.inkDim,
                          backgroundColor: context.tokens.elev1,
                        ),
                        bottomActionBarConfig: const BottomActionBarConfig(
                          enabled: false,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: context.tokens.elev1,
                          buttonIconColor: context.tokens.inkSub,
                          hintText: 'Search emoji...',
                        ),
                      ),
                    ),
                  ),
```

- [ ] **Step 7: Verify compile**

Run: `flutter analyze lib/features/rating/post_match_rating_screen.dart`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/features/rating/post_match_rating_screen.dart
git commit -m "feat(rating): add emoji picker to comment field"
```

---

## Task 8: Add emoji support to rate player bottom sheet

**Files:**
- Modify: `lib/features/rating/widgets/rate_player_sheet.dart`

- [ ] **Step 1: Add imports**

After the existing imports, add:

```dart
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
```

- [ ] **Step 2: Add state variable**

In `_RatePlayerSheetState`, add:

```dart
  bool _emojiOpen = false;
  final _commentFocus = FocusNode();
```

- [ ] **Step 3: Add dispose**

In `dispose()`, add before `super.dispose()`:

```dart
    _commentFocus.dispose();
```

- [ ] **Step 4: Update the comment TextField**

Replace the comment TextField (lines 191-219) with:

```dart
              TextField(
                controller: _commentCtrl,
                focusNode: _commentFocus,
                onTap: () {
                  if (_emojiOpen) setState(() => _emojiOpen = false);
                },
                minLines: 2,
                maxLines: 3,
                style: TextStyle(
                  fontSize: 13,
                  color: context.tokens.ink,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: l.rate_other_hint,
                  hintStyle: TextStyle(color: context.tokens.inkDim),
                  filled: true,
                  fillColor: context.tokens.elev3,
                  contentPadding: const EdgeInsets.all(12),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      if (_emojiOpen) {
                        setState(() => _emojiOpen = false);
                        _commentFocus.requestFocus();
                      } else {
                        _commentFocus.unfocus();
                        setState(() => _emojiOpen = true);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _emojiOpen
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        size: 22,
                        color: context.tokens.inkSub,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: context.tokens.accent),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                ),
              ),
```

- [ ] **Step 5: Add emoji panel after the save button**

After the `PrimaryButton(...)` and before the closing `],` of the Column's children, add:

```dart
              if (_emojiOpen) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: EmojiPicker(
                    textEditingController: _commentCtrl,
                    onEmojiSelected: (_, __) {},
                    config: Config(
                      height: 220,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        columns: 8,
                        emojiSizeMax: 28 *
                            (defaultTargetPlatform == TargetPlatform.iOS
                                ? 1.2
                                : 1.0),
                        backgroundColor: context.tokens.elev1,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        indicatorColor: context.tokens.accent,
                        iconColorSelected: context.tokens.accent,
                        iconColor: context.tokens.inkDim,
                        backgroundColor: context.tokens.elev1,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        enabled: false,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: context.tokens.elev1,
                        buttonIconColor: context.tokens.inkSub,
                        hintText: 'Search emoji...',
                      ),
                    ),
                  ),
                ),
              ],
```

- [ ] **Step 6: Verify compile**

Run: `flutter analyze lib/features/rating/widgets/rate_player_sheet.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/features/rating/widgets/rate_player_sheet.dart
git commit -m "feat(rating-sheet): add emoji picker to comment field"
```

---

## Task 9: Final verification

**Files:** All modified files

- [ ] **Step 1: Run full project analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: Run tests**

Run: `flutter test`
Expected: All existing tests pass

- [ ] **Step 3: Final commit (if any fixups needed)**

```bash
git add -A
git commit -m "chore: fix any remaining lint issues from rich input MVP"
```
