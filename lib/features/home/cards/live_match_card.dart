import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/live_match.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/live_pill.dart';
import '../../../widgets/typography.dart';

class LiveMatchCarousel extends StatefulWidget {
  final List<LiveMatch> items;
  const LiveMatchCarousel({super.key, required this.items});

  @override
  State<LiveMatchCarousel> createState() => _LiveMatchCarouselState();
}

class _LiveMatchCarouselState extends State<LiveMatchCarousel> {
  late final PageController _ctrl;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        _current = (_current + 1) % widget.items.length;
        _ctrl.animateToPage(
          _current,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final t = context.tokens;
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final posterUrl = m.posterUrl;
              final aWins = m.scoreA > m.scoreB;
              final bWins = m.scoreB > m.scoreA;
              return GestureDetector(
                onTap: () => context.push('/worldcup/live/${m.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(t.r3),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: posterUrl ?? '',
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 160),
                          errorWidget: (_, _, _) =>
                              Container(color: t.elev2),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x33000000),
                                Color(0xCC000000),
                              ],
                              stops: [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const LivePill(),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${m.viewersDisplay} 观看 · ${m.minute}',
                                    style: TextStyle(
                                      fontFamily: t.fontMono,
                                      fontFamilyFallback: t.monoFallbacks,
                                      fontSize: 11,
                                      color: Colors.white70,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.teamA,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  N(
                                    '${m.scoreA}',
                                    size: 28,
                                    weight: FontWeight.w700,
                                    color: aWins ? t.accent : Colors.white,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: Text(
                                      ':',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                  N(
                                    '${m.scoreB}',
                                    size: 28,
                                    weight: FontWeight.w700,
                                    color: bWins ? t.accent : Colors.white,
                                  ),
                                  Expanded(
                                    child: Text(
                                      m.teamB,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = i == _current;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? t.accent : t.inkMute,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
