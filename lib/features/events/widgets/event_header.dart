import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/network_cover.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class EventHeader extends StatelessWidget {
  final Event event;
  final VoidCallback onBack;
  const EventHeader({
    super.key,
    required this.event,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    final l = context.l10n;
    final (dotColor, pillColor, pillText) = switch (event.status) {
      EventStatus.ongoing => (context.tokens.accent, context.tokens.accent, l.event_status_ongoing),
      EventStatus.registering => (context.tokens.warn, context.tokens.warn, l.event_status_registering),
      EventStatus.completed => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
      EventStatus.scheduling => (context.tokens.warn, context.tokens.warn, l.event_status_scheduling),
      EventStatus.cancelled => (context.tokens.danger, context.tokens.danger, l.event_status_cancelled),
      _ => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
    };
    return Stack(
      children: [
        NetworkCover(
          url: event.coverUrl,
          fallbackLabel: context.l10n.event_overview_main_visual(event.name),
          height: 240,
          hue: hue,
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Color(0x80000000),
                  Color(0x40000000),
                  Color(0x66000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => shareEvent(event),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.ios_share,
                  size: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Label(pillText, color: pillColor),
                  if (event.sub != null && event.sub!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Label('· ${event.sub!}', color: const Color(0xCCFFFFFF)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
