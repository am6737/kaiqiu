// danmaku_overlay.dart — B 站风格的直播弹幕叠层控件。
//
// 订阅一个 [Stream<DanmakuItem>],在固定轨道上从右向左匀速飘过文字。
// 与视频播放器叠加使用,外层需包 [IgnorePointer] 以免截获手势。

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 一条弹幕的数据载体。
class DanmakuItem {
  final String user;
  final String text;
  final bool self;
  const DanmakuItem({
    required this.user,
    required this.text,
    required this.self,
  });
}

class DanmakuOverlay extends StatefulWidget {
  final Stream<DanmakuItem> stream;
  final bool enabled;
  final int trackCount;
  final Duration speed;
  const DanmakuOverlay({
    super.key,
    required this.stream,
    this.enabled = true,
    this.trackCount = 4,
    this.speed = const Duration(seconds: 8),
  });

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _ActiveDanmu {
  final DanmakuItem item;
  final int track;
  final AnimationController controller;
  double width = 0; // measured on first layout, 0 means "not yet measured".
  _ActiveDanmu({
    required this.item,
    required this.track,
    required this.controller,
  });
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<DanmakuItem>? _sub;
  final List<_ActiveDanmu> _active = [];

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(_onItem);
  }

  @override
  void didUpdateWidget(DanmakuOverlay old) {
    super.didUpdateWidget(old);
    if (widget.stream != old.stream) {
      _sub?.cancel();
      _sub = widget.stream.listen(_onItem);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final d in _active) {
      d.controller.dispose();
    }
    _active.clear();
    super.dispose();
  }

  void _onItem(DanmakuItem item) {
    if (!widget.enabled) return;
    if (!mounted) return;
    final c = AnimationController(vsync: this, duration: widget.speed);
    final active = _ActiveDanmu(item: item, track: 0, controller: c);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (!mounted) {
          return; // State.dispose will handle the controller.
        }
        // Remove from active list; controller can now be safely disposed.
        setState(() => _active.remove(active));
        c.dispose();
      }
    });
    setState(() {
      _active.add(active);
    });
    c.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final d in _active)
              AnimatedBuilder(
                animation: d.controller,
                builder: (context, child) {
                  // x goes from w (off-screen right) to -d.width (off-screen left).
                  final x = w - (w + d.width) * d.controller.value;
                  return Positioned(
                    left: x,
                    top: 12.0 + d.track * 28.0,
                    child: child!,
                  );
                },
                child: _DanmuText(
                  item: d.item,
                  onMeasured: (width) => d.width = width,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DanmuText extends StatelessWidget {
  final DanmakuItem item;
  final ValueChanged<double> onMeasured;
  const _DanmuText({required this.item, required this.onMeasured});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: item.self ? t.accent : Colors.white,
      shadows: const [
        Shadow(color: Color(0xAA000000), blurRadius: 2, offset: Offset(1, 1)),
      ],
    );
    final textWidget = Text(item.text, style: base);
    final child = item.self
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: t.accentSubtle,
              border: Border.all(color: t.accent, width: 1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: textWidget,
          )
        : textWidget;
    return _MeasureSize(onMeasured: onMeasured, child: child);
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onMeasured;
  const _MeasureSize({required this.child, required this.onMeasured});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final GlobalKey _key = GlobalKey();
  bool _measured = false;

  @override
  Widget build(BuildContext context) {
    if (!_measured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          _measured = true;
          widget.onMeasured(box.size.width);
        }
      });
    }
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
