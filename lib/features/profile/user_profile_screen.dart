import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/player_profile.dart';
import '../../providers.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _dmBusy = false;

  bool get _isSelf {
    try {
      return currentUserId == widget.userId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startDm() async {
    if (_dmBusy) return;
    setState(() => _dmBusy = true);
    try {
      final convId =
          await ref.read(messagesRepoProvider).ensureDmWith(widget.userId);
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      context.push('/chat/$convId');
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('profile_incomplete')) {
        showToast(context, context.l10n.onboarding_profile_required,
            error: true);
        context.push('/onboarding');
      } else {
        showToast(context, '${context.l10n.messages_new_failed}: $e',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _dmBusy = false);
    }
  }

  void _toggleFollow() {
    ref
        .read(favoritesRepoProvider)
        .toggle(FavoriteEntity.user, widget.userId);
  }

  double _bannerHue(String id) =>
      (id.codeUnitAt(0) * 7 + id.codeUnitAt(1)) % 360.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final async = ref.watch(fullProfileByIdProvider(widget.userId));
    ref.watch(localStoreProvider);
    final following = LocalStore.isFollowing(widget.userId);

    return Scaffold(
      backgroundColor: t.bg,
      body: async.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: t.accent)),
        error: (e, _) => _buildError(e),
        data: (profile) {
          if (profile == null) return _buildNotFound();
          return _buildContent(profile, following);
        },
      ),
    );
  }

  Widget _buildError(Object e) {
    final l = context.l10n;
    final t = context.tokens;
    return SafeArea(
      child: Column(
        children: [
          _backRow(),
          Expanded(
            child: Center(
              child: Text('${l.error_load_failed}: $e',
                  style: TextStyle(color: t.inkSub, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    final l = context.l10n;
    final t = context.tokens;
    return SafeArea(
      child: Column(
        children: [
          _backRow(),
          Expanded(
            child: Center(
              child: Text(l.messages_new_dm_not_found,
                  style: TextStyle(color: t.inkSub, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backRow() {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new, size: 18, color: t.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PlayerProfile u, bool following) {
    final l = context.l10n;
    final t = context.tokens;
    final hue = _bannerHue(widget.userId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerColor = HSLColor.fromAHSL(1, hue, 0.4, isDark ? 0.18 : 0.82);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Header banner + avatar ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner: custom image or gradient fallback
              if (u.bannerUrl != null && u.bannerUrl!.isNotEmpty)
                SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    u.bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _GradientBanner(
                        color: bannerColor, isDark: isDark),
                  ),
                )
              else
                _GradientBanner(color: bannerColor, isDark: isDark),
              // Back button
              Positioned(
                top: 12,
                left: 8,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x40000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              // Avatar, overlapping the banner bottom edge
              Positioned(
                bottom: -44,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.bg,
                      shape: BoxShape.circle,
                    ),
                    child: NetworkAvatar(u.name, url: u.avatarUrl, size: 84),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),
          // ── Name ──
          Text(
            u.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: t.ink,
              letterSpacing: -0.3,
            ),
          ),
          if (u.handle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              u.handle,
              style: TextStyle(
                fontFamily: t.fontMono,
                fontFamilyFallback: t.monoFallbacks,
                fontSize: 13,
                color: t.inkSub,
              ),
            ),
          ],
          // ── Position + Location tag ──
          const SizedBox(height: 10),
          _TagsRow(profile: u),
          // ── Action buttons ──
          if (!_isSelf) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: following ? l.common_unfollow : l.common_follow,
                      variant:
                          following ? BtnVariant.ghost : BtnVariant.primary,
                      size: BtnSize.md,
                      full: true,
                      onPressed: _toggleFollow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: l.messages_new_dm,
                      variant: BtnVariant.ghost,
                      size: BtnSize.md,
                      full: true,
                      disabled: _dmBusy,
                      onPressed: _dmBusy ? null : _startDm,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // ── Stats strip (always show) ──
          _StatsStrip(stats: u.stats, rating: u.rating),
          const SizedBox(height: 16),
          // ── Info section (always show) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _InfoSection(profile: u),
          ),
          // ── Attributes ──
          if (u.attrs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AttrsCard(attrs: u.attrs),
            ),
          ],
          // ── Honors ──
          if (u.honors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _HonorsCard(honors: u.honors),
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── Tags row: position badge + location ──
class _TagsRow extends StatelessWidget {
  final PlayerProfile profile;
  const _TagsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tags = <Widget>[];

    if (profile.position.isNotEmpty) {
      tags.add(_chip(
        profile.position,
        bg: t.accentSubtle,
        fg: t.accent,
        mono: true,
        t: t,
      ));
    }
    if (profile.city.isNotEmpty) {
      final loc = [
        profile.city,
        if (profile.district.isNotEmpty) profile.district,
      ].join(' · ');
      tags.add(_chip(loc, bg: t.elev2, fg: t.inkSub, mono: false, t: t));
    }

    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: tags,
      ),
    );
  }

  Widget _chip(String text,
      {required Color bg,
      required Color fg,
      required bool mono,
      required AppTokens t}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
          fontFamily: mono ? t.fontMono : null,
          fontFamilyFallback: mono ? t.monoFallbacks : null,
        ),
      ),
    );
  }
}

// ── Stats strip ──
class _StatsStrip extends StatelessWidget {
  final PlayerStats stats;
  final int rating;
  const _StatsStrip({required this.stats, required this.rating});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Row(
        children: [
          _tile(rating > 0 ? '$rating' : '—', l.profile_mini_overall, t),
          _div(t),
          _tile('${stats.matches}', l.profile_mini_matches, t),
          _div(t),
          _tile('${stats.goals}', l.profile_mini_goals, t),
          _div(t),
          _tile('${stats.assists}', '助攻', t),
        ],
      ),
    );
  }

  Widget _tile(String value, String label, AppTokens t) => Expanded(
        child: Column(
          children: [
            N(value, size: 20, weight: FontWeight.w800, color: t.ink),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: t.inkSub)),
          ],
        ),
      );

  Widget _div(AppTokens t) =>
      Container(width: 1, height: 28, color: t.line);
}

// ── Info section: always-visible card ──
class _InfoSection extends StatelessWidget {
  final PlayerProfile profile;
  const _InfoSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <(IconData, String, String)>[
      if (profile.positionFull.isNotEmpty)
        (Icons.sports_soccer, '位置', profile.positionFull),
      if (profile.height > 0)
        (Icons.straighten, '身高', '${profile.height} cm'),
      if (profile.foot.isNotEmpty)
        (Icons.directions_walk, '惯用脚', _footLabel(profile.foot)),
      if (profile.city.isNotEmpty)
        (Icons.location_on_outlined, '所在地', [
          profile.city,
          if (profile.district.isNotEmpty) profile.district,
        ].join(' ')),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 20, thickness: 1, color: t.line),
            Row(
              children: [
                Icon(rows[i].$1, size: 18, color: t.inkDim),
                const SizedBox(width: 12),
                Text(rows[i].$2,
                    style: TextStyle(fontSize: 13, color: t.inkSub)),
                const Spacer(),
                Text(rows[i].$3,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.ink)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _footLabel(String f) => switch (f) {
        'L' => '左脚',
        'R' => '右脚',
        _ => '双脚',
      };
}

// ── Attributes card ──
class _AttrsCard extends StatelessWidget {
  final Map<String, int> attrs;
  const _AttrsCard({required this.attrs});

  static const _labels = {
    'speed': '速度',
    'shooting': '射门',
    'passing': '传球',
    'defense': '防守',
    'stamina': '体力',
    'technique': '技术',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entries =
        _labels.entries.where((e) => attrs.containsKey(e.key)).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('能力值',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 14),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                      width: 36,
                      child: Text(e.value,
                          style: TextStyle(fontSize: 12, color: t.inkSub))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (attrs[e.key] ?? 0) / 100,
                        minHeight: 6,
                        backgroundColor: t.elev3,
                        color: _barColor(attrs[e.key] ?? 0, t),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${attrs[e.key] ?? 0}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                        fontFamily: t.fontMono,
                        fontFamilyFallback: t.monoFallbacks,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _barColor(int v, AppTokens t) {
    if (v >= 80) return t.accent;
    if (v >= 50) return t.warn;
    return t.inkDim;
  }
}

// ── Honors card ──
class _HonorsCard extends StatelessWidget {
  final List<PlayerHonor> honors;
  const _HonorsCard({required this.honors});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.elev2,
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('荣誉',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: t.ink)),
          const SizedBox(height: 12),
          for (final h in honors)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, size: 18, color: t.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${h.year}  ${h.title}',
                        style: TextStyle(fontSize: 13, color: t.ink)),
                  ),
                  if (h.meta != null)
                    Text(h.meta!,
                        style: TextStyle(fontSize: 12, color: t.inkDim)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Gradient banner fallback ──
class _GradientBanner extends StatelessWidget {
  final HSLColor color;
  final bool isDark;
  const _GradientBanner({required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.toColor(),
            color.withLightness(isDark ? 0.12 : 0.72).toColor(),
          ],
        ),
      ),
    );
  }
}
