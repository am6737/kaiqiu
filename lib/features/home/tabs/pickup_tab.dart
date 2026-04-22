// lib/features/home/tabs/pickup_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../models/pickup_filter.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../cards/pickup_feed_card.dart';

class PickupTab extends ConsumerWidget {
  const PickupTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppL10n.of(context);
    final filter = ref.watch(pickupFilterProvider);
    final pickupsAsync = ref.watch(filteredPickupsProvider);
    final userPos = ref.watch(userPositionProvider).valueOrNull;

    return RefreshIndicator(
      color: t.accent,
      backgroundColor: t.elev1,
      onRefresh: () async {
        ref.invalidate(filteredPickupsProvider);
      },
      child: Column(
        children: [
          // Filter bar
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _FilterChip(
                  label: l.home_pickup_filter_all,
                  selected: filter.dateRange == PickupDateRange.all &&
                      filter.level == PickupLevel.all,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      const PickupFilter(),
                  tokens: t,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l.home_pickup_filter_distance,
                  selected: filter.sortBy == PickupSort.distance,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      filter.copyWith(sortBy: PickupSort.distance),
                  tokens: t,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l.home_pickup_filter_today,
                  selected: filter.dateRange == PickupDateRange.today,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      filter.copyWith(dateRange: PickupDateRange.today),
                  tokens: t,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l.home_pickup_filter_intermediate,
                  selected: filter.level == PickupLevel.intermediate,
                  onTap: () => ref.read(pickupFilterProvider.notifier).state =
                      filter.copyWith(level: PickupLevel.intermediate),
                  tokens: t,
                ),
              ],
            ),
          ),
          // Pickup list
          Expanded(
            child: pickupsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  l.home_pickups_load_failed,
                  style: TextStyle(color: t.inkDim),
                ),
              ),
              data: (pickups) => pickups.isEmpty
                  ? Center(
                      child: Text('暂无约球',
                          style: TextStyle(color: t.inkMute)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: pickups.length,
                      itemBuilder: (ctx, i) {
                        final p = pickups[i];
                        double? distKm;
                        if (userPos != null &&
                            p.lat != null &&
                            p.lng != null) {
                          distKm = Geolocator.distanceBetween(
                                userPos.latitude,
                                userPos.longitude,
                                p.lat!,
                                p.lng!,
                              ) /
                              1000;
                        }
                        return PickupFeedCard(
                          pickup: p,
                          distanceKm: distKm,
                          locationAvailable: userPos != null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? tokens.accent : tokens.elev1,
          border: selected
              ? null
              : Border.all(color: tokens.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : tokens.inkSub,
          ),
        ),
      ),
    );
  }
}
