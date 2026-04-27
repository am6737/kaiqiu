// venue_owner_bookings_sheet.dart — 场馆主管理预约
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';

class VenueOwnerBookingsSheet extends ConsumerWidget {
  const VenueOwnerBookingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final async = ref.watch(venueOwnerBookingsProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.inkMute,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '预约管理',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          Expanded(
            child: async.when(
              data: (bookings) {
                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 40, color: t.inkMute),
                        const SizedBox(height: 8),
                        Text(
                          '暂无预约',
                          style: TextStyle(fontSize: 14, color: t.inkSub),
                        ),
                      ],
                    ),
                  );
                }
                final pending = bookings.where((b) => b.status == BookingStatus.pending).toList();
                final confirmed = bookings.where((b) => b.status == BookingStatus.confirmed).toList();
                final completed = bookings.where((b) => b.status == BookingStatus.completed).toList();
                final cancelled = bookings.where((b) => b.status == BookingStatus.cancelled).toList();

                return ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _SectionHeader('待确认 (${pending.length})', t.warn),
                      ...pending.map((b) => _BookingTile(booking: b, showActions: true)),
                    ],
                    if (confirmed.isNotEmpty) ...[
                      _SectionHeader('已确认 (${confirmed.length})', const Color(0xFF4CAF50)),
                      ...confirmed.map((b) => _BookingTile(booking: b)),
                    ],
                    if (completed.isNotEmpty) ...[
                      _SectionHeader('已完成 (${completed.length})', t.inkSub),
                      ...completed.map((b) => _BookingTile(booking: b)),
                    ],
                    if (cancelled.isNotEmpty) ...[
                      _SectionHeader('已取消 (${cancelled.length})', t.danger),
                      ...cancelled.map((b) => _BookingTile(booking: b)),
                    ],
                  ],
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: t.accent),
              ),
              error: (e, _) => Center(
                child: Text('加载失败: $e', style: TextStyle(color: t.inkSub, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  final VenueBooking booking;
  final bool showActions;
  const _BookingTile({required this.booking, this.showActions = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final statusColor = switch (booking.status) {
      BookingStatus.confirmed => const Color(0xFF4CAF50),
      BookingStatus.pending => t.warn,
      BookingStatus.cancelled => t.danger,
      BookingStatus.completed => t.inkSub,
    };
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.venueName != null)
                      Text(
                        booking.venueName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${booking.date.month}/${booking.date.day}  ${booking.startTime} - ${booking.endTime}',
                      style: TextStyle(fontSize: 13, color: t.ink),
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
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: t.inkSub),
              const SizedBox(width: 4),
              Text(
                booking.userName ?? '未知用户',
                style: TextStyle(fontSize: 12, color: t.inkSub),
              ),
              if (booking.totalCents > 0) ...[
                const Spacer(),
                Text(
                  '¥${booking.totalYuan.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ],
            ],
          ),
          if (booking.note != null && booking.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '备注: ${booking.note}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: t.inkDim),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '拒绝',
                    variant: BtnVariant.ghost,
                    size: BtnSize.sm,
                    full: true,
                    onPressed: () => _updateStatus(context, ref, 'cancelled'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: '确认',
                    variant: BtnVariant.primary,
                    size: BtnSize.sm,
                    full: true,
                    onPressed: () => _updateStatus(context, ref, 'confirmed'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(venuesRepoProvider).updateBookingStatus(booking.id, status);
      ref.invalidate(venueOwnerBookingsProvider);
      ref.invalidate(myBookingsProvider);
      if (!context.mounted) return;
      final label = status == 'confirmed' ? '已确认预约' : '已拒绝预约';
      showToast(context, label, success: status == 'confirmed');
    } catch (e) {
      if (!context.mounted) return;
      showToast(context, '操作失败: $e', error: true);
    }
  }
}
