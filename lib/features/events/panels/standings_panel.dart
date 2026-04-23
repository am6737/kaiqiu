import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/demo_team_assets.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../widgets/team_badge.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

// ─────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────
class StandingRow {
  final String team;
  int rank = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0, pts = 0;
  StandingRow({required this.team});
}

// ─────────────────────────────────────────────────────────────
// Computation
// ─────────────────────────────────────────────────────────────
List<StandingRow> computeStandings(List<Match> matches) {
  final agg = <String, StandingRow>{};
  StandingRow bump(String k) => agg.putIfAbsent(k, () => StandingRow(team: k));
  for (final m in matches) {
    if (m.status != MatchStatus.finished || m.scoreA == null || m.scoreB == null) continue;
    final a = bump(m.teamALabel ?? 'TBD');
    final b = bump(m.teamBLabel ?? 'TBD');
    a.gf += m.scoreA!;
    a.ga += m.scoreB!;
    b.gf += m.scoreB!;
    b.ga += m.scoreA!;
    if (m.scoreA! > m.scoreB!) {
      a.w++;
      b.l++;
      a.pts += 3;
    } else if (m.scoreA! < m.scoreB!) {
      b.w++;
      a.l++;
      b.pts += 3;
    } else {
      a.d++;
      b.d++;
      a.pts++;
      b.pts++;
    }
  }
  final list = agg.values.toList()
    ..sort((x, y) {
      if (y.pts != x.pts) return y.pts.compareTo(x.pts);
      final xd = x.gf - x.ga, yd = y.gf - y.ga;
      if (yd != xd) return yd.compareTo(xd);
      return y.gf.compareTo(x.gf);
    });
  for (int i = 0; i < list.length; i++) {
    list[i].rank = i + 1;
  }
  return list;
}

// ─────────────────────────────────────────────────────────────
// Panel
// ─────────────────────────────────────────────────────────────
class StandingsPanel extends ConsumerWidget {
  final String eventId;
  const StandingsPanel({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(eventMatchesProvider(eventId))
        .when(
          data: (matches) {
            final rows = computeStandings(matches);
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Label(context.l10n.event_standings_empty2),
                ),
              );
            }
            return StandingsTable(rows: rows, matches: matches);
          },
          loading: () => Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator(color: context.tokens.accent)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '${context.l10n.error_load_failed}: $e',
                style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
              ),
            ),
          ),
        );
  }
}

// ─────────────────────────────────────────────────────────────
// Table
// ─────────────────────────────────────────────────────────────
class StandingsTable extends StatelessWidget {
  final List<StandingRow> rows;
  final List<Match> matches;
  const StandingsTable({super.key, required this.rows, required this.matches});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          if (rows.length >= 2)
            StandingsHero(top: rows[0], runner: rows[1], allMatches: matches),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 24, child: Label(l.event_standings_rank)),
                const SizedBox(width: 10),
                Expanded(child: Label(l.event_standings_team)),
                SizedBox(
                  width: 32,
                  child: Center(child: Label(l.event_standings_wins)),
                ),
                SizedBox(
                  width: 32,
                  child: Center(child: Label(l.event_standings_draws)),
                ),
                SizedBox(
                  width: 32,
                  child: Center(child: Label(l.event_standings_losses)),
                ),
                SizedBox(
                  width: 40,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Label(l.event_standings_points),
                  ),
                ),
              ],
            ),
          ),
          for (final s in rows)
            Material(
              color: s.rank <= 2 ? const Color(0x0800FF85) : Colors.transparent,
              child: InkWell(
                onTap: () =>
                    showTeamSheet(context, standing: s, allMatches: matches),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: N(
                          '${s.rank}',
                          size: 13,
                          weight: FontWeight.w600,
                          color: s.rank <= 2 ? context.tokens.accent : context.tokens.inkSub,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            TeamBadge(
                              name: s.team,
                              logoUrl: DemoTeamAssets.forTeamName(s.team).logoUrl,
                              size: 44,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.team,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.tokens.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.w}', size: 12, color: context.tokens.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.d}', size: 12, color: context.tokens.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: N('${s.l}', size: 12, color: context.tokens.inkSub),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: N(
                            '${s.pts}',
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Team sheet (bottom sheet)
// ─────────────────────────────────────────────────────────────
Future<void> showTeamSheet(
  BuildContext context, {
  required StandingRow standing,
  required List<Match> allMatches,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.elev1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => TeamSheet(standing: standing, allMatches: allMatches),
  );
}

class TeamSheet extends StatelessWidget {
  final StandingRow standing;
  final List<Match> allMatches;
  const TeamSheet({super.key, required this.standing, required this.allMatches});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final own = standing.team;
    final teamMatches =
        allMatches
            .where((m) => m.teamALabel == own || m.teamBLabel == own)
            .toList()
          ..sort((a, b) {
            final at = a.playedAt, bt = b.playedAt;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
    final gd = standing.gf - standing.ga;
    final hue = (standing.rank * 50).toDouble() % 360;
    final teamColor = HSLColor.fromAHSL(1, hue, 0.35, 0.3).toColor();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: teamColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        standing.team,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${standing.rank}',
                        style: TextStyle(
                          fontFamily: context.tokens.fontMono,
                          fontFamilyFallback: context.tokens.monoFallbacks,
                          fontSize: 12,
                          color: context.tokens.inkSub,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Label(l.team_card_summary),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: StatCell(
                      value: '${standing.pts}',
                      label: l.event_standings_points,
                      accent: context.tokens.accent,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      value: '${standing.w}',
                      label: l.event_standings_wins,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      value: '${standing.d}',
                      label: l.event_standings_draws,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      value: '${standing.l}',
                      label: l.event_standings_losses,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: StatCell(
                      value: '${standing.gf}',
                      label: l.team_card_gf,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      value: '${standing.ga}',
                      label: l.team_card_ga,
                    ),
                  ),
                  Expanded(
                    child: StatCell(
                      value: gd > 0 ? '+$gd' : '$gd',
                      label: l.team_card_gd,
                      accent: gd > 0
                          ? context.tokens.accent
                          : gd < 0
                          ? context.tokens.inkSub
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Label('${l.team_card_matches} · ${teamMatches.length}'),
            const SizedBox(height: 8),
            Expanded(
              child: teamMatches.isEmpty
                  ? Center(child: Label(l.event_standings_empty2))
                  : ListView.separated(
                      controller: scroll,
                      padding: EdgeInsets.zero,
                      itemCount: teamMatches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) =>
                          TeamMatchRow(match: teamMatches[i], ownTeam: own),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Team match row
// ─────────────────────────────────────────────────────────────
class TeamMatchRow extends StatelessWidget {
  final Match match;
  final String ownTeam;
  const TeamMatchRow({super.key, required this.match, required this.ownTeam});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isHome = match.teamALabel == ownTeam;
    final opponent = (isHome ? match.teamBLabel : match.teamALabel) ?? '—';
    final ownScore = isHome ? match.scoreA : match.scoreB;
    final oppScore = isHome ? match.scoreB : match.scoreA;

    String? resultLabel;
    Color? resultColor;
    if (match.status == MatchStatus.finished && ownScore != null && oppScore != null) {
      if (ownScore > oppScore) {
        resultLabel = l.event_standings_wins;
        resultColor = context.tokens.accent;
      } else if (ownScore < oppScore) {
        resultLabel = l.event_standings_losses;
        resultColor = context.tokens.inkSub;
      } else {
        resultLabel = l.event_standings_draws;
        resultColor = context.tokens.inkMute;
      }
    }

    final dateStr = match.playedAt != null
        ? '${match.playedAt!.month.toString().padLeft(2, '0')}/'
              '${match.playedAt!.day.toString().padLeft(2, '0')}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          if (resultLabel != null) ...[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: resultColor!.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                resultLabel,
                style: TextStyle(
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: resultColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              opponent,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: context.tokens.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (match.status == MatchStatus.finished && ownScore != null && oppScore != null)
            N(
              '$ownScore - $oppScore',
              size: 13,
              weight: FontWeight.w700,
              color: resultColor ?? context.tokens.ink,
            )
          else
            Text('-', style: TextStyle(color: context.tokens.inkDim, fontSize: 12)),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(width: 10),
            N(dateStr, size: 11, color: context.tokens.inkDim),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Standings hero
// ─────────────────────────────────────────────────────────────
class StandingsHero extends StatelessWidget {
  final StandingRow top;
  final StandingRow runner;
  final List<Match> allMatches;

  const StandingsHero({
    super.key,
    required this.top,
    required this.runner,
    required this.allMatches,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final diff = top.pts - runner.pts;
    final accent = context.tokens.accent;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: accent.withAlpha(0x66)),
        borderRadius: BorderRadius.circular(context.tokens.r3),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Label(l.event_standings_leaders_label),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: StandingsHeroSide(
                  standing: top,
                  subLabel: l.event_standings_leader_top,
                  subLabelColor: accent,
                  allMatches: allMatches,
                ),
              ),
              SizedBox(
                width: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        N(
                          '${top.pts}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: accent,
                        ),
                        Text(
                          ' - ',
                          style: TextStyle(
                            color: context.tokens.inkDim,
                            fontSize: 18,
                          ),
                        ),
                        N(
                          '${runner.pts}',
                          size: 40,
                          weight: FontWeight.w800,
                          color: context.tokens.ink,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Label(l.event_standings_points_diff(diff)),
                  ],
                ),
              ),
              Expanded(
                child: StandingsHeroSide(
                  standing: runner,
                  subLabel: l.event_standings_leader_runner,
                  subLabelColor: context.tokens.inkSub,
                  allMatches: allMatches,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StandingsHeroSide extends StatelessWidget {
  final StandingRow standing;
  final String subLabel;
  final Color subLabelColor;
  final List<Match> allMatches;

  const StandingsHeroSide({
    super.key,
    required this.standing,
    required this.subLabel,
    required this.subLabelColor,
    required this.allMatches,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.tokens.r2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => showTeamSheet(
          context,
          standing: standing,
          allMatches: allMatches,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TeamBadge(
                name: standing.team,
                logoUrl: DemoTeamAssets.forTeamName(standing.team).logoUrl,
                size: 72,
              ),
              const SizedBox(height: 6),
              Text(
                standing.team,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Label(subLabel, color: subLabelColor),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared stat cell (also used by scorers_panel)
// ─────────────────────────────────────────────────────────────
class StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String? sub;
  final Color? accent;
  const StatCell({
    super.key,
    required this.value,
    required this.label,
    this.sub,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        N(value, size: 22, weight: FontWeight.w700, color: accent ?? context.tokens.ink),
        const SizedBox(height: 4),
        Label(label),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub!, style: TextStyle(fontSize: 10, color: context.tokens.inkDim)),
        ],
      ],
    );
  }
}
