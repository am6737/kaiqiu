// search_screen.dart — 全局搜索（约球/赛事/球员）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  static const _hotTags = ['足球', '篮球', '约球', '龙岗杯', '莲花山', '新手局', '中级', '免费场'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final history = LocalStore.searchHistory;
    final q = _query.trim();

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: T.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: T.elev2,
                        border: Border.all(color: T.line),
                        borderRadius: BorderRadius.circular(T.r2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: T.inkSub),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              style: const TextStyle(
                                color: T.ink,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l.search_hint,
                                hintStyle: const TextStyle(
                                  color: T.inkDim,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.search,
                              onChanged: (v) => setState(() => _query = v),
                              onSubmitted: (v) async {
                                await LocalStore.pushSearch(v);
                                if (mounted) setState(() {});
                              },
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: T.inkSub,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: q.isEmpty ? _buildIdle(history) : _buildResults(q)),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(List<String> history) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (history.isNotEmpty) ...[
          SectionHeader(
            title: l.search_recent,
            trailing: GestureDetector(
              onTap: () async {
                await LocalStore.clearSearchHistory();
                if (mounted) setState(() {});
              },
              child: Label(l.search_clear),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in history)
                  _Chip(
                    label: h,
                    onTap: () {
                      _controller.text = h;
                      setState(() => _query = h);
                    },
                  ),
              ],
            ),
          ),
        ],
        SectionHeader(title: l.search_hot_tags),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _hotTags)
                _Chip(
                  label: t,
                  onTap: () {
                    _controller.text = t;
                    setState(() => _query = t);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(String q) {
    final l = context.l10n;
    final pickups = ref.watch(livePickupsProvider).valueOrNull ?? [];
    final hits = pickups
        .where((p) => p.venue.contains(q) || (p.level?.contains(q) ?? false))
        .toList();

    final eOn =
        ref.watch(liveEventsProvider(EventStatus.ongoing)).valueOrNull ?? [];
    final eReg =
        ref.watch(liveEventsProvider(EventStatus.registering)).valueOrNull ??
        [];
    final events = [
      for (final e in [...eOn, ...eReg])
        if (e.name.contains(q) ||
            (e.sub?.contains(q) ?? false) ||
            (e.city?.contains(q) ?? false))
          e,
    ];

    if (hits.isEmpty && events.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l.search_result_empty(q),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (hits.isNotEmpty) ...[
          SectionHeader(title: l.search_result_pickups),
          for (final p in hits)
            ListTile(
              leading: const Icon(Icons.sports_soccer, color: T.live),
              title: Text(
                p.venue,
                style: const TextStyle(color: T.ink, fontSize: 14),
              ),
              subtitle: Text(
                p.displayTime,
                style: const TextStyle(color: T.inkSub, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 16,
                color: T.inkDim,
              ),
              onTap: () async {
                await LocalStore.pushSearch(q);
                if (context.mounted) context.push('/pickup/${p.id}');
              },
            ),
        ],
        if (events.isNotEmpty) ...[
          SectionHeader(title: l.search_result_events),
          for (final e in events)
            ListTile(
              leading: const Icon(Icons.emoji_events, color: T.warn),
              title: Text(
                e.name,
                style: const TextStyle(color: T.ink, fontSize: 14),
              ),
              subtitle: Text(
                e.sub ?? (e.city ?? ''),
                style: const TextStyle(color: T.inkSub, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 16,
                color: T.inkDim,
              ),
              onTap: () async {
                await LocalStore.pushSearch(q);
                if (context.mounted) context.push('/event/${e.id}');
              },
            ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: T.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
