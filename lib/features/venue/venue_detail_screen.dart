// venue_detail_screen.dart — 场馆详情页
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/venue.dart';
import '../../providers.dart';
import '../../services/map_launcher.dart';
import '../../services/supabase.dart' as svc;
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/network_cover.dart';
import '../../widgets/primary_button.dart';
import 'venue_booking_sheet.dart';

class VenueDetailScreen extends ConsumerWidget {
  final String id;
  const VenueDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(venueDetailProvider(id));
    return async.when(
      data: (venue) => _Body(venue: venue),
      loading: () => Scaffold(
        backgroundColor: context.tokens.bg,
        body: Center(
          child: CircularProgressIndicator(color: context.tokens.accent),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: context.tokens.bg,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 32, color: context.tokens.danger),
                const SizedBox(height: 8),
                Text(
                  '加载失败: $e',
                  style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => ref.invalidate(venueDetailProvider(id)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.tokens.elev3,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '重试',
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
}

class _Body extends StatelessWidget {
  final Venue venue;
  const _Body({required this.venue});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _CoverSliver(venue: venue),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + sport badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              venue.name,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: t.ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: t.accentSubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              venue.sportTypeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rating row
                      if (venue.rating != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ...List.generate(5, (i) {
                                final filled = i < (venue.rating ?? 0).round();
                                return Icon(
                                  filled ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: filled
                                      ? const Color(0xFFFFB800)
                                      : t.inkMute,
                                );
                              }),
                              const SizedBox(width: 6),
                              Text(
                                venue.rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: t.ink,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${venue.reviewCount}条评价)',
                                style: TextStyle(fontSize: 12, color: t.inkSub),
                              ),
                            ],
                          ),
                        ),

                      // Info chips
                      _InfoChips(venue: venue),
                      const SizedBox(height: 20),

                      // Description
                      if (venue.description != null &&
                          venue.description!.isNotEmpty) ...[
                        Text(
                          '场馆介绍',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          venue.description!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: t.inkSub,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Facilities
                      if (venue.facilities.isNotEmpty) ...[
                        Text(
                          '配套设施',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: venue.facilities.map((f) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: t.elev2,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: t.line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _facilityIcon(f),
                                    size: 14,
                                    color: t.inkSub,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: t.inkSub,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Location section
                      Text(
                        '场馆位置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => MapLauncher.openNavigation(
                          context: context,
                          lat: venue.lat,
                          lng: venue.lng,
                          name: venue.name,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: t.elev2,
                            borderRadius: BorderRadius.circular(t.r2),
                            border: Border.all(color: t.line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: t.accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      venue.address,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: t.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '点击导航',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: t.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: t.inkMute,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Contact info
                      Text(
                        '联系方式',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ContactRow(venue: venue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(venue: venue),
          ),
        ],
      ),
    );
  }

  static IconData _facilityIcon(String f) => switch (f) {
    '更衣室' => Icons.checkroom,
    '停车场' => Icons.local_parking,
    '灯光' => Icons.light,
    '淋浴' => Icons.shower,
    '饮水' => Icons.water_drop,
    '洗手间' => Icons.wc,
    'WiFi' => Icons.wifi,
    '储物柜' => Icons.lock,
    '观众席' => Icons.people,
    _ => Icons.check_circle_outline,
  };
}

class _CoverSliver extends StatelessWidget {
  final Venue venue;
  const _CoverSliver({required this.venue});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: t.elev1,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: venue.coverUrl != null
            ? NetworkCover(
                url: venue.coverUrl,
                fallbackLabel: venue.name,
                height: 240,
              )
            : Container(
                color: t.elev3,
                child: Center(
                  child: Icon(
                    Icons.stadium,
                    size: 64,
                    color: t.inkMute,
                  ),
                ),
              ),
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  final Venue venue;
  const _InfoChips({required this.venue});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chips = <(IconData, String)>[
      (Icons.grass, venue.fieldTypeLabel),
      (Icons.grid_view, '${venue.fieldCount}块场地'),
      (
        Icons.monetization_on_outlined,
        venue.pricePerHourCents > 0
            ? '¥${venue.pricePerHourYuan.toStringAsFixed(0)}/小时'
            : '免费',
      ),
      if (venue.openingHours != null)
        (Icons.access_time, venue.openingHours!),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: t.elev2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.$1, size: 14, color: t.inkSub),
              const SizedBox(width: 4),
              Text(
                c.$2,
                style: TextStyle(fontSize: 12, color: t.inkSub),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ContactRow extends ConsumerWidget {
  final Venue venue;
  const _ContactRow({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
        border: Border.all(color: t.line),
      ),
      child: Column(
        children: [
          if (venue.phone != null && venue.phone!.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.phone, size: 18, color: t.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    venue.phone!,
                    style: TextStyle(fontSize: 14, color: t.ink),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: venue.phone!));
                    showToast(context, '电话已复制');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.accentSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '复制',
                      style: TextStyle(
                        fontSize: 12,
                        color: t.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Icon(Icons.person, size: 18, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '负责人: ${venue.ownerName ?? '场馆管理员'}',
                  style: TextStyle(fontSize: 14, color: t.ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  final Venue venue;
  const _BottomBar({required this.venue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final isOwner = svc.currentUserId == venue.ownerId;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: t.elev1,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          // Chat with owner
          if (!isOwner) ...[
            Expanded(
              child: PrimaryButton(
                label: '联系场馆',
                variant: BtnVariant.secondary,
                size: BtnSize.md,
                full: true,
                onPressed: () => _contactOwner(context, ref),
              ),
            ),
            const SizedBox(width: 10),
          ],
          // Book
          Expanded(
            child: PrimaryButton(
              label: isOwner ? '管理预约' : '预约场地',
              variant: BtnVariant.primary,
              size: BtnSize.md,
              full: true,
              onPressed: () => _showBooking(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactOwner(BuildContext context, WidgetRef ref) async {
    final uid = svc.currentUserId;
    if (uid == null) {
      showToast(context, '请先登录');
      return;
    }
    try {
      final repo = ref.read(messagesRepoProvider);
      final convId = await repo.ensureDmWith(venue.ownerId);
      if (context.mounted) {
        context.push('/chat/$convId');
      }
    } catch (e) {
      if (context.mounted) showToast(context, '无法建立对话: $e');
    }
  }

  void _showBooking(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tokens.elev1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VenueBookingSheet(venue: venue),
    );
  }
}
