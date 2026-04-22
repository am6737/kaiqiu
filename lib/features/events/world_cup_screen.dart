// world_cup_screen.dart — 世界杯专区
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/demo_images.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class WorldCupScreen extends ConsumerWidget {
  const WorldCupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wcs = ref.watch(wcMatchesProvider).valueOrNull ?? const [];
    ref.watch(localStoreProvider);
    final l = context.l10n;
    final focusMatchId = 'wc-focus';

    // Hero uses a real photo backdrop (empty green pitch) with a
    // dark gradient scrim so the title is readable in both themes.
    // All hero text is forced white because it sits over the photo.
    const heroTitleColor = Color(0xFFFFFFFF);
    const heroSubColor = Color(0xCCFFFFFF);
    const heroBtnScrim = Color(0x66000000);

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Hero
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: DemoImages.eventCoverLonggang,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 160),
                  placeholder: (_, _) => Container(color: const Color(0xFF1A1A20)),
                  errorWidget: (_, _, _) => Container(color: const Color(0xFF1A1A20)),
                ),
                // Bottom-up dark scrim for title legibility.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 1.0],
                      colors: [
                        Color(0x33000000),
                        Color(0x66000000),
                        Color(0xCC000000),
                      ],
                    ),
                  ),
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
                          color: heroBtnScrim,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: heroTitleColor,
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
                          color: heroBtnScrim,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.ios_share,
                          size: 16,
                          color: heroTitleColor,
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
                      Label('FIFA 2026', color: context.tokens.accent),
                      const SizedBox(height: 6),
                      Text(
                        l.wc_hero_title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: heroTitleColor,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.wc_hero_sub,
                        style: const TextStyle(fontSize: 13, color: heroSubColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Featured match
          if (wcs.isNotEmpty) ...[
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
              borderRadius: BorderRadius.circular(context.tokens.r3),
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
                          color: context.tokens.accent,
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
                            Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: context.tokens.accentInk,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.wc_btn_watch_live,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.tokens.accentInk,
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
              borderRadius: BorderRadius.circular(context.tokens.r3),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _predBar(context, 62, l.wc_team_argentina_win, context.tokens.accent, context.tokens.accentInk),
                    const SizedBox(width: 8),
                    _predBar(context, 14, l.wc_team_draw, context.tokens.inkMute, context.tokens.ink),
                    const SizedBox(width: 8),
                    _predBar(context, 24, l.wc_team_brazil_win, context.tokens.elev3, context.tokens.ink),
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
          ], // end wcs.isNotEmpty
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
                      borderRadius: BorderRadius.circular(context.tokens.r2),
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
                                  _miniFlag(context, m.flagA ?? '', 220),
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
                                  _miniFlag(context, m.flagB ?? '', 25),
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
                              color: reminded ? context.tokens.accentSubtle : context.tokens.elev3,
                              border: Border.all(
                                color: reminded ? context.tokens.accent : context.tokens.line,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l.wc_btn_remind,
                              style: TextStyle(
                                fontSize: 11,
                                color: reminded ? context.tokens.accent : context.tokens.inkSub,
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

  Widget _flag(BuildContext context, String code, double hue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
    width: 44,
    height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: HSLColor.fromAHSL(1, hue, 0.4, isDark ? 0.3 : 0.65).toColor(),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      code,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: context.tokens.ink,
      ),
    ),
  );
  }

  Widget _miniFlag(BuildContext context, String code, double hue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
    width: 22,
    height: 16,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: HSLColor.fromAHSL(1, hue, 0.4, isDark ? 0.3 : 0.65).toColor(),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(
      code,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: 8,
        fontWeight: FontWeight.w700,
        color: context.tokens.ink,
      ),
    ),
  );
  }

  Widget _predBar(BuildContext context, int pct, String label, Color bg, Color fg) {
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
            fontFamily: context.tokens.fontMono,
            fontFamilyFallback: context.tokens.monoFallbacks,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

