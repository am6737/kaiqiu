import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/pickup.dart';
import '../../../services/supabase.dart' as svc;
import '../../../theme/app_tokens.dart';
import '../../../widgets/network_avatar.dart';

class PickupFeedCard extends StatelessWidget {
  final Pickup pickup;
  final double? distanceKm;
  final bool locationAvailable;
  final bool glass;
  const PickupFeedCard({
    super.key,
    required this.pickup,
    this.distanceKm,
    this.locationAvailable = false,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final needed = pickup.displayNeed;
    final filled = pickup.total - needed;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/pickup/${pickup.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: glass
              ? (isDark ? const Color(0x33FFFFFF) : const Color(0x80FFFFFF))
              : t.elev1,
          border: Border.all(
            color: glass
                ? (isDark ? const Color(0x1AFFFFFF) : const Color(0x40FFFFFF))
                : t.line,
          ),
          borderRadius: BorderRadius.circular(t.r3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hostRow(t, l),
            const SizedBox(height: 10),
            _venueRow(t, l),
            const SizedBox(height: 10),
            Container(
              height: 0.5,
              color: glass
                  ? (isDark ? const Color(0x1AFFFFFF) : const Color(0x33FFFFFF))
                  : t.line,
            ),
            const SizedBox(height: 10),
            _bottomRow(t, l, needed, filled),
          ],
        ),
      ),
    );
  }

  Widget _hostRow(AppTokens t, dynamic l) {
    final hostName = pickup.displayHost;
    final ago = _timeAgo(pickup.createdAt, l);
    final isMe = pickup.hostId == svc.currentUserId;

    final Color dotColor;
    final String statusText;
    switch (pickup.status) {
      case PickupStatus.cancelled:
        dotColor = t.danger;
        statusText = l.pickup_status_cancelled;
      case PickupStatus.almost:
        dotColor = t.warn;
        statusText = l.home_status_almost;
      case PickupStatus.full:
        dotColor = t.inkMute;
        statusText = l.home_status_full;
      case PickupStatus.done:
        dotColor = t.inkMute;
        statusText = l.pickup_detail_status_done;
      default:
        dotColor = t.accent;
        statusText = l.home_status_open;
    }

    return Row(
      children: [
        NetworkAvatar(hostName, url: pickup.hostAvatarUrl, size: 24),
        const SizedBox(width: 8),
        Text(
          hostName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: t.ink,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: t.accent.withAlpha(26),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '我',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: t.accent,
              ),
            ),
          ),
        ],
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.home_host_pickup_with_time(ago),
            style: TextStyle(fontSize: 11, color: t.inkDim),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: dotColor,
          ),
        ),
      ],
    );
  }

  Widget _venueRow(AppTokens t, dynamic l) {
    final feeText = pickup.feeCents == 0
        ? l.home_fee_free
        : l.home_fee_yuan(
            (pickup.feeCents / 100).toStringAsFixed(
              pickup.feeCents % 100 == 0 ? 0 : 2,
            ),
          );
    final timeText = pickup.displayTime.isNotEmpty
        ? pickup.displayTime
        : _formatStartAt(pickup.startAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pickup.venue,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: t.ink,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.access_time_rounded, size: 12, color: t.inkSub),
            const SizedBox(width: 4),
            Text(timeText, style: TextStyle(fontSize: 12, color: t.inkSub)),
            const SizedBox(width: 10),
            Text(feeText, style: TextStyle(fontSize: 12, color: t.inkSub)),
            if (pickup.level != null && pickup.level!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                pickup.level!,
                style: TextStyle(fontSize: 12, color: t.inkSub),
              ),
            ],
            if (distanceKm != null) ...[
              const SizedBox(width: 10),
              Icon(Icons.near_me, size: 10, color: t.inkMute),
              const SizedBox(width: 2),
              Text(
                '${distanceKm!.toStringAsFixed(1)}km',
                style: TextStyle(fontSize: 12, color: t.inkMute),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _bottomRow(AppTokens t, dynamic l, int needed, int filled) {
    final avatarCount = filled.clamp(0, 4);

    return Row(
      children: [
        SizedBox(
          width: avatarCount * 16.0 + 10,
          height: 26,
          child: Stack(
            children: List.generate(avatarCount, (i) {
              final letter = String.fromCharCode(65 + i); // A, B, C, D
              return Positioned(
                left: i * 16.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.elev1, width: 2),
                  ),
                  child: NetworkAvatar(letter, size: 22),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$filled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: t.ink,
                ),
              ),
              TextSpan(
                text: '/${pickup.total}',
                style: TextStyle(fontSize: 12, color: t.inkDim),
              ),
              const WidgetSpan(child: SizedBox(width: 6)),
              TextSpan(
                text: needed > 0 ? l.home_need_n(needed) : l.home_full,
                style: TextStyle(
                  fontSize: 12,
                  color: needed > 0 ? t.accent : t.inkDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime created, dynamic l) {
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  String _formatStartAt(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
