// match_ratings_screen.dart — 单场比赛评分排行（独立子页）
//
// 展示一场比赛的球员评分排行：比分条 + A/B 队筛选 + 球员列表。
// 点击球员展开详情；底部固定 CTA 跳到 /rate/:matchId 进入打分。
//
// 数据来自 `matchPlayerRatingsProvider`（与原 RatingsPanel 相同），
// 不走赛事级聚合，删除 RatingsPanel 后的唯一入口。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../models/rating.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';
import '../../widgets/user_card_sheet.dart';

class MatchRatingsScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String matchId;
  const MatchRatingsScreen({
    super.key,
    required this.eventId,
    required this.matchId,
  });

  @override
  ConsumerState<MatchRatingsScreen> createState() => _MatchRatingsScreenState();
}

class _MatchRatingsScreenState extends ConsumerState<MatchRatingsScreen> {
  String _teamFilter = 'all'; // 'all' / 'a' / 'b'
  PlayerRatingRow? _selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final matchesAsync = ref.watch(eventMatchesProvider(widget.eventId));

    return Scaffold(
      backgroundColor: context.tokens.bg,
      appBar: AppBar(
        backgroundColor: context.tokens.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: context.tokens.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l.match_ratings_title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        shape: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      body: eventAsync.when(
        loading: () => const _RatingsLoading(),
        error: (e, _) => _RatingsError(e),
        data: (event) => matchesAsync.when(
          loading: () => const _RatingsLoading(),
          error: (e, _) => _RatingsError(e),
          data: (matches) {
            Match? match;
            for (final m in matches) {
              if (m.id == widget.matchId) {
                match = m;
                break;
              }
            }
            if (match == null) {
              return Center(
                child: Text(
                  l.match_not_found,
                  style: TextStyle(color: context.tokens.inkSub, fontSize: 13),
                ),
              );
            }
            return _Body(
              event: event,
              match: match,
              selected: _selected,
              teamFilter: _teamFilter,
              onSelect: (p) => setState(() => _selected = p),
              onBackFromDetail: () => setState(() => _selected = null),
              onFilter: (f) => setState(() => _teamFilter = f),
            );
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Event event;
  final Match match;
  final PlayerRatingRow? selected;
  final String teamFilter;
  final ValueChanged<PlayerRatingRow> onSelect;
  final VoidCallback onBackFromDetail;
  final ValueChanged<String> onFilter;

  const _Body({
    required this.event,
    required this.match,
    required this.selected,
    required this.teamFilter,
    required this.onSelect,
    required this.onBackFromDetail,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selected != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: _PlayerRatingDetail(
          player: selected!,
          event: event,
          matchId: match.id,
          onBack: onBackFromDetail,
        ),
      );
    }
    final async = ref.watch(matchPlayerRatingsProvider(match));
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScoreStrip(event: event, match: match),
              async.when(
                loading: () => const _RatingsLoading(),
                error: (e, _) => _RatingsError(e),
                data: (rows) {
                  final visible = rows.where((r) => r.name != '—').toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TeamFilterRow(
                        match: match,
                        total: visible.length,
                        selected: teamFilter,
                        onChange: onFilter,
                      ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Label(context.l10n.event_rating_empty_go_rate),
                          ),
                        )
                      else
                        for (int i = 0; i < visible.length; i++)
                          GestureDetector(
                            onTap: () => onSelect(visible[i]),
                            onLongPress: () => showUserCardSheet(context, ref, userId: visible[i].rateeId),
                            child: _PlayerRow(
                              p: visible[i],
                              rank: i + 1,
                              showMomentBlock: true,
                            ),
                          ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Label(context.l10n.event_rating_tap_for_detail),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: context.tokens.bg,
              border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
            ),
            child: PrimaryButton(
              label: context.l10n.match_ratings_go_rate,
              full: true,
              size: BtnSize.lg,
              onPressed: () => context.push('/rate/${match.id}'),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Score strip
// ─────────────────────────────────────────────────────────────
class _ScoreStrip extends StatelessWidget {
  final Event event;
  final Match match;
  const _ScoreStrip({required this.event, required this.match});

  @override
  Widget build(BuildContext context) {
    final a = match.teamALabel ?? '—';
    final b = match.teamBLabel ?? '—';
    final sa = match.scoreA ?? 0;
    final sb = match.scoreB ?? 0;
    final winA = sa > sb;
    final winB = sb > sa;
    final date = match.playedAt;
    final dateStr = date == null
        ? ''
        : '${date.year.toString().padLeft(4, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.'
              '${date.day.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, 150, 0.25, 0.18).toColor(),
            HSLColor.fromAHSL(1, 150, 0.10, 0.12).toColor(),
          ],
        ),
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.accentSubtle,
                  border: Border.all(color: context.tokens.accent.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  event.name,
                  style: TextStyle(
                    fontFamily: context.tokens.fontMono,
                    fontFamilyFallback: context.tokens.monoFallbacks,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.tokens.accent,
                  ),
                ),
              ),
              if (match.round != null) ...[
                const SizedBox(width: 6),
                Label('· ${match.round}'),
              ],
              const Spacer(),
              if (dateStr.isNotEmpty)
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: context.tokens.fontMono,
                    fontFamilyFallback: context.tokens.monoFallbacks,
                    fontSize: 11,
                    color: context.tokens.inkSub,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  a,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: winA ? context.tokens.ink : context.tokens.inkSub,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              N(
                '$sa',
                size: 26,
                weight: FontWeight.w800,
                color: winA ? context.tokens.accent : context.tokens.ink,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: N(
                  '-',
                  size: 22,
                  weight: FontWeight.w800,
                  color: context.tokens.inkSub,
                ),
              ),
              N(
                '$sb',
                size: 26,
                weight: FontWeight.w800,
                color: winB ? context.tokens.accent : context.tokens.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: winB ? context.tokens.ink : context.tokens.inkSub,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// A/B filter row
// ─────────────────────────────────────────────────────────────
class _TeamFilterRow extends StatelessWidget {
  final Match match;
  final int total;
  final String selected;
  final ValueChanged<String> onChange;
  const _TeamFilterRow({
    required this.match,
    required this.total,
    required this.selected,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget chip(String value, String text) {
      final active = value == selected;
      return GestureDetector(
        onTap: () => onChange(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? context.tokens.ink : context.tokens.elev2,
            border: Border.all(color: active ? context.tokens.ink : context.tokens.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? context.tokens.bg : context.tokens.inkSub,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          chip('all', '${l.event_rating_team_all} $total'),
          const SizedBox(width: 8),
          if (match.teamALabel != null) chip('a', match.teamALabel!),
          if (match.teamALabel != null) const SizedBox(width: 8),
          if (match.teamBLabel != null) chip('b', match.teamBLabel!),
          const Spacer(),
          Label(l.event_rating_players_voted(total)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Player row
// ─────────────────────────────────────────────────────────────
class _PlayerRow extends StatelessWidget {
  final PlayerRatingRow p;
  final int rank;
  final bool showMomentBlock;
  const _PlayerRow({
    required this.p,
    required this.rank,
    this.showMomentBlock = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final you = p.rateeId == currentUserId;
    final scoreColor = p.avgScore >= 8
        ? context.tokens.accent
        : (p.avgScore >= 6 ? context.tokens.ink : context.tokens.danger);
    final hasMoment = showMomentBlock && (p.topComment?.isNotEmpty ?? false);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: rank == 1 ? context.tokens.accent : context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? context.tokens.accent
                  : (rank <= 3 ? context.tokens.elev3 : Colors.transparent),
              border: rank == 1 ? null : Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: context.tokens.fontMono,
                fontFamilyFallback: context.tokens.monoFallbacks,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: rank == 1 ? Colors.black : context.tokens.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Avatar(p.name, size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (you) _tinyBadge(context, l.rate_short_you, context.tokens.accentSubtle, context.tokens.accent),
                    if (rank == 1)
                      _tinyBadge(context, l.event_rating_mvp, context.tokens.accentSubtle, context.tokens.accent),
                    if (p.topHighlight != null && p.topHighlight!.isNotEmpty)
                      _statChip(context, p.topHighlight!),
                  ],
                ),
                const SizedBox(height: 3),
                Label(
                  [
                    if (p.position != null) p.position!,
                    l.event_rating_n_voters_inline(p.votes),
                  ].join(' · '),
                ),
                if (hasMoment) ...[
                  const SizedBox(height: 8),
                  _MomentQuote(text: p.topComment!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                N(
                  p.avgScore.toStringAsFixed(1),
                  size: 22,
                  weight: FontWeight.w800,
                  color: scoreColor,
                ),
                const SizedBox(height: 2),
                Label(l.event_rating_score_avg),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.chevron_right, size: 12, color: context.tokens.inkDim),
          ),
        ],
      ),
    );
  }

  Widget _tinyBadge(BuildContext context, String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: fg.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    ),
  );

  Widget _statChip(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x22FF6D3B),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0x55FF6D3B)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: const Color(0xFFFFB38A),
      ),
    ),
  );
}

class _MomentQuote extends StatelessWidget {
  final String text;
  const _MomentQuote({required this.text});
  @override
  Widget build(BuildContext context) {
    final trimmed = text.length > 28 ? '${text.substring(0, 28)}…' : text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.tokens.elev3,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 12, color: context.tokens.inkSub),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              trimmed,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Player detail (inline, same screen — hides list while open)
// ─────────────────────────────────────────────────────────────
final _scoreDistProvider =
    FutureProvider.family<List<int>, String>((ref, matchId) async {
  return ref.read(ratingsRepoProvider).scoreDistribution(matchId);
});

final _topCommentsProvider =
    FutureProvider.family<List<RatingComment>, String>((ref, matchId) async {
  return ref.read(ratingsRepoProvider).topComments(matchId);
});

class _PlayerRatingDetail extends ConsumerWidget {
  final VoidCallback onBack;
  final PlayerRatingRow player;
  final Event event;
  final String matchId;
  const _PlayerRatingDetail({
    required this.onBack,
    required this.player,
    required this.event,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = player;
    final dist = ref.watch(_scoreDistProvider(matchId)).valueOrNull ??
        List<int>.filled(11, 0);
    final maxD = dist.every((e) => e == 0) ? 1 : dist.reduce(math.max);
    final comments =
        ref.watch(_topCommentsProvider(matchId)).valueOrNull ?? const [];
    final you = p.rateeId == currentUserId;
    final scoreColor = p.avgScore >= 8
        ? context.tokens.accent
        : (p.avgScore >= 6 ? context.tokens.ink : context.tokens.danger);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(width: 8),
              Label(context.l10n.event_rating_player_detail),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HSLColor.fromAHSL(1, 150, 0.25, 0.18).toColor(),
                HSLColor.fromAHSL(1, 150, 0.10, 0.12).toColor(),
              ],
            ),
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(context.tokens.r3),
          ),
          child: Row(
            children: [
              Avatar(p.name, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.ink,
                          ),
                        ),
                        if (you) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: context.tokens.accentSubtle,
                              border: Border.all(
                                color: const Color(0x6600FF85),
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              context.l10n.rate_short_you,
                              style: TextStyle(
                                fontFamily: context.tokens.fontMono,
                                fontFamilyFallback: context.tokens.monoFallbacks,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: context.tokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Label(
                      [
                        if (p.position != null) p.position!,
                        event.name,
                      ].join(' · '),
                    ),
                    const SizedBox(height: 8),
                    Label(context.l10n.event_rating_players_voted(p.votes)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  N(
                    p.avgScore.toStringAsFixed(2),
                    size: 42,
                    weight: FontWeight.w800,
                    color: scoreColor,
                  ),
                  const SizedBox(height: 4),
                  Label(context.l10n.event_rating_score_avg),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(context.l10n.event_rating_distribution),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.tokens.elev2,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 70,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (int i = 0; i < dist.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                child: FractionallySizedBox(
                                  heightFactor: dist[i] / maxD,
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: i >= 8
                                          ? context.tokens.accent
                                          : i >= 6
                                          ? context.tokens.ink
                                          : i >= 4
                                          ? context.tokens.inkSub
                                          : context.tokens.danger,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(2),
                                        topRight: Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (int i = 0; i < dist.length; i++)
                          Expanded(
                            child: Center(
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  fontFamily: context.tokens.fontMono,
                                  fontFamilyFallback: context.tokens.monoFallbacks,
                                  fontSize: 9,
                                  color: context.tokens.inkDim,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Label(context.l10n.event_rating_hot_comments),
                  const Spacer(),
                  Label(context.l10n.event_rating_sort_hot),
                ],
              ),
              const SizedBox(height: 10),
              for (final c in comments)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(c.user, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            c.user,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.inkSub,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: c.score >= 8
                                  ? context.tokens.accentSubtle
                                  : c.score >= 6
                                  ? context.tokens.elev3
                                  : const Color(0x24FF3B6B),
                              border: Border.all(
                                color: c.score >= 8
                                    ? context.tokens.accent.withValues(alpha: 0.3)
                                    : c.score >= 6
                                    ? context.tokens.line
                                    : context.tokens.danger.withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              c.score.toStringAsFixed(1),
                              style: TextStyle(
                                fontFamily: context.tokens.fontMono,
                                fontFamilyFallback: context.tokens.monoFallbacks,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.score >= 8
                                    ? context.tokens.accent
                                    : c.score >= 6
                                    ? context.tokens.ink
                                    : context.tokens.danger,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Label(_relativeTime(c.createdAt)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.tokens.ink,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 12,
                            color: context.tokens.inkSub,
                          ),
                          const SizedBox(width: 4),
                          N('${c.likes}', size: 11, color: context.tokens.inkSub),
                          const SizedBox(width: 14),
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: context.tokens.inkSub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.event_rating_reply,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.tokens.inkSub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Local loading / error states
// ─────────────────────────────────────────────────────────────
class _RatingsLoading extends StatelessWidget {
  const _RatingsLoading();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(36),
    child: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
  );
}

class _RatingsError extends StatelessWidget {
  final Object error;
  const _RatingsError(this.error);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(
        '${context.l10n.error_load_failed}: $error',
        style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
      ),
    ),
  );
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return '${dt.month}-${dt.day}';
}
