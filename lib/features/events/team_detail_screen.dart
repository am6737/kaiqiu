import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/typography.dart';
import 'panels/standings_panel.dart';

class TeamDetailScreen extends ConsumerWidget {
  final String eventId;
  final String teamId;

  const TeamDetailScreen({
    super.key,
    required this.eventId,
    required this.teamId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsync = ref.watch(teamDetailProvider(teamId));
    final membersAsync = ref.watch(teamMembersProvider(teamId));

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: teamAsync.when(
        data: (team) => _Body(
          team: team,
          eventId: eventId,
          membersAsync: membersAsync,
        ),
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.tokens.danger)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final TeamRow team;
  final String eventId;
  final AsyncValue<List<TeamMember>> membersAsync;

  const _Body({
    required this.team,
    required this.eventId,
    required this.membersAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final matchesAsync = ref.watch(eventMatchesProvider(eventId));

    StandingRow? standing;
    if (matchesAsync case AsyncData(value: final matches)) {
      final standings = computeStandings(matches);
      for (final s in standings) {
        if (s.team == team.name) {
          standing = s;
          break;
        }
      }
    }

    final memberCount = membersAsync.valueOrNull?.length ?? 0;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: context.tokens.bg,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.tokens.ink),
            onPressed: () => context.pop(),
          ),
          title: Text(
            team.name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
            ),
          ),
          pinned: true,
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _HeroSection(team: team, memberCount: memberCount),
              if (standing != null) ...[
                const SizedBox(height: 16),
                _StatsCard(standing: standing, label: l.team_detail_stats),
              ],
              const SizedBox(height: 16),
              _MembersSection(membersAsync: membersAsync),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  final TeamRow team;
  final int memberCount;

  const _HeroSection({required this.team, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: context.tokens.elev3,
            borderRadius: BorderRadius.circular(20),
            image: team.logoUrl != null
                ? DecorationImage(
                    image: NetworkImage(team.logoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: team.logoUrl == null
              ? Center(
                  child: Text(
                    team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: context.tokens.inkSub,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          team.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.tokens.ink,
          ),
        ),
        if (team.slogan != null && team.slogan!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '"${team.slogan!}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: context.tokens.inkSub,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (team.captainAvatar != null)
              CircleAvatar(
                radius: 10,
                backgroundImage: NetworkImage(team.captainAvatar!),
              )
            else
              CircleAvatar(
                radius: 10,
                backgroundColor: context.tokens.elev3,
                child: Icon(Icons.person, size: 12, color: context.tokens.inkDim),
              ),
            const SizedBox(width: 6),
            Text(
              team.captainName ?? '—',
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.tokens.accentSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.team_detail_captain,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.accent,
                ),
              ),
            ),
            Text(
              '·',
              style: TextStyle(color: context.tokens.inkDim, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Text(
              l.team_detail_member_count(memberCount),
              style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final StandingRow standing;
  final String label;

  const _StatsCard({required this.standing, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
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
                    label: context.l10n.event_standings_points,
                    accent: context.tokens.accent,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${standing.w}',
                    label: context.l10n.event_standings_wins,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${standing.d}',
                    label: context.l10n.event_standings_draws,
                  ),
                ),
                Expanded(
                  child: StatCell(
                    value: '${standing.l}',
                    label: context.l10n.event_standings_losses,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final AsyncValue<List<TeamMember>> membersAsync;

  const _MembersSection({required this.membersAsync});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.team_detail_members),
          const SizedBox(height: 8),
          membersAsync.when(
            data: (members) {
              if (members.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.tokens.inkDim,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in members) _MemberRow(member: m),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  color: context.tokens.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => Text(
              '$e',
              style: TextStyle(fontSize: 12, color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMember member;
  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: context.tokens.elev3,
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Icon(Icons.person, size: 16, color: context.tokens.inkDim)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.name ?? '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.tokens.ink,
              ),
            ),
          ),
          if (member.jerseyNumber != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#${member.jerseyNumber}',
                style: TextStyle(
                  fontFamily: context.tokens.fontMono,
                  fontFamilyFallback: context.tokens.monoFallbacks,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.inkSub,
                ),
              ),
            ),
          if (member.role == 'captain')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.tokens.accentSubtle,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                l.team_detail_captain,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
