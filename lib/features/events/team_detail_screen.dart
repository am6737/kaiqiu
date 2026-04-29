import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/typography.dart';
import 'panels/standings_panel.dart';
import 'widgets/bottom_cta.dart';

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
    final isCaptain = team.captainId == currentUserId;
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final teamSize = eventAsync.valueOrNull?.teamSize ?? 11;

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
              _HeroSection(team: team, memberCount: memberCount, isCaptain: isCaptain),
              if (isCaptain && memberCount < teamSize) ...[
                const SizedBox(height: 12),
                _RosterWarning(current: memberCount, total: teamSize),
              ],
              if (standing != null) ...[
                const SizedBox(height: 16),
                _StatsCard(standing: standing, label: l.team_detail_stats),
              ],
              const SizedBox(height: 16),
              _MembersSection(
                membersAsync: membersAsync,
                isCaptain: isCaptain,
                teamId: team.id,
                eventId: eventId,
                teamSize: teamSize,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends ConsumerWidget {
  final TeamRow team;
  final int memberCount;
  final bool isCaptain;

  const _HeroSection({
    required this.team,
    required this.memberCount,
    required this.isCaptain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final hasSlogan = team.slogan != null && team.slogan!.isNotEmpty;

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
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isCaptain ? () => _editSlogan(context, ref) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    hasSlogan ? team.slogan! : l.team_detail_slogan_hint,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: hasSlogan ? context.tokens.inkSub : context.tokens.inkDim,
                    ),
                  ),
                ),
                if (isCaptain) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: context.tokens.inkDim,
                  ),
                ],
              ],
            ),
          ),
        ),
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

  Future<void> _editSlogan(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final controller = TextEditingController(text: team.slogan ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.r3)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
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
            const SizedBox(height: 16),
            Text(
              l.team_detail_edit_slogan,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.tokens.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              style: TextStyle(fontSize: 14, color: context.tokens.ink),
              decoration: InputDecoration(
                hintText: l.team_detail_slogan_hint,
                hintStyle: TextStyle(color: context.tokens.inkDim),
                filled: true,
                fillColor: context.tokens.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                  borderSide: BorderSide(color: context.tokens.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                  borderSide: BorderSide(color: context.tokens.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.tokens.r2),
                  borderSide: BorderSide(color: context.tokens.accent),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text),
                style: FilledButton.styleFrom(
                  backgroundColor: context.tokens.accent,
                ),
                child: Text(l.common_save),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null && context.mounted) {
      try {
        await ref.read(eventsRepoProvider).updateTeam(team.id, {'slogan': result.trim()});
        ref.invalidate(teamDetailProvider(team.id));
        if (context.mounted) showToast(context, l.team_detail_edit_slogan, success: true);
      } catch (e) {
        if (context.mounted) showToast(context, '$e', error: true);
      }
    }
  }
}

class _RosterWarning extends StatelessWidget {
  final int current;
  final int total;
  const _RosterWarning({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.tokens.warnSubtle,
          border: Border.all(color: context.tokens.warn.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(context.tokens.r2),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: context.tokens.warn),
            const SizedBox(width: 8),
            Text(l.team_detail_roster_warning(current, total), style: TextStyle(fontSize: 12, color: context.tokens.warn)),
          ],
        ),
      ),
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

class _MembersSection extends ConsumerWidget {
  final AsyncValue<List<TeamMember>> membersAsync;
  final bool isCaptain;
  final String teamId;
  final String eventId;
  final int teamSize;

  const _MembersSection({
    required this.membersAsync,
    required this.isCaptain,
    required this.teamId,
    required this.eventId,
    required this.teamSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Label(l.team_detail_members)),
              if (isCaptain)
                TextButton.icon(
                  onPressed: () => _showAddMemberSheet(context, ref),
                  icon: Icon(Icons.add, size: 16, color: context.tokens.accent),
                  label: Text(
                    l.team_detail_add_member,
                    style: TextStyle(fontSize: 13, color: context.tokens.accent),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
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
                  for (final m in members)
                    _MemberRow(
                      member: m,
                      isCaptain: isCaptain,
                      onRemove: () => _removeMember(context, ref, m),
                    ),
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

  void _showAddMemberSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.elev2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.r3)),
      ),
      builder: (_) => _AddMemberSheet(teamId: teamId, eventId: eventId),
    );
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, TeamMember member) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.team_detail_remove_member),
        content: Text(l.team_detail_remove_member_confirm),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text(l.common_cancel),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: Text(l.common_confirm, style: TextStyle(color: context.tokens.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(eventsRepoProvider).removeTeamMember(member.id);
        ref.invalidate(teamMembersProvider(teamId));
        if (context.mounted) showToast(context, l.team_detail_remove_member, success: true);
      } catch (e) {
        if (context.mounted) showToast(context, '$e', error: true);
      }
    }
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  final String teamId;
  final String eventId;
  const _AddMemberSheet({required this.teamId, required this.eventId});

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _searchC = TextEditingController();
  final _jerseyC = TextEditingController();
  String _query = '';
  String? _selectedUserId;
  String? _selectedName;
  String? _selectedAvatar;
  String? _position;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchC.removeListener(_onSearchChanged);
    _searchC.dispose();
    _jerseyC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.tokens;
    final results = _query.length >= 2
        ? ref.watch(profileSearchProvider(_query))
        : const AsyncValue<List<Map<String, dynamic>>>.data([]);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.inkMute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              l.team_detail_add_member,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 20),

            // Search field / selected user
            Label(l.event_register_search_user),
            const SizedBox(height: 8),
            if (_selectedUserId != null)
              _buildSelectedUser(t)
            else
              _buildSearchField(t, l),

            // Search results dropdown
            if (_selectedUserId == null && _query.length >= 2)
              _buildSearchResults(results, t),

            const SizedBox(height: 16),

            // Jersey number
            Label(l.event_register_jersey),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: t.elev1,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(t.r2),
              ),
              child: TextField(
                controller: _jerseyC,
                keyboardType: TextInputType.number,
                style: TextStyle(color: t.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '1–99',
                  hintStyle: TextStyle(color: t.inkMute, fontSize: 14),
                  prefixIcon: Icon(Icons.tag, size: 18, color: t.inkDim),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Position selector
            Label(l.event_register_position),
            const SizedBox(height: 8),
            Row(
              children: [
                _positionChip(l.position_forward, 'forward', t),
                const SizedBox(width: 8),
                _positionChip(l.position_midfielder, 'midfielder', t),
                const SizedBox(width: 8),
                _positionChip(l.position_defender, 'defender', t),
                const SizedBox(width: 8),
                _positionChip(l.position_goalkeeper, 'goalkeeper', t),
              ],
            ),

            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: t.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.r2),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.common_confirm,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(AppTokens t, dynamic l) {
    return Container(
      decoration: BoxDecoration(
        color: t.elev1,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: TextField(
        controller: _searchC,
        style: TextStyle(color: t.ink, fontSize: 14),
        decoration: InputDecoration(
          hintText: l.event_register_search_user_hint,
          hintStyle: TextStyle(color: t.inkMute, fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 20, color: t.inkDim),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSelectedUser(AppTokens t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.accentSubtle,
        border: Border.all(color: t.accent.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(t.r2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: t.elev3,
            backgroundImage: _selectedAvatar != null
                ? NetworkImage(_selectedAvatar!)
                : null,
            child: _selectedAvatar == null
                ? Icon(Icons.person, size: 14, color: t.inkDim)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedName ?? '',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.ink,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedUserId = null;
              _selectedName = null;
              _selectedAvatar = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.ink.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: t.inkSub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    AsyncValue<List<Map<String, dynamic>>> results,
    AppTokens t,
  ) {
    return results.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: t.elev1,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(t.r2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < list.take(5).length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: t.line),
                _buildResultRow(list[i], t),
              ],
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: t.accent,
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildResultRow(Map<String, dynamic> p, AppTokens t) {
    final name = (p['name'] as String?) ?? '—';
    final avatar = p['avatar_url'] as String?;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedUserId = p['id'] as String;
          _selectedName = name;
          _selectedAvatar = avatar;
          _searchC.clear();
          _query = '';
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: t.elev3,
              backgroundImage:
                  avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Icon(Icons.person, size: 14, color: t.inkDim)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontSize: 14, color: t.ink),
              ),
            ),
            Icon(Icons.add_circle_outline, size: 18, color: t.accent),
          ],
        ),
      ),
    );
  }

  Widget _positionChip(String label, String value, AppTokens t) {
    final selected = _position == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _position = selected ? null : value),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.accentSubtle : t.elev1,
            border: Border.all(
              color: selected ? t.accent : t.line,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(t.r2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? t.accent : t.inkSub,
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged() {
    final text = _searchC.text.trim();
    if (text != _query) {
      setState(() => _query = text);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_selectedUserId == null) {
      showToast(context, l.error_required_select(l.event_register_search_user), error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final jersey = int.tryParse(_jerseyC.text.trim());
      await ref.read(eventsRepoProvider).addTeamMember(
            widget.teamId,
            _selectedUserId!,
            jersey,
            position: _position,
          );
      ref.invalidate(teamMembersProvider(widget.teamId));
      if (mounted) {
        context.pop();
        showToast(context, l.team_detail_add_member, success: true);
      }
    } catch (e) {
      if (mounted) showToast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMember member;
  final bool isCaptain;
  final VoidCallback onRemove;
  const _MemberRow({
    required this.member,
    required this.isCaptain,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String? positionLabel;
    if (member.position != null) {
      switch (member.position) {
        case 'forward':
          positionLabel = l.position_forward;
        case 'midfielder':
          positionLabel = l.position_midfielder;
        case 'defender':
          positionLabel = l.position_defender;
        case 'goalkeeper':
          positionLabel = l.position_goalkeeper;
      }
    }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name ?? '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.tokens.ink,
                  ),
                ),
                if (positionLabel != null)
                  Text(
                    positionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.tokens.inkDim,
                    ),
                  ),
              ],
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
          if (isCaptain && member.role != 'captain')
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close, size: 16, color: context.tokens.danger),
              ),
            ),
        ],
      ),
    );
  }
}

