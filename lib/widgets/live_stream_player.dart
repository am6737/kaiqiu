// live_stream_player.dart — HLS live stream player with broadcast-style overlay.
//
// Wraps `video_player` to play a public HLS test stream with automatic
// fallback between multiple candidate URLs. Default behavior mirrors a
// real live broadcast: muted auto-play, tap-to-toggle controls,
// loading / error / signal-weak states, fullscreen button.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../l10n/l10n_extension.dart';
import '../theme/tokens.dart';
import 'live_pill.dart';

/// Public HLS test streams (reliable CDNs, always-on).
/// Tried in order — the first one that initializes wins.
const List<String> kHlsCandidates = <String>[
  // Mux public test stream (Big Buck Bunny, multi-bitrate).
  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  // Bitmovin public test stream (Sintel, multi-bitrate).
  'https://bitmovin-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8',
  // Apple BipBop advanced example.
  'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8',
];

class LiveStreamPlayer extends StatefulWidget {
  final double height;

  /// Rendered top-left (typically a back button).
  final Widget? topLeft;

  /// Rendered top-right (reminder / share / etc).
  final Widget? topRight;

  /// Rendered bottom-left (LIVE pill + minute).
  final Widget? bottomLeftOverlay;

  /// Rendered bottom-right (viewer count).
  final Widget? bottomRightOverlay;

  /// Compact broadcast-style scoreboard shown top-center on the video.
  /// e.g. "ARG 1 - 1 BRA · 67'".
  final String? scoreOverlay;

  const LiveStreamPlayer({
    super.key,
    this.height = 240,
    this.topLeft,
    this.topRight,
    this.bottomLeftOverlay,
    this.bottomRightOverlay,
    this.scoreOverlay,
  });

  @override
  State<LiveStreamPlayer> createState() => _LiveStreamPlayerState();
}

class _LiveStreamPlayerState extends State<LiveStreamPlayer> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _error = false;
  bool _muted = true;
  bool _showControls = false;
  bool _retrying = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initSource(0);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initSource(int idx) async {
    if (idx >= kHlsCandidates.length) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _retrying = false;
      });
      return;
    }
    final url = kHlsCandidates[idx];
    final oldCtrl = _controller;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.setVolume(_muted ? 0 : 1);
      await ctrl.play();
      setState(() {
        _controller = ctrl;
        _loading = false;
        _error = false;
        _retrying = false;
      });
      await oldCtrl?.dispose();
    } catch (_) {
      await ctrl.dispose();
      // Try the next candidate.
      if (!mounted) return;
      _initSource(idx + 1);
    }
  }

  void _retry() {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _loading = true;
      _error = false;
    });
    _initSource(0);
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _hideTimer?.cancel();
    if (_showControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _showControls = false);
      });
    }
  }

  void _tapControl(VoidCallback action) {
    action();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  Future<void> _togglePlayPause() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null) return;
    final next = !_muted;
    await c.setVolume(next ? 0 : 1);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  void _enterFullscreen() {
    final c = _controller;
    if (c == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => _LiveFullscreenRoute(
          controller: c,
          initiallyMuted: _muted,
          onMuteChanged: (m) async {
            _muted = m;
            await c.setVolume(m ? 0 : 1);
            if (mounted) setState(() {});
          },
          scoreOverlay: widget.scoreOverlay,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: black behind video while loading.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E1712), Color(0xFF050808)],
              ),
            ),
          ),
          // Video surface.
          if (_controller != null && _controller!.value.isInitialized)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          // Dim scrim so white overlays stay legible over bright pixels.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x66000000),
                      Color(0x00000000),
                      Color(0x66000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          // Loading state.
          if (_loading)
            const Center(
              child: _LoadingIndicator(),
            ),
          // Error state — tap to retry.
          if (_error)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _retry,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.signal_wifi_off,
                        color: Colors.white70,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.wc_live_signal_weak,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.wc_live_tap_retry,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Top-center broadcast scoreboard chip.
          if (widget.scoreOverlay != null)
            Positioned(
              top: 44,
              left: 0,
              right: 0,
              child: Center(child: _ScoreboardChip(text: widget.scoreOverlay!)),
            ),
          // Top-left.
          if (widget.topLeft != null)
            Positioned(top: 40, left: 12, child: widget.topLeft!),
          // Top-right.
          if (widget.topRight != null)
            Positioned(top: 40, right: 12, child: widget.topRight!),
          // Bottom row of overlays (LIVE pill, viewers).
          Positioned(
            bottom: 10,
            left: 14,
            right: 14,
            child: Row(
              children: [
                if (widget.bottomLeftOverlay != null) widget.bottomLeftOverlay!,
                const Spacer(),
                if (widget.bottomRightOverlay != null)
                  widget.bottomRightOverlay!,
              ],
            ),
          ),
          // Center play/pause button — shown when controls visible OR when paused.
          if (_controller != null &&
              !_loading &&
              !_error &&
              (_showControls || !_controller!.value.isPlaying))
            Center(
              child: GestureDetector(
                onTap: () => _tapControl(_togglePlayPause),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x80000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          // Mute + fullscreen — bottom-right corner, shown with controls.
          if (_controller != null && !_loading && !_error && _showControls)
            Positioned(
              bottom: 44,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CircleControl(
                    icon: _muted ? Icons.volume_off : Icons.volume_up,
                    onTap: () => _tapControl(_toggleMute),
                  ),
                  const SizedBox(width: 8),
                  _CircleControl(
                    icon: Icons.fullscreen,
                    onTap: () => _tapControl(_enterFullscreen),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Broadcast-style scoreboard chip (semi-transparent black pill with a live dot).
class _ScoreboardChip extends StatelessWidget {
  final String text;
  const _ScoreboardChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: T.live,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: T.live, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: T.fontMono,
              fontFamilyFallback: T.monoFallbacks,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleControl({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0x80000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(T.live),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l.wc_live_loading,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Fullscreen landscape overlay for the live stream.
/// Takes the existing [VideoPlayerController] — does not re-initialize the stream.
class _LiveFullscreenRoute extends StatefulWidget {
  final VideoPlayerController controller;
  final bool initiallyMuted;
  final ValueChanged<bool> onMuteChanged;
  final String? scoreOverlay;

  const _LiveFullscreenRoute({
    required this.controller,
    required this.initiallyMuted,
    required this.onMuteChanged,
    required this.scoreOverlay,
  });

  @override
  State<_LiveFullscreenRoute> createState() => _LiveFullscreenRouteState();
}

class _LiveFullscreenRouteState extends State<_LiveFullscreenRoute> {
  bool _showControls = false;
  late bool _muted = widget.initiallyMuted;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggle() {
    setState(() => _showControls = !_showControls);
    _hideTimer?.cancel();
    if (_showControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _showControls = false);
      });
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await widget.controller.setVolume(next ? 0 : 1);
    widget.onMuteChanged(next);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _togglePlayPause() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio == 0
                    ? 16 / 9
                    : widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            // Top-left close.
            if (_showControls)
              Positioned(
                top: 24,
                left: 16,
                child: _CircleControl(
                  icon: Icons.fullscreen_exit,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            // Top-center scoreboard.
            if (widget.scoreOverlay != null)
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: _ScoreboardChip(text: widget.scoreOverlay!),
                ),
              ),
            // Bottom-left LIVE pill.
            const Positioned(bottom: 24, left: 20, child: LivePill()),
            // Bottom-right controls.
            if (_showControls)
              Positioned(
                bottom: 24,
                right: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircleControl(
                      icon: _muted ? Icons.volume_off : Icons.volume_up,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 10),
                    _CircleControl(
                      icon: widget.controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      onTap: _togglePlayPause,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
