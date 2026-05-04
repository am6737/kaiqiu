// pickup_map_screen.dart — 约球地图 (stylized SVG-like) + 底部抽屉
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/map_pin.dart';
import '../../models/pickup.dart';
import '../../models/venue.dart';
import '../../providers.dart';
import '../../widgets/chip_pill.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/sport_icon.dart';
import '../../widgets/typography.dart';
import '../home/cards/pickup_feed_card.dart';
import 'map/real_map.dart';
import '../../theme/app_tokens.dart';

class PickupMapScreen extends ConsumerStatefulWidget {
  const PickupMapScreen({super.key});

  @override
  ConsumerState<PickupMapScreen> createState() => _PickupMapScreenState();
}

enum _MapMode { pickup, venue }

class _PickupMapScreenState extends ConsumerState<PickupMapScreen> {
  _MapMode _mode = _MapMode.pickup;
  String _filter = 'all';
  String? _activePin;
  bool _sheetExpanded = false;
  final _sheetCtrl = DraggableScrollableController();

  static const _defaultVisibleKeys = {
    'all',
    'today',
    'tomorrow',
    'week',
    'free',
    'lv',
    'fee',
    'near',
  };
  final Set<String> _visibleFilterKeys = Set.of(_defaultVisibleKeys);

  // Venue filter state (symmetric to pickup filter).
  String _venueFilter = 'v_all';
  static const _defaultVisibleVenueKeys = {
    'v_all',
    'v_indoor',
    'v_outdoor',
    'v_football',
    'v_basketball',
    'v_free',
    'v_near',
  };
  final Set<String> _visibleVenueFilterKeys = Set.of(_defaultVisibleVenueKeys);

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
  bool _mapCentered = true;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _acquireLocation();
    _sheetCtrl.addListener(_onSheetChanged);
  }

  Future<void> _acquireLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    // Try cached position first (instant, no GPS fix needed).
    final last = await Geolocator.getLastKnownPosition();
    if (last != null && mounted) {
      setState(() {
        _userLat = last.latitude;
        _userLng = last.longitude;
      });
    }
    // Then try a fresh fix; update if successful.
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _onLocateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _userLat = last.latitude;
          _userLng = last.longitude;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _locateTrigger++;
        _mapCentered = true;
        _isLocating = false;
      });
    }
  }

  String? _distanceTo(Pickup p) {
    if (p.lat == null || p.lng == null) return null;
    final meters = Geolocator.distanceBetween(
      _userLat,
      _userLng,
      p.lat!,
      p.lng!,
    );
    return (meters / 1000).toStringAsFixed(1);
  }

  String? _distanceToPoint(double lat, double lng) {
    final meters = Geolocator.distanceBetween(_userLat, _userLng, lat, lng);
    return (meters / 1000).toStringAsFixed(1);
  }

  void _dismissCard() {
    if (_activePin == null) return;
    setState(() => _activePin = null);
    _sheetCtrl.animateTo(
      0.55,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  double _sheetMinSize(BuildContext context) =>
      60 / MediaQuery.of(context).size.height;

  void _onSheetChanged() {
    if (!_sheetCtrl.isAttached) return;
    final minSize = _sheetMinSize(context);
    if (_activePin != null && _sheetCtrl.size > minSize + 0.01) {
      setState(() => _activePin = null);
    }
    final expanded = _sheetCtrl.size > 0.7;
    if (expanded != _sheetExpanded) {
      setState(() => _sheetExpanded = expanded);
    }
  }

  @override
  void dispose() {
    _sheetCtrl.removeListener(_onSheetChanged);
    _sheetCtrl.dispose();
    super.dispose();
  }

  List<(String, String)> _allFilterOptions(BuildContext context) {
    final l = context.l10n;
    return [
      ('all', l.home_pickup_filter_all),
      ('today', l.pickup_filter_today),
      ('tomorrow', l.pickup_filter_tomorrow),
      ('week', l.pickup_filter_week),
      ('free', l.home_fee_free),
      ('lv', l.pickup_filter_mid),
      ('fee', l.pickup_filter_cheap),
      ('near', l.pickup_filter_near),
    ];
  }

  List<(String, String)> _visibleFilterOptions(BuildContext context) {
    return _allFilterOptions(
      context,
    ).where((f) => f.$1 == 'all' || _visibleFilterKeys.contains(f.$1)).toList();
  }

  List<(String, String)> _allVenueFilterOptions() {
    return const [
      ('v_all', '全部'),
      ('v_indoor', '室内'),
      ('v_outdoor', '室外'),
      ('v_semi', '半室内'),
      ('v_football', '足球'),
      ('v_basketball', '篮球'),
      ('v_badminton', '羽毛球'),
      ('v_free', '免费'),
      ('v_cheap', '低价'),
      ('v_near', '附近'),
      ('v_rated', '高评分'),
    ];
  }

  List<(String, String)> _visibleVenueFilterOptions() {
    return _allVenueFilterOptions()
        .where((f) => f.$1 == 'v_all' || _visibleVenueFilterKeys.contains(f.$1))
        .toList();
  }

  List<Pickup> _filterPickups(List<Pickup> pickups) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));

    return switch (_filter) {
      'today' => pickups.where(
        (p) =>
            !p.startAt.isBefore(todayStart) &&
            p.startAt.isBefore(tomorrowStart),
      ),
      'tomorrow' => pickups.where(
        (p) =>
            !p.startAt.isBefore(tomorrowStart) &&
            p.startAt.isBefore(tomorrowEnd),
      ),
      'week' => pickups.where(
        (p) => !p.startAt.isBefore(todayStart) && p.startAt.isBefore(weekEnd),
      ),
      'free' => pickups.where((p) => p.feeCents == 0),
      'lv' => pickups.where((p) => p.level == '中级'),
      'fee' => pickups.where((p) => p.feeYuan <= _maxFee),
      'near' => pickups.where((p) {
        if (p.lat == null || p.lng == null) return false;
        final m = Geolocator.distanceBetween(
          _userLat,
          _userLng,
          p.lat!,
          p.lng!,
        );
        return m <= _distKm * 1000;
      }),
      _ => pickups,
    }.toList();
  }

  List<Venue> _filterVenues(List<Venue> venues) {
    return switch (_venueFilter) {
      'v_indoor' => venues.where((v) => v.fieldType == VenueFieldType.indoor),
      'v_outdoor' => venues.where((v) => v.fieldType == VenueFieldType.outdoor),
      'v_semi' => venues.where((v) => v.fieldType == VenueFieldType.semi),
      'v_football' => venues.where((v) => v.sportType == 'football'),
      'v_basketball' => venues.where((v) => v.sportType == 'basketball'),
      'v_badminton' => venues.where((v) => v.sportType == 'badminton'),
      'v_free' => venues.where((v) => v.pricePerHourCents == 0),
      'v_cheap' => venues.where((v) => v.pricePerHourCents <= 5000),
      'v_near' => venues.where((v) {
        final m = Geolocator.distanceBetween(_userLat, _userLng, v.lat, v.lng);
        return m <= 3000;
      }),
      'v_rated' => venues.where((v) => v.rating != null && v.rating! >= 4.0),
      _ => venues,
    }.toList();
  }

  void _showFilterChipConfig(BuildContext context) {
    final allOptions = _allFilterOptions(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
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
                    context.l10n.pickup_filter_title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allOptions.where((f) => f.$1 != 'all').map((f) {
                      final selected = _visibleFilterKeys.contains(f.$1);
                      return GestureDetector(
                        onTap: () {
                          setModal(() {
                            setState(() {
                              if (selected) {
                                _visibleFilterKeys.remove(f.$1);
                              } else {
                                _visibleFilterKeys.add(f.$1);
                              }
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.tokens.accentSubtle
                                : context.tokens.elev2,
                            border: Border.all(
                              color: selected
                                  ? context.tokens.accent
                                  : context.tokens.line,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: context.tokens.accent,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                f.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? context.tokens.accent
                                      : context.tokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVenueFilterChipConfig(BuildContext context) {
    final allOptions = _allVenueFilterOptions();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
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
                    '场馆筛选配置',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allOptions.where((f) => f.$1 != 'v_all').map((f) {
                      final selected = _visibleVenueFilterKeys.contains(f.$1);
                      return GestureDetector(
                        onTap: () {
                          setModal(() {
                            setState(() {
                              if (selected) {
                                _visibleVenueFilterKeys.remove(f.$1);
                                if (_venueFilter == f.$1) {
                                  _venueFilter = 'v_all';
                                }
                              } else {
                                _visibleVenueFilterKeys.add(f.$1);
                              }
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? context.tokens.accentSubtle
                                : context.tokens.elev2,
                            border: Border.all(
                              color: selected
                                  ? context.tokens.accent
                                  : context.tokens.line,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: context.tokens.accent,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                f.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? context.tokens.accent
                                      : context.tokens.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                              color: localLevel == lv.$1
                                  ? context.tokens.accentSubtle
                                  : context.tokens.elev2,
                              border: Border.all(
                                color: localLevel == lv.$1
                                    ? context.tokens.accent
                                    : context.tokens.line,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              lv.$2,
                              style: TextStyle(
                                fontSize: 12,
                                color: localLevel == lv.$1
                                    ? context.tokens.accent
                                    : context.tokens.ink,
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
    final pickupsAsync = ref.watch(livePickupsProvider);
    final venuesAsync = ref.watch(liveVenuesProvider);

    if (_mode == _MapMode.venue) {
      return venuesAsync.when(
        data: (venues) => _buildMap(context, const [], venues: venues),
        loading: () => Scaffold(
          backgroundColor: context.tokens.bg,
          body: Center(
            child: CircularProgressIndicator(color: context.tokens.accent),
          ),
        ),
        error: (e, _) =>
            _buildError(context, e, () => ref.invalidate(liveVenuesProvider)),
      );
    }

    return pickupsAsync.when(
      data: (list) => _buildMap(context, list),
      loading: () => Scaffold(
        backgroundColor: context.tokens.bg,
        body: Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
        ),
      ),
      error: (e, _) =>
          _buildError(context, e, () => ref.invalidate(livePickupsProvider)),
    );
  }

  Widget _buildError(BuildContext context, Object e, VoidCallback onRetry) {
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 32,
                  color: context.tokens.danger,
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.l10n.error_load_failed}: $e',
                  style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onRetry,
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
    );
  }

  List<MapPin> _venuesToPins(List<Venue> venues) {
    return venues
        .map(
          (v) => MapPin(
            id: v.id,
            lat: v.lat,
            lng: v.lng,
            label: v.name,
            sublabel: v.sportTypeLabel,
            type: MapPinType.venue,
          ),
        )
        .toList();
  }

  Widget _buildMap(
    BuildContext context,
    List<Pickup> pickups, {
    List<Venue> venues = const [],
  }) {
    final isVenueMode = _mode == _MapMode.venue;
    final filteredVenues = isVenueMode ? _filterVenues(venues) : venues;
    final filteredPickups = isVenueMode ? pickups : _filterPickups(pickups);
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: Stack(
        children: [
          // Real map (AMap on mobile, SVG canvas on web via conditional import).
          Positioned.fill(
            child: RealPickupMap(
              pickups: isVenueMode ? const [] : filteredPickups,
              extraPins: isVenueMode ? _venuesToPins(filteredVenues) : const [],
              activePinId: _activePin,
              locateTrigger: _locateTrigger,
              centerLat: _userLat != _fallbackLat ? _userLat : null,
              centerLng: _userLng != _fallbackLng ? _userLng : null,
              onUserLocationChanged: (pos) {
                if (mounted) {
                  setState(() {
                    _userLat = pos.latitude;
                    _userLng = pos.longitude;
                  });
                }
              },
              onMapPanned: () {
                if (mounted && _mapCentered) {
                  setState(() => _mapCentered = false);
                }
                _dismissCard();
              },
              onPinTap: (id) {
                setState(() => _activePin = id);
                _sheetCtrl.animateTo(
                  _sheetMinSize(context),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              onMapTap: _dismissCard,
            ),
          ),
          // Top bar (gradient fade) — Positioned + mainAxisSize.min so the
          // gradient container only covers the actual bar, leaving the map
          // Platform View free to receive touch/pan gestures.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Mode toggle: 约球 / 场馆
                        _ModeToggle(
                          mode: _mode,
                          onChanged: (m) => setState(() {
                            _mode = m;
                            _activePin = null;
                          }),
                        ),
                        const Spacer(),
                        _CircleBtn(
                          icon: Icons.add,
                          onTap: () => context.push(
                            isVenueMode ? '/venue/create' : '/pickup/create',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CircleBtn(
                          icon: Icons.filter_list,
                          onTap: () => isVenueMode
                              ? _showVenueFilterChipConfig(context)
                              : _showFilterSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (ctx) {
                        final filters = isVenueMode
                            ? _visibleVenueFilterOptions()
                            : _visibleFilterOptions(ctx);
                        final activeKey = isVenueMode ? _venueFilter : _filter;
                        return SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: filters.length,
                                  separatorBuilder: (_, i) =>
                                      const SizedBox(width: 6),
                                  itemBuilder: (_, i) {
                                    final f = filters[i];
                                    return ChipPill(
                                      label: f.$2,
                                      active: f.$1 == activeKey,
                                      onTap: () => setState(() {
                                        if (isVenueMode) {
                                          _venueFilter = f.$1;
                                        } else {
                                          _filter = f.$1;
                                        }
                                      }),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => isVenueMode
                                    ? _showVenueFilterChipConfig(ctx)
                                    : _showFilterChipConfig(ctx),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: context.tokens.elev2,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: context.tokens.line,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.tune,
                                    size: 14,
                                    color: context.tokens.inkSub,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Legend (right side) — only for pickup mode
          if (!isVenueMode)
            Positioned(
              right: 14,
              top: 180,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
            bottom: 100,
            child: GestureDetector(
              onTap: _onLocateMe,
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
                child: _isLocating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.tokens.accent,
                        ),
                      )
                    : Icon(
                        Icons.my_location,
                        size: 20,
                        color: _mapCentered
                            ? context.tokens.accent
                            : context.tokens.ink,
                      ),
              ),
            ),
          ),
          // Bottom sheet
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.55,
            minChildSize: _sheetMinSize(context),
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.55, 1.0],
            builder: (context, scrollController) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final sheetRadius = _sheetExpanded
                  ? BorderRadius.zero
                  : const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    );
              return ClipRRect(
                borderRadius: sheetRadius,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xCC121212)
                          : const Color(0xCCF8F6F3),
                      border: _sheetExpanded
                          ? null
                          : Border(
                              top: BorderSide(
                                color: isDark
                                    ? const Color(0x33FFFFFF)
                                    : const Color(0x55FFFFFF),
                                width: 0.5,
                              ),
                            ),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      isVenueMode
                                          ? '${filteredVenues.length} 个场馆'
                                          : context.l10n
                                                .pickup_city_pickup_count(
                                                  filteredPickups.length,
                                                ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: context.tokens.ink,
                                      ),
                                    ),
                                    const Spacer(),
                                    Label(
                                      context.l10n.pickup_map_sort_distance,
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () {
                                        _sheetCtrl.animateTo(
                                          _sheetExpanded ? 0.55 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      },
                                      child: Icon(
                                        _sheetExpanded
                                            ? Icons.fullscreen_exit
                                            : Icons.fullscreen,
                                        size: 20,
                                        color: context.tokens.inkSub,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isVenueMode)
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _VenueListRow(
                                venue: filteredVenues[i],
                                distanceKm: _distanceToPoint(
                                  filteredVenues[i].lat,
                                  filteredVenues[i].lng,
                                ),
                                onTap: () => context.push(
                                  '/venue/${filteredVenues[i].id}',
                                ),
                              ),
                              childCount: filteredVenues.length,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((_, i) {
                                final p = filteredPickups[i];
                                final dist = _distanceTo(p);
                                return PickupFeedCard(
                                  pickup: p,
                                  distanceKm: dist != null
                                      ? double.tryParse(dist)
                                      : null,
                                  locationAvailable: true,
                                  glass: true,
                                );
                              }, childCount: filteredPickups.length),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Floating pickup card
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: AnimatedSlide(
              offset: _activePin != null ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                opacity: _activePin != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: IgnorePointer(
                  ignoring: _activePin == null,
                  child: Builder(
                    builder: (context) {
                      if (isVenueMode) {
                        final venue = _activePin != null
                            ? filteredVenues
                                  .where((v) => v.id == _activePin)
                                  .firstOrNull
                            : null;
                        if (venue == null) return const SizedBox.shrink();
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _VenueFloatingCard(
                            key: ValueKey(venue.id),
                            venue: venue,
                            distanceKm: _distanceToPoint(venue.lat, venue.lng),
                            onTap: () => context.push('/venue/${venue.id}'),
                          ),
                        );
                      }
                      final pickup = _activePin != null
                          ? filteredPickups
                                .where((p) => p.id == _activePin)
                                .firstOrNull
                          : null;
                      if (pickup == null) return const SizedBox.shrink();
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _PickupFloatingCard(
                          key: ValueKey(pickup.id),
                          pickup: pickup,
                          distanceKm: _distanceTo(pickup),
                          onTap: () => context.push('/pickup/${pickup.id}'),
                        ),
                      );
                    },
                  ),
                ),
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

class _PickupFloatingCard extends StatelessWidget {
  final Pickup pickup;
  final String? distanceKm;
  final VoidCallback onTap;
  const _PickupFloatingCard({
    super.key,
    required this.pickup,
    this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final need = pickup.displayNeed;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.elev2,
          borderRadius: BorderRadius.circular(t.r3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Venue photo or sport icon placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: pickup.venuePhotoUrl != null
                  ? Image.network(
                      pickup.venuePhotoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(t),
                    )
                  : _placeholder(t),
            ),
            const SizedBox(width: 10),
            // Info columns
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pickup.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      pickup.displayTime,
                      pickup.formation,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 11, color: t.inkSub),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '¥${pickup.feeYuan.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: t.inkSub),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me, size: 10, color: t.inkMute),
                        const SizedBox(width: 2),
                        Text(
                          '${distanceKm}km',
                          style: TextStyle(fontSize: 11, color: t.inkMute),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status badge + chevron
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _badge(context, t, need),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 18, color: t.inkMute),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppTokens t) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.elev3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SportIcon(Sport.football, size: 22, color: t.inkSub),
    );
  }

  Widget _badge(BuildContext context, AppTokens t, int needed) {
    final l = context.l10n;
    final Color bg, fg;
    final String text;
    if (needed > 2) {
      bg = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      fg = const Color(0xFF4CAF50);
      text = l.pickup_status_open;
    } else if (needed > 0) {
      bg = t.warn.withValues(alpha: 0.15);
      fg = t.warn;
      text = l.pickup_status_almost;
    } else {
      bg = t.inkMute.withValues(alpha: 0.15);
      fg = t.inkMute;
      text = l.pickup_status_full;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ── Mode toggle (约球 / 场馆) ──

class _ModeToggle extends StatelessWidget {
  final _MapMode mode;
  final ValueChanged<_MapMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: '约球',
            icon: Icons.sports_soccer,
            active: mode == _MapMode.pickup,
            onTap: () => onChanged(_MapMode.pickup),
          ),
          _ModeButton(
            label: '场馆',
            icon: Icons.stadium,
            active: mode == _MapMode.venue,
            onTap: () => onChanged(_MapMode.venue),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? t.accentInk : t.inkSub),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? t.accentInk : t.inkSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Venue list row (bottom sheet) ──

class _VenueListRow extends StatelessWidget {
  final Venue venue;
  final String? distanceKm;
  final VoidCallback onTap;
  const _VenueListRow({
    required this.venue,
    this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.line, width: 1)),
        ),
        child: Row(
          children: [
            // Venue icon
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: venue.coverUrl != null ? null : t.elev3,
                borderRadius: BorderRadius.circular(8),
                image: venue.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(venue.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: venue.coverUrl == null
                  ? Icon(Icons.stadium, size: 20, color: t.inkSub)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        venue.sportTypeLabel,
                        style: TextStyle(fontSize: 11, color: t.accent),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        venue.fieldTypeLabel,
                        style: TextStyle(fontSize: 11, color: t.inkSub),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        venue.pricePerHourCents > 0
                            ? '¥${venue.pricePerHourYuan.toStringAsFixed(0)}/h'
                            : '免费',
                        style: TextStyle(fontSize: 11, color: t.inkSub),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me, size: 10, color: t.inkMute),
                        const SizedBox(width: 2),
                        Text(
                          '${distanceKm}km',
                          style: TextStyle(fontSize: 11, color: t.inkMute),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (venue.rating != null) ...[
              Icon(Icons.star, size: 14, color: const Color(0xFFFFB800)),
              const SizedBox(width: 2),
              Text(
                venue.rating!.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.ink,
                ),
              ),
            ] else
              Icon(Icons.chevron_right, size: 18, color: t.inkMute),
          ],
        ),
      ),
    );
  }
}

// ── Venue floating card ──

class _VenueFloatingCard extends StatelessWidget {
  final Venue venue;
  final String? distanceKm;
  final VoidCallback onTap;
  const _VenueFloatingCard({
    super.key,
    required this.venue,
    this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.elev2,
          borderRadius: BorderRadius.circular(t.r3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: venue.coverUrl != null
                  ? Image.network(
                      venue.coverUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _venuePlaceholder(t),
                    )
                  : _venuePlaceholder(t),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [venue.sportTypeLabel, venue.fieldTypeLabel].join(' · '),
                    style: TextStyle(fontSize: 11, color: t.inkSub),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        venue.pricePerHourCents > 0
                            ? '¥${venue.pricePerHourYuan.toStringAsFixed(0)}/小时'
                            : '免费',
                        style: TextStyle(fontSize: 11, color: t.inkSub),
                      ),
                      if (distanceKm != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me, size: 10, color: t.inkMute),
                        const SizedBox(width: 2),
                        Text(
                          '${distanceKm}km',
                          style: TextStyle(fontSize: 11, color: t.inkMute),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '预约',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right, size: 18, color: t.inkMute),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _venuePlaceholder(AppTokens t) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.elev3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.stadium, size: 22, color: t.inkSub),
    );
  }
}
