import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';
import 'network_avatar.dart';

OverlayEntry? _currentEntry;
Timer? _dismissTimer;

void showInAppNotification(
  BuildContext context, {
  required String title,
  required String body,
  String? avatarUrl,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  _dismissTimer?.cancel();
  _currentEntry?.remove();
  _currentEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  void remove() {
    _dismissTimer?.cancel();
    if (_currentEntry == entry) {
      entry.remove();
      _currentEntry = null;
    }
  }

  entry = OverlayEntry(
    builder: (_) => _InAppBanner(
      title: title,
      body: body,
      avatarUrl: avatarUrl,
      onTap: () {
        remove();
        onTap?.call();
      },
      onDismiss: remove,
    ),
  );

  _currentEntry = entry;
  overlay.insert(entry);

  HapticFeedback.lightImpact();

  _dismissTimer = Timer(duration, () {
    if (_currentEntry == entry) {
      entry.remove();
      _currentEntry = null;
    }
  });
}

class _InAppBanner extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppBanner({
    required this.title,
    required this.body,
    this.avatarUrl,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppBanner> createState() => _InAppBannerState();
}

class _InAppBannerState extends State<_InAppBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (d) {
              if (d.primaryVelocity != null && d.primaryVelocity! < -100) {
                widget.onDismiss();
              }
            },
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.elev2,
                  borderRadius: BorderRadius.circular(t.r3),
                  border: Border.all(color: t.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      NetworkAvatar(widget.title,
                          url: widget.avatarUrl, size: 38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.body,
                              style: TextStyle(
                                fontSize: 13,
                                color: t.inkSub,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: t.inkDim,
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
