import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import 'match_control_panel.dart';

class MatchLiveRoom extends ConsumerStatefulWidget {
  final String eventId;
  final String matchId;
  const MatchLiveRoom({
    super.key,
    required this.eventId,
    required this.matchId,
  });

  @override
  ConsumerState<MatchLiveRoom> createState() => _MatchLiveRoomState();
}

class _MatchLiveRoomState extends ConsumerState<MatchLiveRoom> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _connecting = true;
  String? _error;
  bool _micEnabled = true;
  bool _camEnabled = true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final tokenData =
          await ref.read(livekitTokenProvider(widget.matchId).future);
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );

      _listener = room.createListener();
      _listener!
        ..on<ParticipantConnectedEvent>((_) => _refresh())
        ..on<ParticipantDisconnectedEvent>((_) => _refresh())
        ..on<TrackPublishedEvent>((_) => _refresh())
        ..on<TrackUnpublishedEvent>((_) => _refresh())
        ..on<TrackSubscribedEvent>((_) => _refresh())
        ..on<TrackUnsubscribedEvent>((_) => _refresh())
        ..on<TrackMutedEvent>((_) => _refresh())
        ..on<TrackUnmutedEvent>((_) => _refresh());

      await room.connect(
        tokenData.wsUrl,
        tokenData.token,
      );

      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _room = room;
        _connecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _connecting = false;
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleMic() async {
    _micEnabled = !_micEnabled;
    await _room?.localParticipant?.setMicrophoneEnabled(_micEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCam() async {
    _camEnabled = !_camEnabled;
    await _room?.localParticipant?.setCameraEnabled(_camEnabled);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }

  bool get _isHost {
    final uid = currentUserId;
    if (uid == null) return false;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    return eventAsync.valueOrNull?.creatorId == uid;
  }

  List<Participant> get _participants {
    final room = _room;
    if (room == null) return [];
    return [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
  }

  void _showControlPanel() {
    final matchAsync = ref.read(matchRealtimeProvider(widget.matchId));
    final match = matchAsync.valueOrNull;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchControlPanel(
        matchId: widget.matchId,
        eventId: widget.eventId,
        initialScoreA: match?.scoreA ?? 0,
        initialScoreB: match?.scoreB ?? 0,
        initialMinute: match?.minute ?? 0,
        onMatchEnded: () {
          Navigator.pop(context);
          _room?.disconnect();
          if (mounted) context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final matchAsync = ref.watch(matchRealtimeProvider(widget.matchId));

    if (_connecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                l.live_room_reconnecting,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _connecting = true;
                    _error = null;
                  });
                  _connect();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final participants = _participants;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              participantCount: participants.length,
              onBack: () {
                _room?.disconnect();
                context.pop();
              },
              isHost: _isHost,
              onControl: _isHost ? _showControlPanel : null,
            ),
            Expanded(
              child: _VideoGrid(participants: participants),
            ),
            matchAsync.when(
              data: (match) => _ScoreBar(match: match),
              loading: () => const SizedBox(height: 48),
              error: (e, st) => const SizedBox(height: 48),
            ),
            _BottomControls(
              micEnabled: _micEnabled,
              camEnabled: _camEnabled,
              onToggleMic: _toggleMic,
              onToggleCam: _toggleCam,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int participantCount;
  final VoidCallback onBack;
  final bool isHost;
  final VoidCallback? onControl;

  const _TopBar({
    required this.participantCount,
    required this.onBack,
    required this.isHost,
    this.onControl,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              l.live_room_title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          if (isHost)
            IconButton(
              icon:
                  const Icon(Icons.settings, color: Colors.white70, size: 20),
              onPressed: onControl,
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$participantCount',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoGrid extends StatelessWidget {
  final List<Participant> participants;
  const _VideoGrid({required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    final count = participants.length;
    final crossCount = count <= 1
        ? 1
        : count <= 4
            ? 2
            : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 4 / 3,
      ),
      itemCount: count,
      itemBuilder: (ctx, i) => _ParticipantTile(participant: participants[i]),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    // videoTrackPublications is a List, not a Map — iterate directly.
    final videoTrack = participant.videoTrackPublications
        .where((pub) => pub.track != null && !pub.muted)
        .map((pub) => pub.track as VideoTrack)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.grey[900],
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white12,
                  child: Text(
                    (participant.name.isNotEmpty
                            ? participant.name
                            : participant.identity)[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  participant.name.isNotEmpty
                      ? participant.name
                      : participant.identity,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            if (participant.isMuted)
              const Positioned(
                right: 6,
                bottom: 6,
                child:
                    Icon(Icons.mic_off, color: Colors.redAccent, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final Match match;
  const _ScoreBar({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              match.teamALabel ?? 'Team A',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${match.scoreA ?? 0} - ${match.scoreB ?? 0}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              match.teamBLabel ?? 'Team B',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),
          if (match.minute != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${match.minute}'",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final bool micEnabled;
  final bool camEnabled;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCam;

  const _BottomControls({
    required this.micEnabled,
    required this.camEnabled,
    required this.onToggleMic,
    required this.onToggleCam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlButton(
            icon: micEnabled ? Icons.mic : Icons.mic_off,
            active: micEnabled,
            onPressed: onToggleMic,
          ),
          const SizedBox(width: 24),
          _ControlButton(
            icon: camEnabled ? Icons.videocam : Icons.videocam_off,
            active: camEnabled,
            onPressed: onToggleCam,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white24 : Colors.redAccent,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
