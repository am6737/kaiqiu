import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../services/local_storage.dart';
import '../../services/location.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';
import 'city_data.dart';

class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';

  // GPS state
  bool _gpsLoading = true;
  CityInfo? _gpsCity;
  bool _gpsFailed = false;

  // Region keys for scroll-to
  final _regionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    for (final r in kRegionOrder) {
      _regionKeys[r] = GlobalKey();
    }
    _locateCity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _locateCity() async {
    setState(() {
      _gpsLoading = true;
      _gpsFailed = false;
      _gpsCity = null;
    });
    final pos = await LocationService().currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _gpsLoading = false;
        _gpsFailed = true;
      });
      return;
    }
    final city = findNearestCity(pos.latitude, pos.longitude);
    setState(() {
      _gpsLoading = false;
      _gpsCity = city;
      _gpsFailed = false;
    });
  }

  Future<void> _pick(String city) async {
    await LocalStore.setCity(city);
    if (mounted) context.pop();
  }

  void _scrollToRegion(String region) {
    final key = _regionKeys[region];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = LocalStore.city;
    final searchResults = searchCities(_query);
    final isSearching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 40, right: 40),
              children: [
                PageTitleBar(
                  title: l.city_picker_title,
                  onBack: () => context.pop(),
                ),
                // GPS card
                _GpsCard(
                  loading: _gpsLoading,
                  city: _gpsCity,
                  failed: _gpsFailed,
                  onUse: () {
                    if (_gpsCity != null) _pick(_gpsCity!.name);
                  },
                  onRetry: _locateCity,
                ),
                const SizedBox(height: 14),
                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: l.city_picker_search_hint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: isSearching
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: context.tokens.elev2,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (isSearching) ...[
                  if (searchResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          l.city_picker_no_result,
                          style: TextStyle(color: context.tokens.inkSub, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    for (final c in searchResults)
                      _CityRow(
                        city: c,
                        active: c.name == current,
                        currentLabel: l.city_picker_current_label,
                        onTap: () => _pick(c.name),
                      ),
                ] else ...[
                  // Recent cities
                  _RecentSection(
                    current: current,
                    onPick: _pick,
                  ),
                  // Hot cities
                  SectionHeader(title: l.city_picker_hot),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in kHotCityNames)
                          _CityChip(
                            label: name,
                            active: name == current,
                            onTap: () => _pick(name),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // All cities by region
                  for (final region in kRegionOrder) ...[
                    _RegionHeader(key: _regionKeys[region], title: region),
                    for (final c in citiesByRegion[region]!)
                      _CityRow(
                        city: c,
                        active: c.name == current,
                        currentLabel: l.city_picker_current_label,
                        onTap: () => _pick(c.name),
                      ),
                  ],
                ],
              ],
            ),

            // Region index sidebar (only when not searching)
            if (!isSearching)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _RegionIndexBar(
                  regions: kRegionOrder,
                  onTap: _scrollToRegion,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// GPS Card
// ──────────────────────────────────────────────────────────────

class _GpsCard extends StatelessWidget {
  final bool loading;
  final CityInfo? city;
  final bool failed;
  final VoidCallback onUse;
  final VoidCallback onRetry;

  const _GpsCard({
    required this.loading,
    required this.city,
    required this.failed,
    required this.onUse,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isGrey = failed || (city == null && !loading);

    return GestureDetector(
      onTap: failed ? onRetry : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isGrey
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [context.tokens.accent, context.tokens.accent.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (!isGrey)
              BoxShadow(
                color: context.tokens.accent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status line
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: loading
                              ? Colors.amber
                              : failed
                                  ? Colors.grey.shade300
                                  : const Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        loading
                            ? l.city_picker_gps_locating
                            : failed
                                ? l.city_picker_gps_failed
                                : l.city_picker_gps_located,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // City name or loading
                  if (loading)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (city != null) ...[
                    Text(
                      city!.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      city!.province,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ] else
                    Text(
                      failed ? l.city_picker_gps_failed : l.city_picker_gps_not_supported,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            if (!loading && city != null)
              GestureDetector(
                onTap: onUse,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l.city_picker_gps_use,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Recent Section
// ──────────────────────────────────────────────────────────────

class _RecentSection extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPick;

  const _RecentSection({required this.current, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recent = LocalStore.recentCities.where((c) => c != current).take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.city_picker_recent),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in recent)
                _CityChip(
                  label: name,
                  active: false,
                  onTap: () => onPick(name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Region header
// ──────────────────────────────────────────────────────────────

class _RegionHeader extends StatelessWidget {
  final String title;

  const _RegionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.tokens.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(height: 1, color: context.tokens.line),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// City row (for all-cities list and search results)
// ──────────────────────────────────────────────────────────────

class _CityRow extends StatelessWidget {
  final CityInfo city;
  final bool active;
  final String currentLabel;
  final VoidCallback onTap;

  const _CityRow({
    required this.city,
    required this.active,
    required this.currentLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                city.name,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? context.tokens.accent : context.tokens.ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.accentSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                city.province,
                style: TextStyle(
                  fontSize: 12,
                  color: context.tokens.inkSub,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// City chip (for hot cities and recent cities)
// ──────────────────────────────────────────────────────────────

class _CityChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CityChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? context.tokens.accentSubtle : context.tokens.elev2,
          border: Border.all(
            color: active ? context.tokens.accent : context.tokens.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? context.tokens.accent : context.tokens.ink,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Region index sidebar
// ──────────────────────────────────────────────────────────────

class _RegionIndexBar extends StatelessWidget {
  final List<String> regions;
  final ValueChanged<String> onTap;

  const _RegionIndexBar({required this.regions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: context.tokens.elev2.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in regions)
              GestureDetector(
                onTap: () => onTap(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.tokens.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
