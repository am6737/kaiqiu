import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class BracketPanel extends ConsumerWidget {
  final String eventId;
  const BracketPanel({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(eventMatchesProvider(eventId))
        .when(
          data: (matches) => BracketLayout(eventId: eventId, matches: matches),
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

class BracketLayout extends StatelessWidget {
  final String eventId;
  final List<Match> matches;
  const BracketLayout({super.key, required this.eventId, required this.matches});

  @override
  Widget build(BuildContext context) {
    final league = matches.where((m) => m.round == 'league').toList();
    if (league.isNotEmpty) {
      return _LeagueSchedule(eventId: eventId, matches: league);
    }

    final qf = matches.where((m) => m.round == 'qf').toList();
    final sf = matches.where((m) => m.round == 'sf').toList();
    final finals = matches.where((m) => m.round == 'final').toList();
    final finalMatch = finals.isNotEmpty ? finals.first : null;

    if (qf.isEmpty && sf.isEmpty && finalMatch == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Label(context.l10n.event_bracket_waiting)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 500,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(context.l10n.event_bracket_qf),
                    const SizedBox(height: 10),
                    if (qf.isEmpty)
                      const EmptyCell(text: 'TBD')
                    else
                      for (final m in qf) MatchCard(eventId: eventId, m: m),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(context.l10n.event_bracket_sf),
                      const SizedBox(height: 36),
                      if (sf.isEmpty)
                        const EmptyCell(text: 'TBD')
                      else ...[
                        MatchCard(eventId: eventId, m: sf[0]),
                        if (sf.length > 1) ...[
                          const SizedBox(height: 60),
                          MatchCard(eventId: eventId, m: sf[1]),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Label(context.l10n.event_bracket_final),
                      const SizedBox(height: 10),
                      if (finalMatch == null)
                        const EmptyCell(text: 'TBD')
                      else
                        MatchCard(
                          eventId: eventId,
                          m: finalMatch,
                          isFinal: true,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueSchedule extends StatelessWidget {
  final String eventId;
  final List<Match> matches;
  const _LeagueSchedule({required this.eventId, required this.matches});

  @override
  Widget build(BuildContext context) {
    final sorted = [...matches]..sort((a, b) {
      final at = a.playedAt, bt = b.playedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });

    final grouped = <String, List<Match>>{};
    for (final m in sorted) {
      final key = m.playedAt != null
          ? '${m.playedAt!.year}-${m.playedAt!.month.toString().padLeft(2, '0')}-${m.playedAt!.day.toString().padLeft(2, '0')}'
          : '—';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.inkSub,
                ),
              ),
            ),
            for (final m in entry.value)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MatchCard(eventId: eventId, m: m),
              ),
          ],
        ],
      ),
    );
  }
}

class EmptyCell extends StatelessWidget {
  final String text;
  const EmptyCell({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.tokens.elev2,
      border: Border.all(color: context.tokens.line, style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(context.tokens.r2),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: 11,
        color: context.tokens.inkDim,
      ),
    ),
  );
}

class MatchCard extends StatelessWidget {
  final String eventId;
  final Match m;
  final bool isFinal;
  const MatchCard({
    super.key,
    required this.eventId,
    required this.m,
    this.isFinal = false,
  });

  @override
  Widget build(BuildContext context) {
    final sa = m.scoreA;
    final sb = m.scoreB;
    final aWins = m.status == MatchStatus.finished && sa != null && sb != null && sa > sb;
    final bWins = m.status == MatchStatus.finished && sa != null && sb != null && sb > sa;
    final timeStr = m.playedAt != null
        ? '${m.playedAt!.month.toString().padLeft(2, '0')}-${m.playedAt!.day.toString().padLeft(2, '0')} ${m.playedAt!.hour.toString().padLeft(2, '0')}:${m.playedAt!.minute.toString().padLeft(2, '0')}'
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isFinal ? context.tokens.accentSubtle : context.tokens.elev2,
        border: Border.all(
          color: isFinal ? context.tokens.accent : context.tokens.line,
          width: isFinal ? 1.2 : 1,
        ),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/event/$eventId/match/${m.id}'),
          child: Padding(
            padding: EdgeInsets.all(isFinal ? 0 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFinal)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.tokens.accent, width: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, size: 14, color: context.tokens.accent),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.event_bracket_champion,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(isFinal ? 10 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (m.status == MatchStatus.live)
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      if (m.status == MatchStatus.live) const SizedBox(height: 4),
                      _teamLine(
                        context,
                        m.teamALabel ?? 'TBD',
                        sa,
                        won: aWins,
                        showWinnerIcon: isFinal,
                      ),
                      const SizedBox(height: 4),
                      _teamLine(
                        context,
                        m.teamBLabel ?? 'TBD',
                        sb,
                        won: bWins,
                        showWinnerIcon: isFinal,
                      ),
                      if (m.pkScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'PK ${m.pkScore}',
                                style: TextStyle(
                                  fontFamily: context.tokens.fontMono,
                                  fontFamilyFallback: context.tokens.monoFallbacks,
                                  fontSize: 9,
                                  color: context.tokens.warn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (timeStr != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            timeStr,
                            style: TextStyle(
                              fontFamily: context.tokens.fontMono,
                              fontFamilyFallback: context.tokens.monoFallbacks,
                              fontSize: 10,
                              color: context.tokens.inkDim,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamLine(
    BuildContext context,
    String name,
    int? score, {
    required bool won,
    bool showWinnerIcon = false,
  }) {
    final nameColor = m.status == MatchStatus.finished ? (won ? context.tokens.ink : context.tokens.inkSub) : context.tokens.inkSub;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (showWinnerIcon && won) ...[
                Icon(Icons.emoji_events, size: 12, color: context.tokens.accent),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: nameColor,
                    fontWeight: won ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (m.status == MatchStatus.finished && score != null)
          N(
            '$score',
            size: 13,
            weight: FontWeight.w700,
            color: won ? context.tokens.accent : context.tokens.inkSub,
          )
        else
          Text('-', style: TextStyle(color: context.tokens.inkDim, fontSize: 11)),
      ],
    );
  }
}
