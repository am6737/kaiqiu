// player_archive_screen.dart — 我的球员档案 (deep page)
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/match_history.dart';
import '../../models/player_profile.dart';
import '../../providers.dart';
import '../../utils/share_helper.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../theme/app_tokens.dart';

class PlayerArchiveScreen extends ConsumerStatefulWidget {
  const PlayerArchiveScreen({super.key});

  @override
  ConsumerState<PlayerArchiveScreen> createState() =>
      _PlayerArchiveScreenState();
}

class _PlayerArchiveScreenState extends ConsumerState<PlayerArchiveScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool get _flipped => _flip.value > 0.5;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_flipped) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlayerProfile? u = ref.watch(myProfileProvider).valueOrNull;
    final teammatesAsync = ref.watch(teammatesProvider);
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.tokens.accent,
          backgroundColor: context.tokens.elev1,
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(teammatesProvider);
            ref.invalidate(historyProvider);
            ref.invalidate(latestUnratedMatchProvider);
          },
          child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // Top bar with back + title + share
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 22,
                        color: context.tokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.profile_archive_title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.tokens.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (u != null) shareProfile(u);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.ios_share, size: 18, color: context.tokens.inkSub),
                    ),
                  ),
                ],
              ),
            ),
            // Identity strip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Avatar(u?.name ?? '新球友', size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u?.name ?? '新球友',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.tokens.accentSubtle,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: context.tokens.accent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                u?.position ?? '',
                                style: TextStyle(
                                  fontFamily: context.tokens.fontMono,
                                  fontFamilyFallback: context.tokens.monoFallbacks,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: context.tokens.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Label(
                              '${u?.positionFull ?? ''} · ${u?.city ?? ''} ${u?.district ?? ''}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    label: context.l10n.common_edit,
                    variant: BtnVariant.ghost,
                    size: BtnSize.sm,
                    onPressed: () => context.push('/profile/edit'),
                  ),
                ],
              ),
            ),
            // 3D flip card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _toggle,
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (_, c) {
                    final t = _flip.value * math.pi;
                    final showBack = _flip.value > 0.5;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(t),
                      child: SizedBox(
                        height: 380,
                        child: showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(math.pi),
                                child: _CardBack(u: u ?? PlayerProfile.empty),
                              )
                            : _CardFront(u: u ?? PlayerProfile.empty),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: AnimatedBuilder(
                animation: _flip,
                builder: (_, c) => Label(
                  _flipped
                      ? context.l10n.archive_flip_front
                      : context.l10n.archive_flip_back,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _RatingPanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Label(context.l10n.archive_season_data),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StatTile(
                        label: context.l10n.profile_mini_matches,
                        value: '${u?.stats.matches ?? 0}',
                      ),
                      const SizedBox(width: 8),
                      _StatTile(
                        label: context.l10n.profile_mini_goals,
                        value: '${u?.stats.goals ?? 0}',
                      ),
                      const SizedBox(width: 8),
                      _StatTile(label: '助攻', value: '${u?.stats.assists ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...historyAsync.when(
                          data: (history) {
                            final trendData = _goalTrendFromHistory(history);
                            final trendLabel = _trendPercent(trendData);
                            return [
                              Row(
                                children: [
                                  Label(context.l10n.archive_goal_trend),
                                  const Spacer(),
                                  if (trendLabel.isNotEmpty)
                                    N(
                                      trendLabel,
                                      size: 11,
                                      color: context.tokens.accent,
                                      weight: FontWeight.w600,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 60,
                                width: double.infinity,
                                child: trendData.isEmpty
                                    ? const SizedBox.shrink()
                                    : CustomPaint(
                                        painter: _TrendPainter(
                                          data: trendData,
                                          accentColor: context.tokens.accent,
                                        ),
                                      ),
                              ),
                            ];
                          },
                          loading: () => [const SizedBox(height: 68)],
                          error: (_, _) => [const SizedBox.shrink()],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Label(context.l10n.archive_honors_title),
                      const Spacer(),
                      Label(context.l10n.archive_honors_count(u?.honors.length ?? 0)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < (u?.honors.length ?? 0); i++)
                    _HonorTile(honor: u!.honors[i], isGold: i == 0),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      children: [
                        Label(context.l10n.archive_teammates_title),
                        const Spacer(),
                        Label(
                          context.l10n.archive_teammates_sub(
                            teammatesAsync.valueOrNull?.length ?? 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...teammatesAsync.when(
                    data: (teammates) => [
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: teammates.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          padding: const EdgeInsets.only(right: 16),
                          itemBuilder: (_, i) {
                            final t = teammates[i];
                            return Column(
                              children: [
                                Avatar(t.name, size: 46),
                                const SizedBox(height: 5),
                                Text(
                                  t.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.tokens.ink,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Label(
                                  context.l10n.archive_teammates_matches(t.matches),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    loading: () => [const SizedBox(height: 90)],
                    error: (_, __) => [const SizedBox.shrink()],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Label(context.l10n.archive_history_title),
                  const SizedBox(height: 10),
                  ...historyAsync.when(
                    data: (history) => [
                      Container(
                        decoration: BoxDecoration(
                          color: context.tokens.elev2,
                          border: Border.all(color: context.tokens.line),
                          borderRadius: BorderRadius.circular(context.tokens.r2),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < history.length; i++)
                              _HistoryRow(match: history[i], isFirst: i == 0),
                          ],
                        ),
                      ),
                    ],
                    loading: () => [const SizedBox(height: 60)],
                    error: (_, __) => [const SizedBox.shrink()],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Card front / back (ported as-is)
// ─────────────────────────────────────────────────────────────
class _CardFront extends StatelessWidget {
  final PlayerProfile u;
  const _CardFront({required this.u});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  HSLColor.fromAHSL(1, 150, 0.15, 0.24).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.15, 0.12).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.3, 0.16).toColor(),
                ]
              : [
                  HSLColor.fromAHSL(1, 150, 0.12, 0.95).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.10, 0.92).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.15, 0.90).toColor(),
                ],
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r4),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CardDotsPainter(
            color: isDark ? const Color(0x0F00FF85) : context.tokens.accent.withValues(alpha: 0.08),
          ))),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: context.tokens.accent),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Label(context.l10n.archive_card_profile, color: context.tokens.accent),
            ),
          ),
          Positioned(
            top: 50,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                N(
                  '${u.rating}',
                  size: 64,
                  weight: FontWeight.w800,
                  color: context.tokens.accent,
                ),
                Row(
                  children: [
                    Label(context.l10n.archive_card_overall, color: context.tokens.accent),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 1, color: context.tokens.accent),
                    const SizedBox(width: 6),
                    Label(u.position),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            right: 14,
            child: Container(
              width: 140,
              height: 170,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          HSLColor.fromAHSL(1, 150, 0.2, 0.28).toColor(),
                          HSLColor.fromAHSL(1, 150, 0.2, 0.18).toColor(),
                        ]
                      : [
                          HSLColor.fromAHSL(1, 150, 0.10, 0.88).toColor(),
                          HSLColor.fromAHSL(1, 150, 0.10, 0.84).toColor(),
                        ],
                ),
                border: Border.all(color: context.tokens.lineStrong),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ScanLinesPainter(
                      color: isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000),
                    )),
                  ),
                  Center(
                    child: Text(
                      'PLAYER\nPORTRAIT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                        fontSize: 11,
                        color: context.tokens.inkDim,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 84,
            child: Text(
              u.name.toUpperCase(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: context.tokens.ink,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: Row(
                children: [
                  _CardStat(k: '身高', v: '${u.height}'),
                  _CardStat(k: '脚', v: u.foot, border: true),
                  _CardStat(
                    k: context.l10n.profile_mini_matches,
                    v: '${u.stats.matches}',
                    border: true,
                  ),
                  _CardStat(
                    k: context.l10n.profile_mini_goals,
                    v: '${u.stats.goals}',
                    border: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  final String k, v;
  final bool border;
  const _CardStat({required this.k, required this.v, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: border ? const EdgeInsets.only(left: 10) : null,
        decoration: border
            ? BoxDecoration(
                border: Border(left: BorderSide(color: context.tokens.line, width: 1)),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Label(k, size: 9),
            const SizedBox(height: 2),
            N(v, size: 14, weight: FontWeight.w700),
          ],
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final PlayerProfile u;
  const _CardBack({required this.u});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = u.attrs.entries.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  HSLColor.fromAHSL(1, 150, 0.15, 0.18).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.15, 0.10).toColor(),
                ]
              : [
                  HSLColor.fromAHSL(1, 150, 0.10, 0.94).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.10, 0.90).toColor(),
                ],
        ),
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) => Row(
              children: [
                Label(context.l10n.archive_radar_title, color: context.tokens.accent),
                const Spacer(),
                Label(context.l10n.archive_radar_flip_back),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _RadarPainter(u.attrs,
                labelColor: context.tokens.inkSub,
                accentColor: context.tokens.accent,
                gridColor: isDark ? const Color(0x14FFFFFF) : const Color(0x14000000),
                axisColor: isDark ? const Color(0x0FFFFFFF) : const Color(0x0F000000),
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3.8,
            children: [
              for (final e in entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Label(e.key)),
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: context.tokens.elev3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: e.value / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: e.value >= 80
                                  ? context.tokens.accent
                                  : e.value >= 60
                                  ? context.tokens.ink
                                  : context.tokens.inkSub,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      N(
                        '${e.value}',
                        size: 12,
                        weight: FontWeight.w700,
                        color: e.value >= 80 ? context.tokens.accent : context.tokens.ink,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardDotsPainter extends CustomPainter {
  final Color color;
  const _CardDotsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double y = 0; y < size.height; y += 10) {
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawCircle(Offset(x + 3, y + 3), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardDotsPainter old) => old.color != color;
}

class _ScanLinesPainter extends CustomPainter {
  final Color color;
  const _ScanLinesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinesPainter old) => old.color != color;
}

class _RadarPainter extends CustomPainter {
  final Map<String, int> attrs;
  final Color labelColor;
  final Color accentColor;
  final Color gridColor;
  final Color axisColor;
  _RadarPainter(this.attrs, {required this.labelColor, required this.accentColor, required this.gridColor, required this.axisColor});

  @override
  void paint(Canvas canvas, Size size) {
    final keys = attrs.keys.toList();
    final n = keys.length;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 20;

    double angle(int i) => 2 * math.pi * i / n - math.pi / 2;
    Offset pt(int i, double v) => Offset(
      cx + math.cos(angle(i)) * r * (v / 100),
      cy + math.sin(angle(i)) * r * (v / 100),
    );

    final ring = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final p = Offset(
          cx + math.cos(angle(i)) * r * f,
          cy + math.sin(angle(i)) * r * f,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ring);
    }

    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 0.5;
    for (int i = 0; i < n; i++) {
      final p = pt(i, 100);
      canvas.drawLine(Offset(cx, cy), p, axis);
    }

    final dataPath = Path();
    for (int i = 0; i < n; i++) {
      final p = pt(i, attrs[keys[i]]!.toDouble());
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = accentColor.withValues(alpha: 0.15));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final pt2 = Paint()..color = accentColor;
    for (int i = 0; i < n; i++) {
      canvas.drawCircle(pt(i, attrs[keys[i]]!.toDouble()), 2.5, pt2);
    }

    for (int i = 0; i < n; i++) {
      final pos = Offset(
        cx + math.cos(angle(i)) * (r + 14),
        cy + math.sin(angle(i)) * (r + 14),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: keys[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.attrs != attrs || old.labelColor != labelColor || old.accentColor != accentColor || old.gridColor != gridColor || old.axisColor != axisColor;
}

class _TrendPainter extends CustomPainter {
  final List<int> data;
  final Color accentColor;
  _TrendPainter({required this.data, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = data.reduce(math.max).toDouble();
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = 8 + (i * (size.width - 16)) / (data.length - 1);
      final y = size.height - (data[i] / maxV) * (size.height - 10) - 4;
      points.add(Offset(x, y));
    }

    final areaPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (final p in points.skip(1)) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.lineTo(points.first.dx, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()..color = accentColor.withValues(alpha: 0.10));

    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final dotPaint = Paint()..color = accentColor;
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i == points.length - 1 ? 3 : 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => old.data != data || old.accentColor != accentColor;
}

// ─────────────────────────────────────────────────────────────
// Helpers (ported as-is)
// ─────────────────────────────────────────────────────────────
class _RatingPanel extends ConsumerWidget {
  const _RatingPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final matchId = ref.watch(latestUnratedMatchProvider).valueOrNull;
    final score = profile != null && profile.rating > 0
        ? profile.rating.toDouble()
        : 0.0;
    final matches = profile?.stats.matches ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  HSLColor.fromAHSL(1, 150, 0.25, 0.20).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.10, 0.14).toColor(),
                ]
              : [
                  HSLColor.fromAHSL(1, 150, 0.18, 0.94).toColor(),
                  HSLColor.fromAHSL(1, 150, 0.10, 0.90).toColor(),
                ],
        ),
        border: Border.all(color: context.tokens.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Row(
        children: [
          _RatingBadge(score: score),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(context.l10n.archive_rating_panel_title, color: context.tokens.accent),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  children: [
                    _StatMini(
                      label: context.l10n.archive_rating_rated,
                      value: '$matches',
                      color: context.tokens.ink,
                    ),
                    _StatMini(
                      label: context.l10n.archive_rating_trend,
                      value: score > 0 ? score.toStringAsFixed(2) : '—',
                      color: context.tokens.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (matchId != null) ...[
            const SizedBox(width: 10),
            PrimaryButton(
              label: context.l10n.archive_rating_go_rate,
              variant: BtnVariant.primary,
              size: BtnSize.sm,
              onPressed: () => GoRouter.of(context).push('/rate/$matchId'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double score;
  const _RatingBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final c = score >= 8
        ? context.tokens.accent
        : score >= 6
        ? context.tokens.ink
        : context.tokens.danger;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: c.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          N(
            score.toStringAsFixed(1),
            size: 22,
            weight: FontWeight.w800,
            color: c,
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.event_tab_ratings,
            style: TextStyle(
              fontFamily: context.tokens.fontMono,
              fontFamilyFallback: context.tokens.monoFallbacks,
              fontSize: 10,
              color: context.tokens.inkDim,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatMini({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 12, color: context.tokens.inkSub)),
        N(value, size: 12, weight: FontWeight.w700, color: color),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  const _StatTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Column(
          children: [
            N(value, size: 22, weight: FontWeight.w800, color: context.tokens.ink),
            const SizedBox(height: 2),
            Label(label),
          ],
        ),
      ),
    );
  }
}

List<int> _goalTrendFromHistory(List<MatchHistoryEntry> history) {
  if (history.isEmpty) return [];
  final sorted = [...history]..sort((a, b) => a.playedAt.compareTo(b.playedAt));
  final buckets = <String, int>{};
  for (final m in sorted) {
    final key = '${m.playedAt.year}-${m.playedAt.month.toString().padLeft(2, '0')}';
    buckets[key] = (buckets[key] ?? 0) + m.myGoals;
  }
  return buckets.values.toList();
}

String _trendPercent(List<int> data) {
  if (data.length < 2) return '';
  final recent = data.last;
  final prev = data[data.length - 2];
  if (prev == 0) return recent > 0 ? '+$recent' : '';
  final pct = ((recent - prev) / prev * 100).round();
  return pct >= 0 ? '+$pct%' : '$pct%';
}

class _HonorTile extends StatelessWidget {
  final PlayerHonor honor;
  final bool isGold;
  const _HonorTile({required this.honor, required this.isGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isGold
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                    )
                  : null,
              color: isGold ? null : context.tokens.elev3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.tokens.line),
            ),
            child: Icon(
              Icons.emoji_events,
              size: 18,
              color: isGold ? Colors.black : context.tokens.inkSub,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honor.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Label('${honor.year}${honor.meta != null ? ' · ${honor.meta}' : ''}'),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 14, color: context.tokens.inkDim),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final MatchHistoryEntry match;
  final bool isFirst;
  const _HistoryRow({required this.match, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final scoreStr = match.score;
    final won = match.scoreA > match.scoreB;
    final lost = match.scoreA < match.scoreB;
    final Color scoreColor;
    if (won) {
      scoreColor = context.tokens.accent;
    } else if (lost) {
      scoreColor = context.tokens.warn;
    } else {
      scoreColor = context.tokens.inkSub;
    }
    final dateStr =
        '${match.playedAt.month.toString().padLeft(2, '0')}-${match.playedAt.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 36, child: N(dateStr, size: 11, color: context.tokens.inkSub)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match.teamA} vs ${match.teamB}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Label(match.eventName),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              N(
                scoreStr,
                size: 13,
                weight: FontWeight.w700,
                color: scoreColor,
              ),
              if (match.myGoals + match.myAssists > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (match.myGoals > 0)
                        context.l10n.archive_history_goals_n(match.myGoals),
                      if (match.myAssists > 0)
                        context.l10n.archive_history_assists_n(match.myAssists),
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: context.tokens.fontMono,
                      fontFamilyFallback: context.tokens.monoFallbacks,
                      fontSize: 10,
                      color: context.tokens.inkSub,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
