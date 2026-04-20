// pickup_detail_screen.dart — 球局详情 + 阵型图 (real slots + tap-to-join)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/pickup.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart' as svc;
import '../../theme/tokens.dart';
import '../../utils/share_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/avatar.dart';
import '../../widgets/live_pill.dart';
import '../../widgets/photo_halftone.dart';
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
      backgroundColor: T.bg,
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
                _VenueInfo(),
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
                _MiniMap(),
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
    return Stack(
      children: [
        const PhotoHalftone(label: '场地外景 · 龙岗体育中心 3号场', height: 200, hue: 140),
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
                  await LocalStore.toggleFavoritePickup(pickupId);
                },
                color: faved ? T.live : T.ink,
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
  final Color color;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.color = T.ink,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0x80000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _VenueInfo extends StatelessWidget {
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
              Label(context.l10n.pickup_detail_open_need_n(3), color: T.live),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '龙岗体育中心 3号场',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: T.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.calendar_today, size: 13, color: T.inkSub),
              SizedBox(width: 5),
              N('今晚 19:30 · 2小时', size: 13, color: T.inkSub),
              SizedBox(width: 14),
              Icon(Icons.currency_yen, size: 13, color: T.inkSub),
              SizedBox(width: 2),
              N('50 AA', size: 13, color: T.inkSub),
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
        color: T.elev2,
        border: Border.all(color: T.line),
        borderRadius: BorderRadius.circular(T.r3),
      ),
      child: Row(
        children: [
          const Avatar(hostName, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      hostName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: T.ink,
                      ),
                    ),
                    SizedBox(width: 6),
                    _CreditBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Label(l.pickup_detail_host_stats(28, 100)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => launchUrl(Uri(scheme: 'tel', path: '10010')),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: T.elev3,
                border: Border.all(color: T.line),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, size: 14, color: T.ink),
            ),
          ),
          PrimaryButton(
            label: followed ? l.common_unfollow : l.common_follow,
            variant: followed ? BtnVariant.secondary : BtnVariant.ghost,
            size: BtnSize.sm,
            onPressed: () async {
              await LocalStore.toggleFollowUser(hostName);
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

class _CreditBadge extends StatelessWidget {
  const _CreditBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: T.liveDim,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        context.l10n.pickup_detail_credit_n(98),
        style: const TextStyle(
          fontFamily: T.fontMono,
          fontFamilyFallback: T.monoFallbacks,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: T.live,
          letterSpacing: 0.5,
        ),
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
              Row(
                children: [
                  N(
                    '$filledCount',
                    size: 12,
                    weight: FontWeight.w600,
                    color: T.live,
                  ),
                  N(
                    context.l10n.pickup_detail_slots_filled_of(
                        _formation.length),
                    size: 12,
                    color: T.inkSub,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              const h = 340.0;
              return Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HSLColor.fromAHSL(1, 150, 0.25, 0.20).toColor(),
                      HSLColor.fromAHSL(1, 150, 0.25, 0.16).toColor(),
                    ],
                  ),
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r3),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _FieldPainter()),
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
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0x33FFFFFF)
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
      Paint()..color = const Color(0x4DFFFFFF),
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
  bool shouldRepaint(covariant _FieldPainter old) => false;
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
              color: filled ? T.elev1 : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: filled ? T.line : T.live, width: 1.5),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: label.length > 1 ? 9 : 10,
                fontWeight: FontWeight.w600,
                color: filled ? T.ink : T.live,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0x80000000),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              pos,
              style: TextStyle(
                fontFamily: T.fontMono,
                fontFamilyFallback: T.monoFallbacks,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: filled ? T.ink : T.live,
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
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r3),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: T.live, strokeWidth: 2),
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
          color: T.elev2,
          border: Border.all(color: T.line),
          borderRadius: BorderRadius.circular(T.r3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 32, color: T.warn),
            const SizedBox(height: 10),
            Text(
              context.l10n.pickup_detail_formation_load_failed,
              style: const TextStyle(color: T.inkSub, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: T.inkDim, fontSize: 11),
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
                  color: T.elev3,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Text(
                  context.l10n.common_retry,
                  style: const TextStyle(color: T.ink, fontSize: 13),
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: [
              for (final (k, v) in items)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: T.elev2,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(T.r2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Label(k),
                      const SizedBox(height: 4),
                      Text(
                        v,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: T.ink,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(context.l10n.pickup_detail_location_km('2.4')),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(T.r2),
            child: Container(
              height: 120,
              color: const Color(0xFF0E1310),
              child: CustomPaint(painter: _MiniMapPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()..color = const Color(0x0AFFFFFF);
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    final road = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 60), Offset(size.width, 70), road);
    canvas.drawCircle(
      Offset(size.width / 2, 60),
      12,
      Paint()
        ..color = const Color(0x4D00FF85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(size.width / 2, 60), 5, Paint()..color = T.live);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => false;
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
      decoration: const BoxDecoration(
        color: T.elev1,
        border: Border(top: BorderSide(color: T.line, width: 1)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.pickup_detail_aa_fee,
                style: const TextStyle(
                  fontSize: 11,
                  color: T.inkDim,
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
                        const Icon(Icons.check, size: 16, color: T.ink),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.pickup_detail_already_joined,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: T.ink,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      context.l10n.pickup_detail_select_position,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
