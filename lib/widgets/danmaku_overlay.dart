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
  double _layoutWidth = 400.0;

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

  /// Picks a track for a new danmu, or null if the overlay is congested.
  ///
  /// Strategy:
  /// 1. Prefer any empty track (lowest index first).
  /// 2. Otherwise pick the track whose latest entry's tail has moved
  ///    furthest past the right edge of the overlay — i.e. the most
  ///    space behind it.
  /// 3. If even the best candidate's tail has not cleared the right
  ///    edge (tail_position >= overlay_right), return null so the
  ///    caller drops the incoming item instead of overlapping.
  int? _pickTrack(double overlayWidth) {
    // latestByTrack: for each occupied track, keep the entry with the
    // smallest progress (= just entered = furthest right tail).
    final latestByTrack = <int, _ActiveDanmu>{};
    for (final d in _active) {
      final prev = latestByTrack[d.track];
      if (prev == null || d.controller.value < prev.controller.value) {
        latestByTrack[d.track] = d;
      }
    }

    // Empty tracks first.
    for (var i = 0; i < widget.trackCount; i++) {
      if (!latestByTrack.containsKey(i)) return i;
    }

    // All tracks occupied — pick by how far the latest entry's tail has
    // moved past the right edge.
    //   x(t) = overlayWidth - (overlayWidth + width) * t
    //   tail position on screen = x + width
    //   how far tail has cleared the right edge = overlayWidth - (x + width)
    //                                           = (overlayWidth + width) * t - width
    int? best;
    double bestScore = -double.infinity;
    latestByTrack.forEach((track, d) {
      // Unmeasured width (first frame): treat as infinite — the incoming
      // danmu would land on top of a danmu whose footprint we don't yet
      // know. Prefer to drop.
      if (d.width == 0) {
        // -infinity score means this track will never be chosen over any
        // measured track, and if it's the only candidate the bestScore
        // stays negative and we drop.
        return;
      }
      final tailLeftOfRight =
          (overlayWidth + d.width) * d.controller.value - d.width;
      if (tailLeftOfRight > bestScore) {
        bestScore = tailLeftOfRight;
        best = track;
      }
    });
    // Best candidate's tail still on the right edge? Drop.
    if (bestScore <= 0) return null;
    return best;
  }

  void _onItem(DanmakuItem item) {
    if (!widget.enabled) return;
    if (!mounted) return;
    final track = _pickTrack(_layoutWidth);
    if (track == null) return; // all tracks busy — drop.
    final c = AnimationController(vsync: this, duration: widget.speed);
    final active = _ActiveDanmu(item: item, track: track, controller: c);
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (!mounted) {
          return; // State.dispose will handle the controller.
        }
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
        _layoutWidth = constraints.maxWidth;
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const topInset = 80.0;
        const bottomInset = 40.0;
        const trackHeight = 28.0;
        final usable = (h - topInset - bottomInset).clamp(
          trackHeight,
          double.infinity,
        );
        final trackGap = widget.trackCount <= 1
            ? 0.0
            : (usable - trackHeight) / (widget.trackCount - 1);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final d in _active)
              AnimatedBuilder(
                animation: d.controller,
                builder: (context, child) {
                  // x goes from w (off-screen right) to -d.width (off-screen left).
                  final x = w - (w + d.width) * d.controller.value;
                  final y = topInset + d.track * trackGap;
                  return Positioned(
                    left: x,
                    top: y,
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
