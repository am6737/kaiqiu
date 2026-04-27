import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                    constraints: const BoxConstraints(minHeight: 38),
                    alignment: Alignment.center,
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
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleEmoji,
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
                      _emojiOpen
                          ? Icons.keyboard
                          : Icons.emoji_emotions_outlined,
                      size: 18,
                      color: context.tokens.inkSub,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
              onEmojiSelected: (_, _) {},
              config: Config(
                height: panelHeight,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax:
                      28 *
                      (defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
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
  const _AttBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
