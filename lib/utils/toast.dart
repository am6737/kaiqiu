import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

OverlayEntry? _toastEntry;
Timer? _toastTimer;

void showToast(
  BuildContext context,
  String msg, {
  bool success = false,
  bool error = false,
  bool info = false,
}) {
  _toastTimer?.cancel();
  _toastEntry?.remove();
  _toastEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  void remove() {
    _toastTimer?.cancel();
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  }

  entry = OverlayEntry(
    builder: (_) => _TopToast(
      msg: msg,
      success: success,
      error: error,
      info: info,
      onDismiss: remove,
    ),
  );

  _toastEntry = entry;
  overlay.insert(entry);

  HapticFeedback.lightImpact();

  _toastTimer = Timer(const Duration(seconds: 3), () {
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  });
}

class _TopToast extends StatefulWidget {
  final String msg;
  final bool success;
  final bool error;
  final bool info;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.msg,
    required this.success,
    required this.error,
    required this.info,
    required this.onDismiss,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.of(context).padding.top;

    final IconData icon;
    final Color bg;
    final Color fg;
    final Color iconColor;
    final Color borderColor;

    if (widget.error) {
      icon = Icons.error_outline_rounded;
      bg = t.danger.withAlpha(30);
      fg = t.danger;
      iconColor = t.danger;
      borderColor = t.danger.withAlpha(40);
    } else if (widget.success) {
      icon = Icons.check_circle_outline_rounded;
      bg = t.accent.withAlpha(30);
      fg = t.accent;
      iconColor = t.accent;
      borderColor = t.accent.withAlpha(40);
    } else if (widget.info) {
      icon = Icons.info_outline_rounded;
      bg = t.elev3;
      fg = t.ink;
      iconColor = t.inkSub;
      borderColor = t.line;
    } else {
      icon = Icons.chat_bubble_outline_rounded;
      bg = t.elev3;
      fg = t.ink;
      iconColor = t.inkSub;
      borderColor = t.line;
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity != null && d.primaryVelocity! < -100) {
                widget.onDismiss();
              }
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(t.r2),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: iconColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.msg,
                          style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
