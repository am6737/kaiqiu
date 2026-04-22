// pickup_map_screen.dart — 约球地图 (stylized SVG-like) + 底部抽屉
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/pickup.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../widgets/chip_pill.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';
import 'map/real_map.dart';
import '../../theme/app_tokens.dart';

class PickupMapScreen extends ConsumerStatefulWidget {
  const PickupMapScreen({super.key});

  @override
  ConsumerState<PickupMapScreen> createState() => _PickupMapScreenState();
}

class _PickupMapScreenState extends ConsumerState<PickupMapScreen> {
  String _filter = 'today';
  String? _activePin;
  final _sheetCtrl = DraggableScrollableController();

  // Extended filter state (opened from the filter icon sheet).
  double _distKm = 5;
  int _maxFee = 100;
  String _level = 'any'; // any/新手/初级/中级/高级

  // User location for distance calculation; falls back to 南宁青秀 area.
  static const _fallbackLat = 22.8170;
  static const _fallbackLng = 108.3665;
  double _userLat = _fallbackLat;
  double _userLng = _fallbackLng;
  int _locateTrigger = 0;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation({bool centerMap = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (centerMap && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.pickup_map_location_disabled)),
          );
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever && centerMap && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.pickup_map_location_denied)),
        );
        return;
      }
      if (perm == LocationPermission.denied) return;

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (mounted) {
        setState(() {
          _userLat = current.latitude;
          _userLng = current.longitude;
          if (centerMap) _locateTrigger++;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _distanceTo(Pickup p) {
    if (p.lat == null || p.lng == null) return null;
    final meters = Geolocator.distanceBetween(
      _userLat, _userLng, p.lat!, p.lng!,
    );
    return (meters / 1000).toStringAsFixed(1);
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

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
      backgroundColor: context.tokens.elev1,
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
                        color: context.tokens.inkMute,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.pickup_filter_title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Label(l.pickup_filter_distance),
                  Slider(
                    value: localDist,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: context.tokens.accent,
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
                    activeColor: context.tokens.accent,
                    label: '¥$localFee',
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
                              color: localLevel == lv.$1 ? context.tokens.accentSubtle : context.tokens.elev2,
                              border: Border.all(
                                color: localLevel == lv.$1 ? context.tokens.accent : context.tokens.line,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              lv.$2,
                              style: TextStyle(
                                fontSize: 12,
                                color: localLevel == lv.$1 ? context.tokens.accent : context.tokens.ink,
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
      loading: () => Scaffold(
        backgroundColor: context.tokens.bg,
        body: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.tokens.bg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 32, color: context.tokens.danger),
                  const SizedBox(height: 8),
                  Text(
                    '${context.l10n.error_load_failed}: $e',
                    style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
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
                        color: context.tokens.elev3,
                        border: Border.all(color: context.tokens.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.common_retry,
                        style: TextStyle(color: context.tokens.ink, fontSize: 12),
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
      backgroundColor: context.tokens.bg,
      body: Stack(
        children: [
          // Real map (AMap on mobile, SVG canvas on web via conditional import).
          Positioned.fill(
            child: RealPickupMap(
              pickups: pickups,
              activePinId: _activePin,
              centerLat: _userLat,
              centerLng: _userLng,
              locateTrigger: _locateTrigger,
              onPinTap: (id) {
                setState(() => _activePin = id);
                _sheetCtrl.animateTo(
                  0.55,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
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
                    context.tokens.bg.withValues(alpha: 0.9),
                    context.tokens.bg.withValues(alpha: 0),
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
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      const Spacer(),
                      _CircleBtn(
                        icon: Icons.add,
                        onTap: () => context.push('/pickup/create'),
                      ),
                      const SizedBox(width: 8),
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
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
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
          // Locate-me button
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * 0.55 + 16,
            child: GestureDetector(
              onTap: () => _fetchLocation(centerMap: true),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.tokens.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _locating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.tokens.accent,
                        ),
                      )
                    : Icon(Icons.my_location, size: 20, color: context.tokens.accent),
              ),
            ),
          ),
          // Bottom sheet
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.55,
            minChildSize: 80 / MediaQuery.of(context).size.height,
            maxChildSize: 0.55,
            snap: true,
            snapSizes: const [0.55],
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.tokens.elev1,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.tokens.inkMute,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Row(
                            children: [
                              Text(
                                context.l10n.pickup_city_pickup_count(
                                  pickups.length,
                                ),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.tokens.ink,
                                ),
                              ),
                              const Spacer(),
                              Label(context.l10n.pickup_map_sort_distance),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _MapListRow(
                        item: pickups[i],
                        distanceKm: _distanceTo(pickups[i]),
                        onTap: () => context.push('/pickup/${pickups[i].id}'),
                      ),
                      childCount: pickups.length,
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
          color: context.tokens.elev2,
          shape: BoxShape.circle,
          border: Border.all(color: context.tokens.line),
        ),
        child: Icon(icon, size: 16, color: context.tokens.ink),
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

class _MapListRow extends StatelessWidget {
  final Pickup item;
  final String? distanceKm;
  final VoidCallback onTap;
  const _MapListRow({required this.item, this.distanceKm, required this.onTap});

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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SportIcon(Sport.football, size: 20, color: context.tokens.inkSub),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      N(item.displayTime, size: 11, color: context.tokens.inkSub),
                      const SizedBox(width: 10),
                      if (item.level != null) Label(item.level!),
                      const SizedBox(width: 10),
                      N(
                        '¥${item.feeYuan.toStringAsFixed(0)}',
                        size: 11,
                        color: context.tokens.inkSub,
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.near_me, size: 10, color: context.tokens.inkMute),
                        const SizedBox(width: 2),
                        N(
                          '${distanceKm}km',
                          size: 11,
                          color: context.tokens.inkMute,
                        ),
                      ],
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
                  color: need > 0 ? context.tokens.accent : context.tokens.inkDim,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
