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
  String _query = '';

  List<Division>? _provinces;
  bool _dataLoading = true;

  // GPS state
  bool _gpsLoading = true;
  String? _gpsPath;
  bool _gpsFailed = false;

  // Drill-down state: breadcrumb path of selected divisions
  final List<Division> _breadcrumb = [];

  // Letter index keys
  final _letterKeys = <String, GlobalKey>{};
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provinces = await loadDivisions();
    if (!mounted) return;
    setState(() {
      _provinces = provinces;
      _dataLoading = false;
    });
    _locateCity();
  }

  Future<void> _locateCity() async {
    if (_provinces == null) return;
    setState(() {
      _gpsLoading = true;
      _gpsFailed = false;
      _gpsPath = null;
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
    final path = findNearestCityPath(_provinces!, pos.latitude, pos.longitude);
    setState(() {
      _gpsLoading = false;
      _gpsPath = path;
      _gpsFailed = path == null;
    });
  }

  Future<void> _pick(String path) async {
    await LocalStore.setCityPath(path);
    if (mounted) context.pop();
  }

  void _drillInto(Division division) {
    setState(() {
      _breadcrumb.add(division);
      _letterKeys.clear();
    });
  }

  void _popTo(int index) {
    setState(() {
      _breadcrumb.removeRange(index, _breadcrumb.length);
      _letterKeys.clear();
    });
  }

  List<Division> get _currentItems {
    if (_breadcrumb.isEmpty) return _provinces ?? [];
    return _breadcrumb.last.children;
  }

  int get _currentLevel => _breadcrumb.length; // 0=省, 1=市, 2=区

  String _buildPath(String name) {
    final parts = _breadcrumb.map((d) => d.name).toList()..add(name);
    return parts.join('/');
  }

  void _scrollToLetter(String letter) {
    final key = _letterKeys[letter];
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
    final currentPath = LocalStore.cityPath;
    final isSearching = _query.isNotEmpty;

    if (_dataLoading) {
      return Scaffold(
        backgroundColor: context.tokens.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final searchResults =
        isSearching ? searchDivisions(_provinces!, _query) : <SearchResult>[];
    final items = _currentItems;
    final grouped = groupByPinyinInitial(items);

    // Build letter keys
    if (_letterKeys.isEmpty) {
      for (final letter in grouped.keys) {
        _letterKeys[letter] = GlobalKey();
      }
    }

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                bottom: 40,
                right: !isSearching && _currentLevel == 0 ? 36 : 0,
              ),
              children: [
                PageTitleBar(
                  title: l.city_picker_title,
                  onBack: () {
                    if (_breadcrumb.isNotEmpty) {
                      _popTo(_breadcrumb.length - 1);
                    } else {
                      context.pop();
                    }
                  },
                ),

                // GPS card (only on province level)
                if (_currentLevel == 0) ...[
                  _GpsCard(
                    loading: _gpsLoading,
                    path: _gpsPath,
                    failed: _gpsFailed,
                    onUse: () {
                      if (_gpsPath != null) _pick(_gpsPath!);
                    },
                    onRetry: _locateCity,
                  ),
                  const SizedBox(height: 14),
                ],

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
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Breadcrumb (when drilled in)
                if (_breadcrumb.isNotEmpty && !isSearching)
                  _Breadcrumb(
                    items: _breadcrumb,
                    onTap: _popTo,
                  ),

                if (isSearching) ...[
                  // Search results
                  if (searchResults.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          l.city_picker_no_result,
                          style: TextStyle(
                              color: context.tokens.inkSub, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    for (final r in searchResults.take(50))
                      _SearchResultRow(
                        result: r,
                        currentPath: currentPath,
                        currentLabel: l.city_picker_current_label,
                        onTap: () => _pick(r.path),
                      ),
                ] else if (_currentLevel == 0) ...[
                  // Province level: show recent + hot + all provinces

                  // Recent
                  _RecentSection(
                    currentPath: currentPath,
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
                            active: currentPath.contains(name),
                            onTap: () {
                              // Find the hot city's province path
                              for (final p in _provinces!) {
                                for (final c in p.children) {
                                  if (c.name == name) {
                                    _pick('${p.name}/${c.name}');
                                    return;
                                  }
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // All provinces by pinyin
                  SectionHeader(title: l.city_picker_all),
                  for (final entry in grouped.entries) ...[
                    _LetterHeader(
                        key: _letterKeys[entry.key], letter: entry.key),
                    for (final item in entry.value)
                      _DivisionRow(
                        division: item,
                        hasChildren: item.children.isNotEmpty,
                        onTap: () => _drillInto(item),
                      ),
                  ],
                ] else ...[
                  // City/District level
                  for (final item in items)
                    _DivisionRow(
                      division: item,
                      hasChildren: item.children.isNotEmpty,
                      active: currentPath.contains(item.name),
                      currentLabel: l.city_picker_current_label,
                      onTap: () {
                        if (item.children.isNotEmpty) {
                          _drillInto(item);
                        } else {
                          _pick(_buildPath(item.name));
                        }
                      },
                    ),
                ],
              ],
            ),

            // Letter index sidebar (province level, not searching)
            if (!isSearching && _currentLevel == 0)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _LetterIndexBar(
                  letters: grouped.keys.toList(),
                  onTap: _scrollToLetter,
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
  final String? path;
  final bool failed;
  final VoidCallback onUse;
  final VoidCallback onRetry;

  const _GpsCard({
    required this.loading,
    required this.path,
    required this.failed,
    required this.onUse,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isGrey = failed || (path == null && !loading);
    final parts = path?.split('/') ?? [];

    return GestureDetector(
      onTap: failed ? onRetry : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isGrey
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [
                    context.tokens.accent,
                    context.tokens.accent.withValues(alpha: 0.7)
                  ],
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
                  if (loading)
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  else if (parts.isNotEmpty) ...[
                    Text(
                      parts.length >= 2 ? parts[1] : parts[0],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (parts.isNotEmpty)
                      Text(
                        parts[0],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                  ] else
                    Text(
                      failed
                          ? l.city_picker_gps_failed
                          : l.city_picker_gps_not_supported,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                ],
              ),
            ),
            if (!loading && parts.isNotEmpty)
              GestureDetector(
                onTap: onUse,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3)),
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
// Breadcrumb
// ──────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final List<Division> items;
  final ValueChanged<int> onTap;

  const _Breadcrumb({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            GestureDetector(
              onTap: () => onTap(i),
              child: Text(
                items[i].name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.accent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '>',
                style: TextStyle(
                    fontSize: 13, color: context.tokens.inkSub),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Recent Section
// ──────────────────────────────────────────────────────────────

class _RecentSection extends StatelessWidget {
  final String currentPath;
  final ValueChanged<String> onPick;

  const _RecentSection({required this.currentPath, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recent =
        LocalStore.recentCities.where((c) => c != currentPath).take(5).toList();
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
              for (final path in recent)
                _CityChip(
                  label: _displayName(path),
                  active: false,
                  onTap: () => onPick(path),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _displayName(String path) {
    final parts = path.split('/');
    if (parts.length >= 3) return '${parts[1]} ${parts[2]}';
    if (parts.length >= 2) return parts[1];
    return parts.last;
  }
}

// ──────────────────────────────────────────────────────────────
// Search result row
// ──────────────────────────────────────────────────────────────

class _SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final String currentPath;
  final String currentLabel;
  final VoidCallback onTap;

  const _SearchResultRow({
    required this.result,
    required this.currentPath,
    required this.currentLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentPath == result.path;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                result.display,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isActive ? context.tokens.accent : context.tokens.ink,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Division row (province / city / district)
// ──────────────────────────────────────────────────────────────

class _DivisionRow extends StatelessWidget {
  final Division division;
  final bool hasChildren;
  final bool active;
  final String? currentLabel;
  final VoidCallback onTap;

  const _DivisionRow({
    required this.division,
    required this.hasChildren,
    this.active = false,
    this.currentLabel,
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
                division.name,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      active ? context.tokens.accent : context.tokens.ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (active && currentLabel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.accentSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.tokens.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (hasChildren)
              Icon(Icons.chevron_right,
                  size: 18, color: context.tokens.inkSub),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Letter header
// ──────────────────────────────────────────────────────────────

class _LetterHeader extends StatelessWidget {
  final String letter;
  const _LetterHeader({super.key, required this.letter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.tokens.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: context.tokens.line)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// City chip
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
// Letter index sidebar
// ──────────────────────────────────────────────────────────────

class _LetterIndexBar extends StatelessWidget {
  final List<String> letters;
  final ValueChanged<String> onTap;

  const _LetterIndexBar({required this.letters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
        decoration: BoxDecoration(
          color: context.tokens.elev2.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in letters)
              GestureDetector(
                onTap: () => onTap(l),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  child: Text(
                    l,
                    style: TextStyle(
                      fontSize: 11,
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
