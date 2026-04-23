import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../models/profile.dart';
import '../../../providers.dart';
import '../../../repositories/goals_repository.dart';
import '../../../widgets/network_avatar.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';
import 'standings_panel.dart' show StatCell;

// ─────────────────────────────────────────────────────────────
// Scorers panel
// ─────────────────────────────────────────────────────────────
class ScorersPanel extends ConsumerWidget {
  final String eventId;
  const ScorersPanel({super.key, required this.eventId});
  static const _medal = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventScorersProvider(eventId));
    return async.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            context.l10n.error_load_failed,
            style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
          ),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                context.l10n.event_scorers_goals,
                style: TextStyle(color: context.tokens.inkSub, fontSize: 12),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              GoldenBootHero(
                row: rows[0],
                onTap: () =>
                    _showScorerSheet(context, eventId: eventId, row: rows[0]),
              ),
              if (rows.length >= 2)
                MedalCard(
                  rank: 2,
                  row: rows[1],
                  kind: MedalKind.silver,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[1]),
                ),
              if (rows.length >= 3)
                MedalCard(
                  rank: 3,
                  row: rows[2],
                  kind: MedalKind.bronze,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[2]),
                ),
              for (int i = 3; i < rows.length; i++)
                ScorerCard(
                  rank: i + 1,
                  row: rows[i],
                  medal: _medal,
                  onTap: () =>
                      _showScorerSheet(context, eventId: eventId, row: rows[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Golden boot hero
// ─────────────────────────────────────────────────────────────
class GoldenBootHero extends ConsumerWidget {
  final ScorerRow row;
  final VoidCallback? onTap;

  const GoldenBootHero({super.key, required this.row, this.onTap});

  static const _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final radius = BorderRadius.circular(context.tokens.r3);
    final perMatch = row.matches > 0
        ? (row.goals / row.matches).toStringAsFixed(2)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0x14FFD700),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x66FFD700)),
              borderRadius: radius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _gold, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatar(
                    row.name,
                    url: avatarUrl,
                    size: 96,
                    square: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(
                        l.event_scorers_golden_boot,
                        color: context.tokens.accent,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (perMatch != null)
                        Label(l.event_scorers_per_match(perMatch))
                      else
                        Label(l.archive_teammates_matches(row.matches)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    N(
                      '${row.goals}',
                      size: 32,
                      weight: FontWeight.w800,
                      color: context.tokens.accent,
                    ),
                    Label(l.event_scorers_goals),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Medal card
// ─────────────────────────────────────────────────────────────
enum MedalKind { silver, bronze }

class MedalCard extends ConsumerWidget {
  final ScorerRow row;
  final int rank;
  final MedalKind kind;
  final VoidCallback? onTap;

  const MedalCard({
    super.key,
    required this.row,
    required this.rank,
    required this.kind,
    this.onTap,
  });

  Color get _medalColor => kind == MedalKind.silver
      ? const Color(0xFFC0C0C0)
      : const Color(0xFFCD7F32);

  Color get _medalBorder => kind == MedalKind.silver
      ? const Color(0x66C0C0C0)
      : const Color(0x66CD7F32);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    final radius = BorderRadius.circular(context.tokens.r2);
    final perMatch = row.matches > 0
        ? (row.goals / row.matches).toStringAsFixed(2)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.tokens.elev2,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _medalBorder),
              borderRadius: radius,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _medalColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontFamily: context.tokens.fontMono,
                      fontFamilyFallback: context.tokens.monoFallbacks,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _medalColor, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: NetworkAvatar(
                    row.name,
                    url: avatarUrl,
                    size: 72,
                    square: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (perMatch != null)
                        Label(l.event_scorers_per_match(perMatch))
                      else
                        Label(l.archive_teammates_matches(row.matches)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    N(
                      '${row.goals}',
                      size: 24,
                      weight: FontWeight.w700,
                      color: context.tokens.accent,
                    ),
                    Label(l.event_scorers_goals),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scorer card
// ─────────────────────────────────────────────────────────────
class ScorerCard extends ConsumerWidget {
  final int rank;
  final ScorerRow row;
  final List<Color> medal;
  final VoidCallback? onTap;
  const ScorerCard({
    super.key,
    required this.rank,
    required this.row,
    required this.medal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = BorderRadius.circular(context.tokens.r2);
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final avatarUrl = profileAsync.valueOrNull?.avatarUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.tokens.elev2,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.tokens.line),
              borderRadius: radius,
            ),
            child: _buildRow(context, avatarUrl),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String? avatarUrl) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Center(
            child: rank <= 3
                ? Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: medal[rank - 1],
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Colors.black,
                      ),
                    ),
                  )
                : N(
                    '$rank',
                    size: 14,
                    weight: FontWeight.w600,
                    color: context.tokens.inkSub,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        NetworkAvatar(row.name, url: avatarUrl, size: 48, square: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.ink,
                ),
              ),
              Label(context.l10n.archive_teammates_matches(row.matches)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            N('${row.goals}', size: 22, weight: FontWeight.w700, color: context.tokens.accent),
            Label(context.l10n.event_scorers_goals),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scorer sheet (bottom sheet)
// ─────────────────────────────────────────────────────────────
Future<void> _showScorerSheet(
  BuildContext context, {
  required String eventId,
  required ScorerRow row,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ScorerSheet(eventId: eventId, row: row),
  );
}

class ScorerSheet extends ConsumerWidget {
  final String eventId;
  final ScorerRow row;
  const ScorerSheet({super.key, required this.eventId, required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ratings = ref.watch(eventPlayerRatingsProvider(eventId));
    final profileAsync = row.scorerId == null
        ? const AsyncValue<Profile?>.data(null)
        : ref.watch(profileByIdProvider(row.scorerId!));
    final profile = profileAsync.valueOrNull;

    PlayerRatingRow? rating;
    final ratingList = ratings.valueOrNull;
    if (ratingList != null && row.scorerId != null) {
      for (final r in ratingList) {
        if (r.rateeId == row.scorerId) {
          rating = r;
          break;
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.tokens.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NetworkAvatar(row.name, url: profile?.avatarUrl, size: 96, square: true),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                      ),
                      if (_metaLine(profile).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _metaLine(profile),
                          style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatCell(
                    value: '${row.goals}',
                    label: l.event_scorers_goals,
                    accent: context.tokens.accent,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${row.matches}',
                    label: l.player_card_mp,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: rating != null
                        ? rating.avgScore.toStringAsFixed(1)
                        : '—',
                    label: l.player_card_rating,
                    sub: rating != null
                        ? l.event_rating_n_voters_inline(rating.votes)
                        : null,
                  ),
                ),
              ],
            ),
            if (profile != null &&
                (profile.height != null ||
                    (profile.foot != null && profile.foot!.isNotEmpty))) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Row(
                  children: [
                    if (profile.height != null)
                      Expanded(
                        child: InlineStat(
                          label: l.profile_edit_height,
                          value: '${profile.height}',
                        ),
                      ),
                    if (profile.foot != null && profile.foot!.isNotEmpty)
                      Expanded(
                        child: InlineStat(
                          label: l.profile_edit_foot,
                          value: _footLabel(l, profile.foot!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _metaLine(Profile? p) {
    if (p == null) return '';
    final parts = <String>[];
    if (p.position != null && p.position!.isNotEmpty) parts.add(p.position!);
    if (p.city != null && p.city!.isNotEmpty) {
      if (p.district != null && p.district!.isNotEmpty) {
        parts.add('${p.city} · ${p.district}');
      } else {
        parts.add(p.city!);
      }
    }
    return parts.join(' · ');
  }

  String _footLabel(AppL10n l, String raw) {
    switch (raw.toLowerCase()) {
      case 'left':
        return l.profile_edit_foot_left;
      case 'right':
        return l.profile_edit_foot_right;
      case 'both':
        return l.profile_edit_foot_both;
      default:
        return raw;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Inline stat
// ─────────────────────────────────────────────────────────────
class InlineStat extends StatelessWidget {
  final String label;
  final String value;
  const InlineStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Label(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.tokens.ink,
          ),
        ),
      ],
    );
  }
}
