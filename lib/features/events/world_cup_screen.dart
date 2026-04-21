// world_cup_screen.dart — 世界杯专区
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class WorldCupScreen extends ConsumerWidget {
  const WorldCupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wcs = ref.watch(wcMatchesProvider);
    ref.watch(localStoreProvider);
    final l = context.l10n;
    final focusMatchId = 'wc-focus';

    return Scaffold(
      backgroundColor: context.tokens.bg,
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
                top: 12,
                left: 12,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x80000000),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: context.tokens.ink,
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
                    onTap: () => shareText(
                      '${l.events_wc_banner_title} · ${l.events_wc_banner_sub}',
                      subject: l.wc_title,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x80000000),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.ios_share,
                        size: 16,
                        color: context.tokens.ink,
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
                    const Label('FIFA 2026', color: T.live),
                    const SizedBox(height: 6),
                    Text(
                      l.wc_hero_title,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: context.tokens.ink,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.wc_hero_sub,
                      style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Featured match
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Label(l.wc_focus_battle),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: const Color(0x4D00FF85)),
              borderRadius: BorderRadius.circular(T.r3),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const LivePill(),
                    const SizedBox(width: 6),
                    Label(l.wc_focus_halftime(wcs[0].minute ?? '')),
                    const Spacer(),
                    Label(l.wc_focus_watch_count('128K')),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _flag(context, 'AR', 200),
                          const SizedBox(height: 8),
                          Text(
                            l.wc_team_argentina,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        N(
                          '${wcs[0].scoreA ?? 0}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: T.live,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '-',
                          style: TextStyle(color: context.tokens.inkDim, fontSize: 18),
                        ),
                        const SizedBox(width: 8),
                        N(
                          '${wcs[0].scoreB ?? 0}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: context.tokens.ink,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _flag(context, 'BR', 140),
                          const SizedBox(height: 8),
                          Text(
                            l.wc_team_brazil,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        variant: BtnVariant.primary,
                        size: BtnSize.md,
                        full: true,
                        onPressed: () =>
                            context.push('/worldcup/live/$focusMatchId'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.wc_btn_watch_live,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PrimaryButton(
                      variant: BtnVariant.ghost,
                      size: BtnSize.md,
                      onPressed: () =>
                          context.push('/worldcup/predict/$focusMatchId'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gps_fixed, size: 14, color: context.tokens.ink),
                          const SizedBox(width: 6),
                          Text(
                            l.wc_btn_predict,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Prediction bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Label(l.wc_predict_bar_title),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(T.r3),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _predBar(62, l.wc_team_argentina_win, T.live, Colors.black),
                    const SizedBox(width: 8),
                    _predBar(14, l.wc_team_draw, context.tokens.inkMute, context.tokens.ink),
                    const SizedBox(width: 8),
                    _predBar(24, l.wc_team_brazil_win, context.tokens.elev3, context.tokens.ink),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Label(l.wc_team_argentina_win),
                    Label(l.wc_team_draw),
                    Label(l.wc_team_brazil_win),
                  ],
                ),
              ],
            ),
          ),
          // Today's schedule
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Label(l.wc_today_schedule),
          ),
          for (final m in wcs.skip(1))
            Builder(
              builder: (ctx) {
                final mid = 'wc-${m.teamA}-${m.teamB}';
                final reminded = LocalStore.hasReminder(mid);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/worldcup/live/$mid'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(T.r2),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Column(
                            children: [
                              N(
                                m.time.contains(' ')
                                    ? m.time.split(' ')[1]
                                    : m.time,
                                size: 15,
                                weight: FontWeight.w700,
                              ),
                              Label(
                                m.status ??
                                    (m.time.contains(' ')
                                        ? m.time.split(' ')[0]
                                        : ''),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: context.tokens.line,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _miniFlag(context, m.flagA, 220),
                                  const SizedBox(width: 8),
                                  Text(
                                    m.teamA,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.tokens.ink,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _miniFlag(context, m.flagB, 25),
                                  const SizedBox(width: 8),
                                  Text(
                                    m.teamB,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.tokens.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final repo = ref.read(remindersRepoProvider);
                            if (LocalStore.hasReminder(mid)) {
                              await repo.cancel(mid);
                            } else {
                              await repo.schedule(
                                matchId: mid,
                                remindAt: DateTime.now().add(
                                  const Duration(hours: 1),
                                ),
                              );
                            }
                            if (context.mounted) {
                              showToast(
                                context,
                                LocalStore.hasReminder(mid)
                                    ? l.wc_remind_set
                                    : l.wc_remind_unset,
                                success: true,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: reminded ? T.liveDim : context.tokens.elev3,
                              border: Border.all(
                                color: reminded ? T.live : context.tokens.line,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l.wc_btn_remind,
                              style: TextStyle(
                                fontSize: 11,
                                color: reminded ? T.live : context.tokens.inkSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _flag(BuildContext context, String code, double hue) => Container(
    width: 44,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: HSLColor.fromAHSL(1, hue, 0.4, 0.3).toColor(),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      code,
      style: TextStyle(
        fontFamily: T.fontMono,
        fontFamilyFallback: T.monoFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.tokens.ink,
      ),
    ),
  );

  Widget _miniFlag(BuildContext context, String code, double hue) => Container(
    width: 22,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: HSLColor.fromAHSL(1, hue, 0.4, 0.3).toColor(),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(
      code,
      style: TextStyle(
        fontFamily: T.fontMono,
        fontFamilyFallback: T.monoFallbacks,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        color: context.tokens.ink,
      ),
    ),
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
        child: Text(
          '$pct%',
          style: TextStyle(
            fontFamily: T.fontMono,
            fontFamilyFallback: T.monoFallbacks,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
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
