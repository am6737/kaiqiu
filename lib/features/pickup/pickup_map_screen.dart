// pickup_map_screen.dart — 约球地图 (stylized SVG-like) + 底部抽屉
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/pickup.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../widgets/chip_pill.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';

class PickupMapScreen extends ConsumerStatefulWidget {
  const PickupMapScreen({super.key});

  @override
  ConsumerState<PickupMapScreen> createState() => _PickupMapScreenState();
}

class _PickupMapScreenState extends ConsumerState<PickupMapScreen> {
  String _filter = 'today';
  bool _sheetOpen = true;
  String? _activePin;

  // Extended filter state (opened from the filter icon sheet).
  double _distKm = 5;
  int _maxFee = 100;
  String _level = 'any'; // any/新手/初级/中级/高级

  List<(String, String)> _filterOptions(BuildContext context) {
    final l = context.l10n;
    return [
      ('today', l.pickup_filter_today),
      ('tomorrow', l.pickup_filter_tomorrow),
      ('week', l.pickup_filter_week),
      ('lv', l.pickup_filter_mid),
      ('fee', l.pickup_filter_cheap),
      ('near', l.pickup_filter_near),
    ];
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final l = context.l10n;
    double localDist = _distKm;
    int localFee = _maxFee;
    String localLevel = _level;
    await showModalBottomSheet(
      context: context,
      backgroundColor: T.elev1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: T.inkMute,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.pickup_filter_title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: T.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Label(l.pickup_filter_distance),
                  Slider(
                    value: localDist,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: T.live,
                    label: '${localDist.toInt()} km',
                    onChanged: (v) => setModal(() => localDist = v),
                  ),
                  const SizedBox(height: 8),
                  Label(l.pickup_filter_fee),
                  Slider(
                    value: localFee.toDouble(),
                    min: 0,
                    max: 300,
                    divisions: 30,
                    activeColor: T.live,
                    label: '¥${localFee}',
                    onChanged: (v) => setModal(() => localFee = v.toInt()),
                  ),
                  const SizedBox(height: 14),
                  Label(l.pickup_filter_level),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final lv in [
                        ('any', l.level_any),
                        ('新手', l.level_beginner),
                        ('初级', l.level_novice),
                        ('中级', l.level_mid),
                        ('高级', l.level_pro),
                      ])
                        GestureDetector(
                          onTap: () => setModal(() => localLevel = lv.$1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: localLevel == lv.$1 ? T.liveDim : T.elev2,
                              border: Border.all(
                                color: localLevel == lv.$1 ? T.live : T.line,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              lv.$2,
                              style: TextStyle(
                                fontSize: 12,
                                color: localLevel == lv.$1 ? T.live : T.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: l.pickup_filter_reset,
                          variant: BtnVariant.secondary,
                          size: BtnSize.md,
                          full: true,
                          onPressed: () {
                            setModal(() {
                              localDist = 5;
                              localFee = 100;
                              localLevel = 'any';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          label: l.pickup_filter_apply,
                          variant: BtnVariant.primary,
                          size: BtnSize.md,
                          full: true,
                          onPressed: () {
                            setState(() {
                              _distKm = localDist;
                              _maxFee = localFee;
                              _level = localLevel;
                            });
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(livePickupsProvider);
    return async.when(
      data: (list) => _buildMap(context, list),
      loading: () => const Scaffold(
        backgroundColor: T.bg,
        body: Center(child: CircularProgressIndicator(color: T.live)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: T.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 32, color: T.danger),
                  const SizedBox(height: 8),
                  Text(
                    '${context.l10n.error_load_failed}: $e',
                    style: const TextStyle(fontSize: 13, color: T.inkSub),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => ref.invalidate(livePickupsProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: T.elev3,
                        border: Border.all(color: T.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.common_retry,
                        style: const TextStyle(color: T.ink, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, List<Pickup> pickups) {
    return Scaffold(
      backgroundColor: T.bg,
      body: Stack(
        children: [
          // Stylized map background
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0E1310),
              child: CustomPaint(painter: _MapPainter()),
            ),
          ),
          // Pins
          for (final p in pickups)
            Builder(
              builder: (ctx) {
                final size = MediaQuery.of(ctx).size;
                final lng = p.lng ?? 0.5;
                final lat = p.lat ?? 0.5;
                final x = lng * size.width;
                final y = lat * size.height * 0.7 + 120;
                final isActive = _activePin == p.id;
                final stateKey = switch (p.status) {
                  PickupStatus.full => 'full',
                  PickupStatus.almost => 'almost',
                  _ => 'open',
                };
                final Color statusColor = switch (stateKey) {
                  'almost' => T.warn,
                  'full' => T.inkMute,
                  _ => T.live,
                };
                return Positioned(
                  left: x - 16,
                  top: y - 40,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _activePin = p.id;
                      _sheetOpen = true;
                    }),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isActive ? 40 : 32,
                          height: isActive ? 40 : 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: T.elev1,
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.25),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: SportIcon(
                            Sport.football,
                            size: isActive ? 18 : 14,
                            color: statusColor,
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: -3),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // "You are here" dot
          Positioned(
            left: MediaQuery.of(context).size.width / 2 - 7,
            top: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    blurRadius: 6,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
          // Top bar (gradient fade)
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    T.bg.withValues(alpha: 0.9),
                    T.bg.withValues(alpha: 0),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CircleBtn(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.pickup_map_title_city(LocalStore.city),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: T.ink,
                        ),
                      ),
                      const Spacer(),
                      _CircleBtn(
                        icon: Icons.filter_list,
                        onTap: () => _showFilterSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (ctx) {
                      final filters = _filterOptions(ctx);
                      return SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filters.length,
                          separatorBuilder: (_, i) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            final f = filters[i];
                            return ChipPill(
                              label: f.$2,
                              active: f.$1 == _filter,
                              onTap: () => setState(() => _filter = f.$1),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Legend (right side)
          Positioned(
            right: 14,
            top: 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: T.elev2,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(T.r2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendRow(
                    state: 'open',
                    label: context.l10n.pickup_map_legend_open,
                  ),
                  const SizedBox(height: 6),
                  _LegendRow(
                    state: 'almost',
                    label: context.l10n.pickup_map_legend_almost,
                  ),
                  const SizedBox(height: 6),
                  _LegendRow(
                    state: 'full',
                    label: context.l10n.pickup_map_legend_full,
                  ),
                ],
              ),
            ),
          ),
          // FAB — host a new pickup
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.57,
            child: GestureDetector(
              onTap: () => context.push('/pickup/create'),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.live,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: T.live.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, size: 24, color: Colors.black),
              ),
            ),
          ),
          // Bottom sheet
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: 0,
            height: _sheetOpen ? MediaQuery.of(context).size.height * 0.55 : 80,
            child: Container(
              decoration: const BoxDecoration(
                color: T.elev1,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: T.line, width: 1)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _sheetOpen = !_sheetOpen),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      width: double.infinity,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: T.inkMute,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.pickup_city_pickup_count(pickups.length),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: T.ink,
                          ),
                        ),
                        const Spacer(),
                        Label(context.l10n.pickup_map_sort_distance),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pickups.length,
                      itemBuilder: (_, i) => _MapListRow(
                        item: pickups[i],
                        onTap: () => context.push('/pickup/${pickups[i].id}'),
                      ),
                    ),
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

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: T.elev2,
          shape: BoxShape.circle,
          border: Border.all(color: T.line),
        ),
        child: Icon(icon, size: 16, color: T.ink),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String state;
  final String label;
  const _LegendRow({required this.state, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusDot(state: state),
        const SizedBox(width: 6),
        Label(label),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // background grid
    final grid = Paint()..color = const Color(0x08FFFFFF);
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    // major roads
    final road = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-20, 180)
        ..quadraticBezierTo(120, 200, 260, 140)
        ..quadraticBezierTo(400, 80, size.width + 40, 90),
      road,
    );
    final road2 = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(60, -20)
        ..lineTo(80, 400)
        ..lineTo(140, size.height + 20),
      road2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.8, -20)
        ..lineTo(size.width * 0.65, 400)
        ..lineTo(size.width * 0.72, size.height + 20),
      road2,
    );
    // parks
    final park = Paint()..color = const Color(0x0A00FF85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 230, 110, 80),
        const Radius.circular(4),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 160, 380, 120, 90),
        const Radius.circular(4),
      ),
      park,
    );
    // water band at bottom
    final water = Paint()..color = const Color(0x146496C8);
    canvas.drawPath(
      Path()
        ..moveTo(-20, size.height - 100)
        ..quadraticBezierTo(
          size.width / 2,
          size.height - 120,
          size.width + 20,
          size.height - 90,
        )
        ..lineTo(size.width + 20, size.height)
        ..lineTo(-20, size.height)
        ..close(),
      water,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => false;
}

class _MapListRow extends StatelessWidget {
  final Pickup item;
  final VoidCallback onTap;
  const _MapListRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stateKey = switch (item.status) {
      PickupStatus.full => 'full',
      PickupStatus.almost => 'almost',
      _ => 'open',
    };
    final need = item.displayNeed;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HSLColor.fromAHSL(1, 140, 0.15, 0.22).toColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SportIcon(Sport.football, size: 20, color: T.inkSub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      N(item.displayTime, size: 11, color: T.inkSub),
                      const SizedBox(width: 10),
                      if (item.level != null) Label(item.level!),
                      const SizedBox(width: 10),
                      N(
                        '¥${item.feeYuan.toStringAsFixed(0)}',
                        size: 11,
                        color: T.inkSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusDot(state: stateKey, size: 7),
                const SizedBox(height: 4),
                N(
                  need > 0
                      ? context.l10n.pickup_map_need_short(need)
                      : context.l10n.pickup_map_full_short,
                  size: 12,
                  weight: FontWeight.w600,
                  color: need > 0 ? T.live : T.inkDim,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
