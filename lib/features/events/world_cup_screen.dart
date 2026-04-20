// world_cup_screen.dart — 世界杯专区
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class WorldCupScreen extends ConsumerWidget {
  const WorldCupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wcs = ref.watch(wcMatchesProvider);

    return Scaffold(
      backgroundColor: T.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Hero
          Stack(
            children: [
              Container(
                height: 240,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      HSLColor.fromAHSL(1, 260, 0.5, 0.18).toColor(),
                      HSLColor.fromAHSL(1, 290, 0.5, 0.12).toColor(),
                    ],
                  ),
                ),
                child: CustomPaint(painter: _HeroPainter()),
              ),
              Positioned(
                top: 12, left: 12,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36, height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x80000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: T.ink),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 16, right: 16, bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label('FIFA 2026', color: T.live),
                    SizedBox(height: 6),
                    Text('世界杯专区',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: T.ink,
                          letterSpacing: -0.6,
                          height: 1.1,
                        )),
                    SizedBox(height: 6),
                    Text('小组赛 · 第 2 轮 · 今晚 5 场直播',
                        style: TextStyle(fontSize: 13, color: T.inkSub)),
                  ],
                ),
              ),
            ],
          ),
          // Featured match
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Label('焦点之战 · 直播中'),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: T.elev2,
              border: Border.all(color: const Color(0x4D00FF85)),
              borderRadius: BorderRadius.circular(T.r3),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const LivePill(),
                    const SizedBox(width: 6),
                    Label('${wcs[0].minute} · 下半场'),
                    const Spacer(),
                    const Label('128K 观看'),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _flag('AR', 200),
                          const SizedBox(height: 8),
                          const Text('阿根廷',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: T.ink)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        N('${wcs[0].scoreA ?? 0}',
                            size: 40, weight: FontWeight.w800, color: T.live),
                        const SizedBox(width: 8),
                        const Text('-',
                            style: TextStyle(color: T.inkDim, fontSize: 18)),
                        const SizedBox(width: 8),
                        N('${wcs[0].scoreB ?? 0}',
                            size: 40, weight: FontWeight.w800, color: T.ink),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _flag('BR', 140),
                          const SizedBox(height: 8),
                          const Text('巴西',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: T.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Expanded(
                      child: PrimaryButton(
                        variant: BtnVariant.primary,
                        size: BtnSize.md,
                        full: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow, size: 14, color: Colors.black),
                            SizedBox(width: 6),
                            Text('观看直播',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    PrimaryButton(
                      variant: BtnVariant.ghost,
                      size: BtnSize.md,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed, size: 14, color: T.ink),
                          SizedBox(width: 6),
                          Text('竞猜',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: T.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Prediction bar
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Label('你的球友竞猜 · 胜平负'),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.elev2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r3),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _predBar(62, '阿根廷胜', T.live, Colors.black),
                    const SizedBox(width: 8),
                    _predBar(14, '平', T.inkMute, T.ink),
                    const SizedBox(width: 8),
                    _predBar(24, '巴西胜', T.elev3, T.ink),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Label('阿根廷胜'),
                    Label('平'),
                    Label('巴西胜'),
                  ],
                ),
              ],
            ),
          ),
          // Today's schedule
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Label('今日赛程'),
          ),
          for (final m in wcs.skip(1))
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: T.elev2,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        N(m.time.contains(' ') ? m.time.split(' ')[1] : m.time,
                            size: 15, weight: FontWeight.w700),
                        Label(m.status ??
                            (m.time.contains(' ') ? m.time.split(' ')[0] : '')),
                      ],
                    ),
                  ),
                  Container(
                      width: 1, height: 36, color: T.line,
                      margin: const EdgeInsets.symmetric(horizontal: 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _miniFlag(m.flagA, 220),
                            const SizedBox(width: 8),
                            Text(m.teamA,
                                style: const TextStyle(
                                    fontSize: 13, color: T.ink)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _miniFlag(m.flagB, 25),
                            const SizedBox(width: 8),
                            Text(m.teamB,
                                style: const TextStyle(
                                    fontSize: 13, color: T.ink)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: T.elev3,
                      border: Border.all(color: T.line),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('提醒',
                        style: TextStyle(fontSize: 11, color: T.inkSub)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _flag(String code, double hue) => Container(
        width: 44, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HSLColor.fromAHSL(1, hue, 0.4, 0.3).toColor(),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(code,
            style: const TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: T.ink)),
      );

  Widget _miniFlag(String code, double hue) => Container(
        width: 22, height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HSLColor.fromAHSL(1, hue, 0.4, 0.3).toColor(),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(code,
            style: const TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: T.ink)),
      );

  Widget _predBar(int pct, String label, Color bg, Color fg) {
    return Expanded(
      flex: pct,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('$pct%',
            style: TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg)),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0x4DFFFFFF);
    for (double y = 0; y < size.height; y += 20) {
      for (double x = 0; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x + 10, y + 10), 1, dot);
      }
    }
    canvas.drawCircle(
      Offset(size.width - 70, 60),
      70,
      Paint()..color = const Color(0x2600FF85),
    );
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) => false;
}
