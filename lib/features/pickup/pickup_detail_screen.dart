// pickup_detail_screen.dart — 球局详情 + 阵型图 (real slots + tap-to-join)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/pickup.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/local_storage.dart';
import '../../services/map_launcher.dart';
import '../../services/supabase.dart' as svc;
import '../../theme/app_tokens.dart';
import 'map/mini_map.dart';
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/network_cover.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

/// Canonical 4-3-3 layout — 11 slot positions on the pitch.
/// Same coordinates used to match seed / join rows.
const _formation = [
  ('GK', 50, 92),
  ('LB', 18, 72),
  ('CB', 38, 72),
  ('CB', 62, 72),
  ('RB', 82, 72),
  ('CM', 30, 48),
  ('CM', 50, 48),
  ('CM', 70, 48),
  ('LW', 20, 22),
  ('ST', 50, 14),
  ('RW', 80, 22),
];

class PickupDetailScreen extends ConsumerWidget {
  final String id;
  const PickupDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(pickupSlotsProvider(id));
    final pickupAsync = ref.watch(pickupDetailProvider(id));

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  onBack: () => context.pop(),
                  onShare: () {
                    final p = pickupAsync.valueOrNull;
                    if (p != null) sharePickup(p);
                  },
                  pickupId: id,
                ),
                _VenueInfo(
                  venue: pickupAsync.valueOrNull?.venue ?? '',
                  address: pickupAsync.valueOrNull?.address,
                  lat: pickupAsync.valueOrNull?.lat,
                  lng: pickupAsync.valueOrNull?.lng,
                ),
                _HostStrip(),
                slotsAsync.when(
                  data: (slots) => _Formation(pickupId: id, slots: slots),
                  loading: () => const _FormationLoading(),
                  error: (e, _) => _FormationError(
                    error: e,
                    onRetry: () => ref.invalidate(pickupSlotsProvider(id)),
                  ),
                ),
                _Details(),
                _MiniMap(
                  venue: pickupAsync.valueOrNull?.venue ?? '',
                  address: pickupAsync.valueOrNull?.address,
                  lat: pickupAsync.valueOrNull?.lat,
                  lng: pickupAsync.valueOrNull?.lng,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCta(pickupId: id),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onShare;
  final String pickupId;
  const _Header({
    required this.onBack,
    required this.onShare,
    required this.pickupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localStoreProvider);
    final faved = LocalStore.isPickupFavorited(pickupId);
    final pickup = ref.watch(pickupDetailProvider(pickupId)).valueOrNull;
    final venue = pickup?.venue;
    final label = venue == null || venue.isEmpty
        ? '场地外景'
        : '场地外景 · $venue';
    return Stack(
      children: [
        NetworkCover(
          url: pickup?.venuePhotoUrl,
          fallbackLabel: label,
          height: 200,
          hue: 140,
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _CircleBtn(icon: Icons.arrow_back_ios_new, onTap: onBack),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Row(
            children: [
              _CircleBtn(
                icon: faved ? Icons.favorite : Icons.favorite_border,
                onTap: () async {
                  await ref
                      .read(favoritesRepoProvider)
                      .toggle(FavoriteEntity.pickup, pickupId);
                },
                color: faved ? context.tokens.accent : context.tokens.ink,
              ),
              const SizedBox(width: 8),
              _CircleBtn(icon: Icons.ios_share, onTap: onShare),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.ink;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0x80000000) : const Color(0x33000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: c),
      ),
    );
  }
}

class _VenueInfo extends StatelessWidget {
  final String venue;
  final String? address;
  final double? lat;
  final double? lng;
  const _VenueInfo({
    required this.venue,
    this.address,
    this.lat,
    this.lng,
  });

  bool get _canNavigate => lat != null && lng != null;

  void _openNav(BuildContext context) {
    if (!_canNavigate) return;
    MapLauncher.openNavigation(
      context: context,
      lat: lat!,
      lng: lng!,
      name: venue.isEmpty ? (address ?? '') : venue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusDot(state: 'open'),
              const SizedBox(width: 6),
              Label(context.l10n.pickup_detail_open_need_n(3), color: context.tokens.accent),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '龙岗体育中心 3号场',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _canNavigate ? () => _openNav(context) : null,
                icon: const Icon(Icons.near_me, size: 16),
                label: Text(context.l10n.pickup_detail_navigate),
                style: TextButton.styleFrom(
                  foregroundColor: context.tokens.accent,
                  disabledForegroundColor: context.tokens.inkMute,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: context.tokens.inkSub),
              SizedBox(width: 5),
              N('今晚 19:30 · 2小时', size: 13, color: context.tokens.inkSub),
              SizedBox(width: 14),
              Icon(Icons.currency_yen, size: 13, color: context.tokens.inkSub),
              SizedBox(width: 2),
              N('50 AA', size: 13, color: context.tokens.inkSub),
            ],
          ),
        ],
      ),
    );
  }
}

class _HostStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    const hostName = '老王';
    final followed = LocalStore.isFollowing(hostName);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Row(
        children: [
          const Avatar(hostName, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Label(l.pickup_detail_host_stats(28, 100)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/messages'),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                border: Border.all(color: context.tokens.line),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 14,
                color: context.tokens.ink,
              ),
            ),
          ),
          PrimaryButton(
            label: followed ? l.common_unfollow : l.common_follow,
            variant: followed ? BtnVariant.secondary : BtnVariant.ghost,
            size: BtnSize.sm,
            onPressed: () async {
              await ref
                  .read(favoritesRepoProvider)
                  .toggle(FavoriteEntity.user, hostName);
              if (context.mounted) {
                showToast(
                  context,
                  LocalStore.isFollowing(hostName)
                      ? l.common_unfollow
                      : l.common_follow,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}


class _Formation extends ConsumerWidget {
  final String pickupId;
  final List<PickupSlot> slots;
  const _Formation({required this.pickupId, required this.slots});

  PickupSlot? _slotAt(int x, int y) {
    for (final s in slots) {
      if (s.x == x && s.y == y) return s;
    }
    return null;
  }

  Future<void> _join(
    BuildContext ctx,
    WidgetRef ref, {
    required String position,
    required int x,
    required int y,
  }) async {
    final uid = svc.currentUserId;
    if (uid == null) {
      showToast(ctx, ctx.l10n.pickup_detail_not_signed_in, error: true);
      return;
    }
    try {
      await ref
          .read(pickupsRepoProvider)
          .join(
            pickupId: pickupId,
            userId: uid,
            position: position,
            x: x,
            y: y,
          );
      ref.invalidate(pickupSlotsProvider(pickupId));
    } catch (e) {
      if (!ctx.mounted) return;
      showToast(ctx, ctx.l10n.pickup_detail_join_failed('$e'), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filledCount = _formation
        .where((p) => _slotAt(p.$2, p.$3) != null)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Label(context.l10n.pickup_detail_formation_title('4-3-3')),
              const Spacer(),
              if (filledCount >= 2) ...[
                GestureDetector(
                  onTap: () {
                    final sport = ref.read(sportProvider);
                    if (sport == 'football') {
                      context.push('/rate-pitch/$pickupId');
                    } else {
                      context.push('/rate/$pickupId');
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.accentSubtle,
                      border: Border.all(color: context.tokens.accent.withAlpha(0x66)),
                      borderRadius: BorderRadius.circular(context.tokens.r1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rate, size: 12, color: context.tokens.accent),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.rate_pitch_rate_teammates_cta,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Row(
                children: [
                  N(
                    '$filledCount',
                    size: 12,
                    weight: FontWeight.w600,
                    color: context.tokens.accent,
                  ),
                  N(
                    context.l10n.pickup_detail_slots_filled_of(
                      _formation.length,
                    ),
                    size: 12,
                    color: context.tokens.inkSub,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              final h = 340.0;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final fieldL1 = isDark ? 0.20 : 0.62;
              final fieldL2 = isDark ? 0.16 : 0.56;
              final lineColor = isDark
                  ? const Color(0x33FFFFFF)
                  : const Color(0x4DFFFFFF);
              final dotColor = isDark
                  ? const Color(0x4DFFFFFF)
                  : const Color(0x66FFFFFF);
              return Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HSLColor.fromAHSL(1, 140, 0.30, fieldL1).toColor(),
                      HSLColor.fromAHSL(1, 140, 0.30, fieldL2).toColor(),
                    ],
                  ),
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r3),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _FieldPainter(
                          lineColor: lineColor,
                          dotColor: dotColor,
                        ),
                      ),
                    ),
                    for (final p in _formation)
                      Positioned(
                        left: (p.$2 / 100) * w - 18,
                        top: (p.$3 / 100) * h - 22,
                        child: _PlayerDot(
                          pos: p.$1,
                          slot: _slotAt(p.$2, p.$3),
                          onJoin: () => _join(
                            context,
                            ref,
                            position: p.$1,
                            x: p.$2,
                            y: p.$3,
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
    );
  }
}

class _FieldPainter extends CustomPainter {
  final Color lineColor;
  final Color dotColor;
  const _FieldPainter({required this.lineColor, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      stroke,
    );
    canvas.drawLine(
      Offset(1, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      stroke,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 30, stroke);
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = dotColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, 1, size.width * 0.4, size.height * 0.14),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.3,
        size.height * 0.85,
        size.width * 0.4,
        size.height * 0.14,
      ),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.4, 1, size.width * 0.2, size.height * 0.06),
      stroke,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.4,
        size.height * 0.93,
        size.width * 0.2,
        size.height * 0.06,
      ),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) =>
      old.lineColor != lineColor || old.dotColor != dotColor;
}

class _PlayerDot extends StatelessWidget {
  final String pos;
  final PickupSlot? slot;
  final VoidCallback onJoin;
  const _PlayerDot({
    required this.pos,
    required this.slot,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final filled = slot != null;
    final uid = svc.currentUserId;
    final label = filled ? slot!.initial(uid) : '+';

    return GestureDetector(
      onTap: filled ? null : onJoin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? context.tokens.elev1 : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: filled ? context.tokens.line : context.tokens.accent, width: 1.5),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: context.tokens.fontMono,
                fontFamilyFallback: context.tokens.monoFallbacks,
                fontSize: label.length > 1 ? 9 : 10,
                fontWeight: FontWeight.w600,
                color: filled ? context.tokens.ink : context.tokens.accent,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0x80000000)
                  : const Color(0x80FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              pos,
              style: TextStyle(
                fontFamily: context.tokens.fontMono,
                fontFamilyFallback: context.tokens.monoFallbacks,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: filled ? context.tokens.ink : context.tokens.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormationLoading extends StatelessWidget {
  const _FormationLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _FormationError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _FormationError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.tokens.elev2,
          border: Border.all(color: context.tokens.line),
          borderRadius: BorderRadius.circular(context.tokens.r3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 32, color: context.tokens.warn),
            const SizedBox(height: 10),
            Text(
              context.l10n.pickup_detail_formation_load_failed,
              style: TextStyle(color: context.tokens.inkSub, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.tokens.inkDim, fontSize: 11),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Text(
                  context.l10n.common_retry,
                  style: TextStyle(color: context.tokens.ink, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (l.pickup_detail_detail_level, '${l.level_mid} · 有基础'),
      (l.pickup_detail_detail_headcount, '10 v 10'),
      (l.pickup_detail_detail_field, '天然草 · 露天'),
      (l.pickup_detail_detail_parking, '场地内可停'),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.pickup_detail_details),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    items[i].$1,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.tokens.inkSub,
                    ),
                  ),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1)
              Divider(height: 1, color: context.tokens.line),
          ],
        ],
      ),
    );
  }
}

class _MiniMap extends StatefulWidget {
  final String venue;
  final String? address;
  final double? lat;
  final double? lng;
  const _MiniMap({
    required this.venue,
    this.address,
    this.lat,
    this.lng,
  });

  @override
  State<_MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<_MiniMap> {
  String? _distanceKm;

  @override
  void initState() {
    super.initState();
    _computeDistance();
  }

  Future<void> _computeDistance() async {
    if (widget.lat == null || widget.lng == null) return;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null || !mounted) return;
      final meters = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, widget.lat!, widget.lng!,
      );
      if (mounted) {
        setState(() => _distanceKm = (meters / 1000).toStringAsFixed(1));
      }
    } catch (_) {}
  }

  String get venue => widget.venue;
  String? get address => widget.address;
  double? get lat => widget.lat;
  double? get lng => widget.lng;
  bool get _canNavigate => lat != null && lng != null;

  void _openNav(BuildContext context) {
    if (!_canNavigate) return;
    MapLauncher.openNavigation(
      context: context,
      lat: lat!,
      lng: lng!,
      name: venue.isEmpty ? (address ?? '') : venue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detailText = (address != null && address!.trim().isNotEmpty)
        ? address!
        : venue;
    final distLabel = _distanceKm != null
        ? l.pickup_detail_location_km(_distanceKm!)
        : l.pickup_detail_location;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(distLabel),
          if (detailText.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detailText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: context.tokens.inkSub,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _canNavigate ? () => _openNav(context) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.tokens.r2),
              child: PickupMiniMap(lat: lat, lng: lng),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomCta extends ConsumerWidget {
  final String pickupId;
  const _BottomCta({required this.pickupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(pickupSlotsProvider(pickupId));
    final uid = svc.currentUserId;
    final joined = slotsAsync.maybeWhen(
      data: (slots) => slots.any((s) => s.userId == uid),
      orElse: () => false,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.pickup_detail_aa_fee,
                style: TextStyle(
                  fontSize: 11,
                  color: context.tokens.inkDim,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              const N('¥50', size: 18, weight: FontWeight.w700),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 180,
            child: PrimaryButton(
              onPressed: joined
                  ? null
                  : () {
                      showToast(
                        context,
                        context.l10n.pickup_detail_tap_empty_slot,
                      );
                    },
              disabled: joined,
              variant: joined ? BtnVariant.secondary : BtnVariant.primary,
              size: BtnSize.lg,
              child: joined
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 16, color: context.tokens.ink),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.pickup_detail_already_joined,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.tokens.ink,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      context.l10n.pickup_detail_select_position,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.accentInk,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
