// player_archive_screen.dart — 我的球员档案 (deep page)
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../theme/tokens.dart';
import '../../utils/share_helper.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

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
    final MockUser u =
        ref.watch(myProfileProvider).valueOrNull ?? ref.watch(userProvider);
    final teammates = ref.watch(teammatesProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        bottom: false,
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
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 22,
                        color: T.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.profile_archive_title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: T.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => shareProfile(u),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.ios_share, size: 18, color: T.inkSub),
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
                  Avatar(u.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: T.ink,
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
                                color: T.liveDim,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0x6600FF85),
                                ),
                              ),
                              child: Text(
                                u.position,
                                style: const TextStyle(
                                  fontFamily: T.fontMono,
                                  fontFamilyFallback: T.monoFallbacks,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: T.live,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Label(
                              '${u.positionFull} · ${u.city} ${u.district}',
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
                                child: _CardBack(u: u),
                              )
                            : _CardFront(u: u),
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
                        value: '${u.stats.matches}',
                      ),
                      const SizedBox(width: 8),
                      _StatTile(
                        label: context.l10n.profile_mini_goals,
                        value: '${u.stats.goals}',
                      ),
                      const SizedBox(width: 8),
                      _StatTile(label: '助攻', value: '${u.stats.assists}'),
                      const SizedBox(width: 8),
                      _StatTile(
                        label: context.l10n.profile_mini_mvp,
                        value: '${u.stats.mvp}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: T.elev2,
                      border: Border.all(color: T.line),
                      borderRadius: BorderRadius.circular(T.r2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Label(context.l10n.archive_goal_trend),
                            const Spacer(),
                            const N(
                              '+28%',
                              size: 11,
                              color: T.live,
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          width: double.infinity,
                          child: CustomPaint(painter: _TrendPainter()),
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
                      Label(context.l10n.archive_honors_count(u.honors.length)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < u.honors.length; i++)
                    _HonorTile(honor: u.honors[i], isGold: i == 0),
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
                        Label(context.l10n
                            .archive_teammates_sub(teammates.length)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: teammates.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 12),
                      padding: const EdgeInsets.only(right: 16),
                      itemBuilder: (_, i) {
                        final t = teammates[i];
                        return Column(
                          children: [
                            Avatar(t.name, size: 46),
                            const SizedBox(height: 5),
                            Text(
                              t.name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: T.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Label(context.l10n.archive_teammates_matches(t.matches)),
                          ],
                        );
                      },
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
                  Label(context.l10n.archive_history_title),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: T.elev2,
                      border: Border.all(color: T.line),
                      borderRadius: BorderRadius.circular(T.r2),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < history.length; i++)
                          _HistoryRow(match: history[i], isFirst: i == 0),
                      ],
                    ),
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

// ─────────────────────────────────────────────────────────────
// Card front / back (ported as-is)
// ─────────────────────────────────────────────────────────────
class _CardFront extends StatelessWidget {
  final MockUser u;
  const _CardFront({required this.u});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, 150, 0.15, 0.24).toColor(),
            HSLColor.fromAHSL(1, 150, 0.15, 0.12).toColor(),
            HSLColor.fromAHSL(1, 150, 0.3, 0.16).toColor(),
          ],
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r4),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CardDotsPainter())),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: T.live),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Label(context.l10n.archive_card_profile, color: T.live),
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
                  color: T.live,
                ),
                Row(
                  children: [
                    Label(context.l10n.archive_card_overall, color: T.live),
                    const SizedBox(width: 6),
                    Container(width: 10, height: 1, color: T.live),
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
                  colors: [
                    HSLColor.fromAHSL(1, 150, 0.2, 0.28).toColor(),
                    HSLColor.fromAHSL(1, 150, 0.2, 0.18).toColor(),
                  ],
                ),
                border: Border.all(color: T.lineStrong),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ScanLinesPainter()),
                  ),
                  const Center(
                    child: Text(
                      'PLAYER\nPORTRAIT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: T.fontMono,
                        fontFamilyFallback: T.monoFallbacks,
                        fontSize: 11,
                        color: T.inkDim,
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
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: T.ink,
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: T.line, width: 1)),
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
            ? const BoxDecoration(
                border: Border(left: BorderSide(color: T.line, width: 1)),
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
  final MockUser u;
  const _CardBack({required this.u});

  @override
  Widget build(BuildContext context) {
    final entries = u.attrs.entries.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, 150, 0.15, 0.18).toColor(),
            HSLColor.fromAHSL(1, 150, 0.15, 0.10).toColor(),
          ],
        ),
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) => Row(
              children: [
                Label(context.l10n.archive_radar_title, color: T.live),
                const Spacer(),
                Label(context.l10n.archive_radar_flip_back),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _RadarPainter(u.attrs),
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
                    color: T.elev2,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Label(e.key)),
                      Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: T.elev3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: e.value / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: e.value >= 80
                                  ? T.live
                                  : e.value >= 60
                                  ? T.ink
                                  : T.inkSub,
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
                        color: e.value >= 80 ? T.live : T.ink,
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
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0F00FF85);
    for (double y = 0; y < size.height; y += 10) {
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawCircle(Offset(x + 3, y + 3), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardDotsPainter old) => false;
}

class _ScanLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinesPainter old) => false;
}

class _RadarPainter extends CustomPainter {
  final Map<String, int> attrs;
  _RadarPainter(this.attrs);

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
      ..color = const Color(0x14FFFFFF)
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
      ..color = const Color(0x0FFFFFFF)
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
    canvas.drawPath(dataPath, Paint()..color = T.live.withValues(alpha: 0.15));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = T.live
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final pt2 = Paint()..color = T.live;
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
          style: const TextStyle(
            color: T.inkSub,
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
  bool shouldRepaint(covariant _RadarPainter old) => old.attrs != attrs;
}

class _TrendPainter extends CustomPainter {
  static const _data = [2, 3, 5, 4, 6, 8, 7, 9, 6, 8, 11, 10];

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = _data.reduce(math.max).toDouble();
    final points = <Offset>[];
    for (int i = 0; i < _data.length; i++) {
      final x = 8 + (i * (size.width - 16)) / (_data.length - 1);
      final y = size.height - (_data[i] / maxV) * (size.height - 10) - 4;
      points.add(Offset(x, y));
    }

    final areaPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (final p in points.skip(1)) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.lineTo(points.first.dx, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()..color = T.live.withValues(alpha: 0.10));

    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = T.live
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final dotPaint = Paint()..color = T.live;
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], i == points.length - 1 ? 3 : 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// Helpers (ported as-is)
// ─────────────────────────────────────────────────────────────
class _RatingPanel extends StatelessWidget {
  const _RatingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, 150, 0.25, 0.20).toColor(),
            HSLColor.fromAHSL(1, 150, 0.10, 0.14).toColor(),
          ],
        ),
        border: Border.all(color: const Color(0x6600FF85)),
        borderRadius: BorderRadius.circular(T.r3),
      ),
      child: Row(
        children: [
          const _RatingBadge(score: 8.74),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(context.l10n.archive_rating_panel_title, color: T.live),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  children: [
                    _StatMini(
                      label: context.l10n.archive_rating_rated,
                      value: '486',
                      color: T.ink,
                    ),
                    _StatMini(
                      label: context.l10n.archive_rating_rank,
                      value: '#1',
                      color: T.live,
                    ),
                    _StatMini(
                      label: context.l10n.archive_rating_trend,
                      value: '+0.12',
                      color: T.live,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PrimaryButton(
            label: context.l10n.archive_rating_go_rate,
            variant: BtnVariant.primary,
            size: BtnSize.sm,
            onPressed: () => GoRouter.of(context).push('/rate/$demoMatchId'),
          ),
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
        ? T.live
        : score >= 6
        ? T.ink
        : T.danger;
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: T.elev2,
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
            style: const TextStyle(
              fontFamily: T.fontMono,
              fontFamilyFallback: T.monoFallbacks,
              fontSize: 10,
              color: T.inkDim,
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
        Text('$label ', style: const TextStyle(fontSize: 12, color: T.inkSub)),
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
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r2),
        ),
        child: Column(
          children: [
            N(value, size: 22, weight: FontWeight.w800, color: T.ink),
            const SizedBox(height: 2),
            Label(label),
          ],
        ),
      ),
    );
  }
}

class _HonorTile extends StatelessWidget {
  final MockHonor honor;
  final bool isGold;
  const _HonorTile({required this.honor, required this.isGold});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.elev2,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r2),
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
              color: isGold ? null : T.elev3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: T.line),
            ),
            child: Icon(
              Icons.emoji_events,
              size: 18,
              color: isGold ? Colors.black : T.inkSub,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honor.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: T.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Label('${honor.year} · ${honor.meta}'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: T.inkDim),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryMatch match;
  final bool isFirst;
  const _HistoryRow({required this.match, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final Color scoreColor;
    if (match.score.contains('胜')) {
      scoreColor = T.live;
    } else if (match.score.contains('负')) {
      scoreColor = T.warn;
    } else {
      scoreColor = T.inkSub;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(top: BorderSide(color: T.line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 36, child: N(match.date, size: 11, color: T.inkSub)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      match.opp,
                      style: const TextStyle(
                        fontSize: 13,
                        color: T.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (match.mvp) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: T.warnDim,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text(
                          'MVP',
                          style: TextStyle(
                            fontFamily: T.fontMono,
                            fontFamilyFallback: T.monoFallbacks,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: T.warn,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Label(match.event),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              N(
                match.score,
                size: 13,
                weight: FontWeight.w700,
                color: scoreColor,
              ),
              if (match.goals + match.assists > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (match.goals > 0)
                        context.l10n.archive_history_goals_n(match.goals),
                      if (match.assists > 0)
                        context.l10n.archive_history_assists_n(match.assists),
                    ].join(' · '),
                    style: const TextStyle(
                      fontFamily: T.fontMono,
                      fontFamilyFallback: T.monoFallbacks,
                      fontSize: 10,
                      color: T.inkSub,
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
