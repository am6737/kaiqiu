// my_venues_screen.dart — 我的场馆 (管理已发布的场馆 + 我的预约)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/venue.dart';
import '../../providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../theme/app_tokens.dart';

class MyVenuesScreen extends ConsumerStatefulWidget {
  const MyVenuesScreen({super.key});

  @override
  ConsumerState<MyVenuesScreen> createState() => _MyVenuesScreenState();
}

class _MyVenuesScreenState extends ConsumerState<MyVenuesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: '我的场馆',
              onBack: () => context.pop(),
              actions: [
                GestureDetector(
                  onTap: () => context.push('/venue/create'),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.add, color: t.accent),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: t.elev2,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(t.r2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabBtn(
                        label: '我发布的',
                        active: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabBtn(
                        label: '我的预约',
                        active: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _tab == 0 ? const _MyVenuesList() : const _MyBookingsList()),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(t.r1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? t.accentInk : t.inkSub,
          ),
        ),
      ),
    );
  }
}

class _MyVenuesList extends ConsumerWidget {
  const _MyVenuesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myVenuesProvider);
    return async.when(
      data: (venues) {
        if (venues.isEmpty) {
          return EmptyState(
            icon: Icons.stadium_outlined,
            title: '还没有发布场馆',
            subtitle: '发布你的场馆，让更多球友找到你',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: venues.length,
          itemBuilder: (_, i) => _VenueRow(venue: venues[i]),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: context.tokens.accent),
      ),
      error: (e, _) => Center(
        child: Text(
          '加载失败: $e',
          style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
        ),
      ),
    );
  }
}

class _VenueRow extends StatelessWidget {
  final Venue venue;
  const _VenueRow({required this.venue});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () => context.push('/venue/${venue.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.line, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
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
                  ? Icon(Icons.stadium, size: 24, color: t.inkSub)
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${venue.sportTypeLabel} · ${venue.fieldTypeLabel} · ${venue.fieldCount}块场地',
                    style: TextStyle(fontSize: 12, color: t.inkSub),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: venue.status == VenueStatus.active
                              ? const Color(0xFF4CAF50)
                              : t.inkMute,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        venue.status == VenueStatus.active ? '营业中' : '已关闭',
                        style: TextStyle(
                          fontSize: 11,
                          color: venue.status == VenueStatus.active
                              ? const Color(0xFF4CAF50)
                              : t.inkMute,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: t.inkMute),
          ],
        ),
      ),
    );
  }
}

class _MyBookingsList extends ConsumerWidget {
  const _MyBookingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myBookingsProvider);
    return async.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_today_outlined,
            title: '还没有预约记录',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: bookings.length,
          itemBuilder: (_, i) => _BookingRow(booking: bookings[i]),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(color: context.tokens.accent),
      ),
      error: (e, _) => Center(
        child: Text(
          '加载失败: $e',
          style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final VenueBooking booking;
  const _BookingRow({required this.booking});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final statusColor = switch (booking.status) {
      BookingStatus.confirmed => const Color(0xFF4CAF50),
      BookingStatus.pending => t.warn,
      BookingStatus.cancelled => t.danger,
      BookingStatus.completed => t.inkSub,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line, width: 1)),
      ),
      child: Row(
        children: [
          // Date circle
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.elev2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${booking.date.month}/${booking.date.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
                Text(
                  booking.startTime,
                  style: TextStyle(fontSize: 10, color: t.inkSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking.startTime} - ${booking.endTime}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                if (booking.note != null && booking.note!.isNotEmpty)
                  Text(
                    booking.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.inkSub),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              booking.statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
