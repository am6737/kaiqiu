# 赛事详情页重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure EventDetailScreen to separate organizer management into a dedicated tab, flatten nested competition sub-tabs into top-level tabs, merge the overview panel into a collapsible header section, and simplify BottomCta to only serve regular users.

**Architecture:** The EventDetailScreen keeps its existing Stack-based layout (ScrollView + fixed bottom CTA). The `_Tabs` widget switches from fixed `Row` to scrollable `SingleChildScrollView` + `Row` to support 5-6 tabs. A new `ManagePanel` consolidates all organizer operations. The `_EventInfoSection` replaces `OverviewPanel` as a collapsible section above the KPI strip. No changes to data layer (models, repositories, providers).

**Tech Stack:** Flutter, Riverpod, go_router, Supabase (existing — no changes)

---

### Task 1: Add l10n strings for new "Manage" tab and "Event Info" section

**Files:**
- Modify: `lib/l10n/app_zh.arb:182-189`
- Modify: `lib/l10n/app_en.arb:182-189`

- [ ] **Step 1: Add new l10n strings to app_zh.arb**

Add after the existing `event_tab_teams` line (line 189):

```json
  "event_tab_manage": "管理",
  "event_info_section": "赛事信息",
  "manage_status_title": "赛事状态",
  "manage_review_title": "报名审核",
  "manage_review_stats": "待审 {pending} · 已通过 {approved} · 已拒绝 {rejected}",
  "@manage_review_stats": { "placeholders": { "pending": { "type": "int" }, "approved": { "type": "int" }, "rejected": { "type": "int" } } },
  "manage_settings_title": "赛事设置",
  "manage_register_on_behalf": "代队报名",
  "manage_status_completed_label": "赛事已结束",
  "manage_status_cancelled_label": "赛事已取消",
```

- [ ] **Step 2: Add matching English strings to app_en.arb**

Add after the existing `event_tab_teams` line (line 189):

```json
  "event_tab_manage": "Manage",
  "event_info_section": "Event Info",
  "manage_status_title": "Event Status",
  "manage_review_title": "Registration Review",
  "manage_review_stats": "Pending {pending} · Approved {approved} · Rejected {rejected}",
  "@manage_review_stats": { "placeholders": { "pending": { "type": "int" }, "approved": { "type": "int" }, "rejected": { "type": "int" } } },
  "manage_settings_title": "Event Settings",
  "manage_register_on_behalf": "Register on Behalf",
  "manage_status_completed_label": "Event completed",
  "manage_status_cancelled_label": "Event cancelled",
```

- [ ] **Step 3: Regenerate l10n**

Run: `cd /home/coder/workspaces/qiuju_app && flutter gen-l10n`
Expected: Generated files updated in `lib/l10n/generated/`

- [ ] **Step 4: Verify generation succeeded**

Run: `grep -c "event_tab_manage" lib/l10n/generated/app_localizations.dart`
Expected: `1` (or more — confirms the new key exists)

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add strings for manage tab and event info section"
```

---

### Task 2: Simplify EventHeader — remove _MoreMenu

**Files:**
- Modify: `lib/features/events/widgets/event_header.dart`

- [ ] **Step 1: Remove _MoreMenu and related props from EventHeader**

Replace the entire file content with this simplified version that removes `_MoreMenu`, `_SheetItem`, and the `isCreator`/`onEdit`/`onCancel`/`onRegister` props:

```dart
import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../utils/share_helper.dart';
import '../../../widgets/network_cover.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';

class EventHeader extends StatelessWidget {
  final Event event;
  final VoidCallback onBack;
  const EventHeader({
    super.key,
    required this.event,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hue = (event.id.codeUnitAt(0) * 7 + event.id.codeUnitAt(1)) % 360.0;
    final l = context.l10n;
    final (dotColor, pillColor, pillText) = switch (event.status) {
      EventStatus.ongoing => (context.tokens.accent, context.tokens.accent, l.event_status_ongoing),
      EventStatus.registering => (context.tokens.warn, context.tokens.warn, l.event_status_registering),
      EventStatus.completed => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
      EventStatus.scheduling => (context.tokens.warn, context.tokens.warn, l.event_status_scheduling),
      EventStatus.cancelled => (context.tokens.danger, context.tokens.danger, l.event_status_cancelled),
      _ => (context.tokens.inkDim, context.tokens.inkSub, l.event_status_done),
    };
    return Stack(
      children: [
        NetworkCover(
          url: event.coverUrl,
          fallbackLabel: context.l10n.event_overview_main_visual(event.name),
          height: 240,
          hue: hue,
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Color(0x80000000),
                  Color(0x40000000),
                  Color(0x66000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => shareEvent(event),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xB3FFFFFF),
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.ios_share,
                  size: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Label(pillText, color: pillColor),
                  if (event.sub != null && event.sub!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Label('· ${event.sub!}', color: const Color(0xCCFFFFFF)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                  letterSpacing: -0.6,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/events/widgets/event_header.dart 2>&1 | tail -5`
Expected: Will show errors in `event_detail_screen.dart` due to removed props — that's expected, we fix it in Task 5.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/widgets/event_header.dart
git commit -m "refactor(event-header): remove _MoreMenu, simplify to back+share only"
```

---

### Task 3: Simplify BottomCta — remove all organizer logic

**Files:**
- Modify: `lib/features/events/widgets/bottom_cta.dart`

- [ ] **Step 1: Rewrite BottomCta to only serve regular users**

Replace the `BottomCta` class (lines 17-543) but keep `RegField` (lines 545-587). The new `BottomCta` removes all organizer logic, uses single-button layout, and hides when no action is applicable. The registration sheets (`showRegisterSheet`, `showIndividualRegisterSheet`, `_showRegistrationModeChoice`, `_showCancelConfirmation`) stay as-is since they're reused by ManagePanel:

```dart
class BottomCta extends ConsumerWidget {
  final Event event;
  const BottomCta({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(localStoreProvider);
    final registered = LocalStore.isEventFavorited(event.id);
    final isCreator = event.creatorId != null && event.creatorId == currentUserId;
    final isRegistering = event.status == EventStatus.registering;
    final isOngoing = event.status == EventStatus.ongoing;

    if (isCreator) return const SizedBox.shrink();

    if (registered && isRegistering) {
      return _bar(
        context,
        child: PrimaryButton(
          label: l.event_register_cancel,
          variant: BtnVariant.ghost,
          size: BtnSize.lg,
          full: true,
          onPressed: () => _showCancelConfirmation(context, ref),
        ),
      );
    }

    if (isRegistering && !registered) {
      final teamsCount = ref.watch(eventTeamsCountProvider(event.id)).valueOrNull ?? 0;
      final isFull = event.teamsMax != null && teamsCount >= event.teamsMax!;
      final deadlinePassed = event.deadline != null && DateTime.now().isAfter(event.deadline!);

      String? disabledReason;
      if (isFull) disabledReason = l.event_registration_full;
      if (deadlinePassed) disabledReason = l.event_registration_deadline_passed;

      return _bar(
        context,
        child: PrimaryButton(
          label: disabledReason ?? l.event_cta_register,
          variant: disabledReason != null ? BtnVariant.secondary : BtnVariant.primary,
          size: BtnSize.lg,
          full: true,
          onPressed: disabledReason != null
              ? null
              : () {
                  if (event.registrationMode == 'team_and_individual') {
                    _showRegistrationModeChoice(context, ref);
                  } else {
                    showRegisterSheet(context, ref);
                  }
                },
        ),
      );
    }

    if (isOngoing) {
      final hasLive = ref.watch(liveMatchesForEventProvider(event.id)).valueOrNull?.isNotEmpty ?? false;
      if (hasLive) {
        return _bar(
          context,
          child: PrimaryButton(
            label: l.event_cta_watch_live,
            size: BtnSize.lg,
            full: true,
            onPressed: () => context.push('/worldcup/live/${event.id}'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tv, size: 16, color: context.tokens.accentInk),
                const SizedBox(width: 6),
                Text(
                  l.event_cta_watch_live,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.accentInk,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _bar(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: child,
    );
  }

  Future<void> showRegisterSheet(BuildContext context, WidgetRef ref) async {
    // --- KEEP EXISTING showRegisterSheet BODY UNCHANGED (lines 197-358) ---
  }

  Future<void> showIndividualRegisterSheet(BuildContext context, WidgetRef ref) async {
    // --- KEEP EXISTING showIndividualRegisterSheet BODY UNCHANGED (lines 361-467) ---
  }

  void _showRegistrationModeChoice(BuildContext context, WidgetRef ref) {
    // --- KEEP EXISTING _showRegistrationModeChoice BODY UNCHANGED (lines 469-503) ---
  }

  Future<void> _showCancelConfirmation(BuildContext context, WidgetRef ref) async {
    // --- KEEP EXISTING _showCancelConfirmation BODY UNCHANGED (lines 505-542) ---
  }
}
```

**Important:** The `showRegisterSheet`, `showIndividualRegisterSheet`, `_showRegistrationModeChoice`, and `_showCancelConfirmation` method bodies must be copied verbatim from the existing file. Only the `build` method and `_buildRightButton` change.

- [ ] **Step 2: Verify the file compiles (ignoring downstream consumers)**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/events/widgets/bottom_cta.dart 2>&1 | tail -5`
Expected: No errors in this file itself. Possible warnings about unused imports (remove `import 'package:go_router/go_router.dart'` if the liveMatch watch path does not need it — but it does for `context.push`).

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/widgets/bottom_cta.dart
git commit -m "refactor(bottom-cta): remove organizer logic, single-button layout, hide when no action"
```

---

### Task 4: Simplify TeamsPanel — remove inline review controls

**Files:**
- Modify: `lib/features/events/panels/teams_panel.dart`

- [ ] **Step 1: Remove organizer-only props and review UI from TeamsPanel**

The simplified `TeamsPanel` no longer accepts `isCreator`, `reviewMode`, or `registrationMode`. It becomes a pure read-only list. Remove `_updateStatus`, `_confirmReject` methods, the approve/reject buttons from `_TeamTile`, the `_IndividualRegistrationsSection` and `_IndividualTile` widgets, and the creator-only contact info display.

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../theme/app_tokens.dart';
import '../../../widgets/typography.dart';

class TeamsPanel extends ConsumerWidget {
  final String eventId;
  final int? teamsMax;

  const TeamsPanel({
    super.key,
    required this.eventId,
    this.teamsMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventTeamsProvider(eventId));
    return async.when(
      data: (teams) => _buildList(context, teams),
      loading: () =>
          Center(child: CircularProgressIndicator(color: context.tokens.accent)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: TextStyle(color: context.tokens.danger, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<TeamRow> teams) {
    final l = context.l10n;
    final approved = teams.where((t) => t.status != 'rejected').length;
    final max = teamsMax ?? 0;

    if (teams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.groups_outlined, size: 40, color: context.tokens.inkDim),
              const SizedBox(height: 8),
              Text(
                l.event_teams_empty,
                style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<TeamRow>.from(teams)
      ..sort((a, b) {
        const order = {'pending': 0, 'approved': 1, 'rejected': 2};
        final cmp = (order[a.status] ?? 1).compareTo(order[b.status] ?? 1);
        if (cmp != 0) return cmp;
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return aTime.compareTo(bTime);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.event_teams_summary(approved, max)),
          const SizedBox(height: 12),
          for (final team in sorted)
            _TeamTile(team: team, eventId: eventId),
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  final TeamRow team;
  final String eventId;

  const _TeamTile({
    required this.team,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    final isRejected = team.status == 'rejected';
    return GestureDetector(
      onTap: () => context.push('/event/$eventId/team/${team.id}'),
      child: Opacity(
        opacity: isRejected ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
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
                backgroundImage: team.captainAvatar != null
                    ? NetworkImage(team.captainAvatar!)
                    : null,
                child: team.captainAvatar == null
                    ? Text(
                        team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.tokens.inkSub,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.ink,
                      ),
                    ),
                    if (team.captainName != null)
                      Text(
                        team.captainName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.tokens.inkSub,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusBadge(status: team.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, bg, fg) = switch (status) {
      'approved' => (l.event_teams_approved, context.tokens.accentSubtle, context.tokens.accent),
      'rejected' => (l.event_teams_rejected, context.tokens.elev3, context.tokens.inkDim),
      _ => (l.event_teams_pending, context.tokens.warnSubtle, context.tokens.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.tokens.r1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no compile errors in this file**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/events/panels/teams_panel.dart 2>&1 | tail -5`
Expected: Clean, no errors in teams_panel.dart itself.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/panels/teams_panel.dart
git commit -m "refactor(teams-panel): remove inline review controls, read-only list"
```

---

### Task 5: Create ManagePanel

**Files:**
- Create: `lib/features/events/panels/manage_panel.dart`

- [ ] **Step 1: Create ManagePanel with three sections**

Create the file with status card, registration review, and event settings sections. This panel consolidates all organizer operations previously scattered across `_MoreMenu`, `BottomCta`, and `TeamsPanel`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../models/event.dart';
import '../../../providers.dart';
import '../../../services/supabase.dart';
import '../../../utils/toast.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/typography.dart';
import '../../../theme/app_tokens.dart';
import '../widgets/bottom_cta.dart';

class ManagePanel extends ConsumerWidget {
  final Event event;
  const ManagePanel({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(event: event),
          const SizedBox(height: 20),
          _ReviewSection(event: event),
          const SizedBox(height: 20),
          _SettingsSection(event: event),
        ],
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  final Event event;
  const _StatusCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.manage_status_title),
          const SizedBox(height: 12),
          _buildStatusAction(context, ref, l),
        ],
      ),
    );
  }

  Widget _buildStatusAction(BuildContext context, WidgetRef ref, dynamic l) {
    return switch (event.status) {
      EventStatus.registering => PrimaryButton(
          label: l.event_close_registration,
          size: BtnSize.lg,
          full: true,
          onPressed: () => _confirmAction(
            context,
            ref,
            title: l.event_close_registration,
            body: l.event_close_registration_confirm,
            action: () async {
              await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.scheduling);
              ref.invalidate(eventDetailProvider(event.id));
            },
          ),
        ),
      EventStatus.scheduling => PrimaryButton(
          label: l.schedule_generate,
          size: BtnSize.lg,
          full: true,
          onPressed: () => context.push('/event/${event.id}/schedule'),
        ),
      EventStatus.ongoing => PrimaryButton(
          label: l.event_complete,
          size: BtnSize.lg,
          full: true,
          variant: BtnVariant.warn,
          onPressed: () => _confirmAction(
            context,
            ref,
            title: l.event_complete,
            body: l.event_complete_confirm,
            action: () async {
              await ref.read(eventsRepoProvider).updateEventStatus(event.id, EventStatus.completed);
              ref.invalidate(eventDetailProvider(event.id));
              if (context.mounted) showToast(context, l.event_complete_success, success: true);
            },
          ),
        ),
      EventStatus.completed => Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: context.tokens.accent),
            const SizedBox(width: 8),
            Text(l.manage_status_completed_label, style: TextStyle(fontSize: 14, color: context.tokens.inkSub)),
          ],
        ),
      EventStatus.cancelled => Row(
          children: [
            Icon(Icons.cancel, size: 18, color: context.tokens.danger),
            const SizedBox(width: 8),
            Text(l.manage_status_cancelled_label, style: TextStyle(fontSize: 14, color: context.tokens.inkSub)),
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _confirmAction(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await action();
  }
}

class _ReviewSection extends ConsumerWidget {
  final Event event;
  const _ReviewSection({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final teamsAsync = ref.watch(eventTeamsProvider(event.id));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.manage_review_title),
          const SizedBox(height: 8),
          teamsAsync.when(
            data: (teams) => _buildTeamReview(context, ref, teams),
            loading: () => Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: context.tokens.accent, strokeWidth: 2)),
            ),
            error: (e, _) => Text('$e', style: TextStyle(fontSize: 12, color: context.tokens.danger)),
          ),
          if (event.registrationMode == 'team_and_individual') ...[
            const SizedBox(height: 16),
            _IndividualReviewList(eventId: event.id),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamReview(BuildContext context, WidgetRef ref, List<TeamRow> teams) {
    final l = context.l10n;
    final pending = teams.where((t) => t.status == 'pending').toList();
    final approved = teams.where((t) => t.status == 'approved').length;
    final rejected = teams.where((t) => t.status == 'rejected').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.manage_review_stats(pending.length, approved, rejected),
          style: TextStyle(fontSize: 12, color: context.tokens.inkSub),
        ),
        if (pending.isEmpty) ...[
          const SizedBox(height: 8),
          Text(l.event_teams_empty, style: TextStyle(fontSize: 12, color: context.tokens.inkDim)),
        ],
        for (final team in pending) ...[
          const SizedBox(height: 10),
          _PendingTeamTile(
            team: team,
            eventId: event.id,
          ),
        ],
      ],
    );
  }
}

class _PendingTeamTile extends ConsumerWidget {
  final TeamRow team;
  final String eventId;
  const _PendingTeamTile({required this.team, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: context.tokens.elev3,
                backgroundImage: team.captainAvatar != null ? NetworkImage(team.captainAvatar!) : null,
                child: team.captainAvatar == null
                    ? Text(team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.tokens.inkSub))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tokens.ink)),
                    if (team.captainName != null)
                      Text(team.captainName!, style: TextStyle(fontSize: 12, color: context.tokens.inkSub)),
                  ],
                ),
              ),
            ],
          ),
          if (team.contact != null || team.phone != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 42),
                if (team.contact != null) ...[
                  Icon(Icons.person_outline, size: 13, color: context.tokens.inkDim),
                  const SizedBox(width: 4),
                  Text(team.contact!, style: TextStyle(fontSize: 11, color: context.tokens.inkDim)),
                  const SizedBox(width: 12),
                ],
                if (team.phone != null) ...[
                  Icon(Icons.phone_outlined, size: 13, color: context.tokens.inkDim),
                  const SizedBox(width: 4),
                  Text(team.phone!, style: TextStyle(fontSize: 11, color: context.tokens.inkDim)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _confirmReject(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.tokens.danger),
                    borderRadius: BorderRadius.circular(context.tokens.r1),
                  ),
                  child: Text(l.event_teams_reject, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tokens.danger)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _approve(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.tokens.accent,
                    borderRadius: BorderRadius.circular(context.tokens.r1),
                  ),
                  child: Text(l.event_teams_approve, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.tokens.accentInk)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(eventsRepoProvider).updateTeamStatus(team.id, 'approved');
      ref.invalidate(eventTeamsProvider(eventId));
      ref.invalidate(eventTeamsCountProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }

  Future<void> _confirmReject(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_teams_reject),
        content: Text(l.event_teams_reject_confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(eventsRepoProvider).updateTeamStatus(team.id, 'rejected');
      ref.invalidate(eventTeamsProvider(eventId));
      ref.invalidate(eventTeamsCountProvider(eventId));
    } catch (e) {
      if (context.mounted) showToast(context, '$e', error: true);
    }
  }
}

class _IndividualReviewList extends ConsumerWidget {
  final String eventId;
  const _IndividualReviewList({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(individualRegistrationsProvider(eventId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(l.individual_registrations_title),
        const SizedBox(height: 8),
        async.when(
          data: (regs) {
            final pending = regs.where((r) => r.status == 'pending').toList();
            if (pending.isEmpty) {
              return Text(l.individual_registrations_empty, style: TextStyle(fontSize: 12, color: context.tokens.inkDim));
            }
            return Column(
              children: [
                for (final reg in pending) ...[
                  const SizedBox(height: 8),
                  _IndividualTile(reg: reg, eventId: eventId),
                ],
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _IndividualTile extends ConsumerWidget {
  final IndividualRegistration reg;
  final String eventId;
  const _IndividualTile({required this.reg, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.elev1,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reg.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.tokens.ink)),
                if (reg.position != null)
                  Text(_posLabel(context, reg.position!), style: TextStyle(fontSize: 11, color: context.tokens.inkSub)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _assignToTeam(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: context.tokens.accent,
                borderRadius: BorderRadius.circular(context.tokens.r1),
              ),
              child: Text(l.individual_assign_to_team, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.accentInk)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              await ref.read(eventsRepoProvider).rejectIndividualRegistration(reg.id);
              ref.invalidate(individualRegistrationsProvider(eventId));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: context.tokens.danger),
                borderRadius: BorderRadius.circular(context.tokens.r1),
              ),
              child: Text(l.individual_reject, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.tokens.danger)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignToTeam(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final teams = await ref.read(eventsRepoProvider).listTeams(eventId);
    final approvedTeams = teams.where((t) => t.status == 'approved').toList();
    if (!context.mounted) return;

    final selectedTeam = await showModalBottomSheet<TeamRow>(
      context: context,
      backgroundColor: context.tokens.elev1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.individual_assign_to_team, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.tokens.ink)),
            const SizedBox(height: 12),
            for (final team in approvedTeams)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, team),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Text(team.name, style: TextStyle(fontSize: 14, color: context.tokens.ink)),
                ),
              ),
          ],
        ),
      ),
    );
    if (selectedTeam == null) return;
    await ref.read(eventsRepoProvider).assignIndividualToTeam(reg.id, selectedTeam.id, reg.userId);
    ref.invalidate(individualRegistrationsProvider(eventId));
    ref.invalidate(teamMembersProvider(selectedTeam.id));
  }

  String _posLabel(BuildContext context, String pos) {
    final l = context.l10n;
    return switch (pos) {
      'forward' => l.position_forward,
      'midfielder' => l.position_midfielder,
      'defender' => l.position_defender,
      'goalkeeper' => l.position_goalkeeper,
      _ => pos,
    };
  }
}

class _SettingsSection extends ConsumerWidget {
  final Event event;
  const _SettingsSection({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canCancel = event.status == EventStatus.draft ||
        event.status == EventStatus.registering ||
        event.status == EventStatus.scheduling;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(context.tokens.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(l.manage_settings_title),
          const SizedBox(height: 12),
          _SettingRow(
            icon: Icons.edit_outlined,
            label: l.event_edit,
            onTap: () => context.push('/event/${event.id}/edit'),
          ),
          _SettingRow(
            icon: Icons.group_add_outlined,
            label: l.manage_register_on_behalf,
            onTap: () {
              final cta = BottomCta(event: event);
              cta.showRegisterSheet(context, ref);
            },
          ),
          _SettingRow(
            icon: Icons.cancel_outlined,
            label: l.event_cancel,
            color: canCancel ? context.tokens.danger : context.tokens.inkMute,
            onTap: canCancel ? () => _confirmCancel(context, ref) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.event_cancel),
        content: Text(l.event_cancel_confirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.common_cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.common_confirm)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(eventsRepoProvider).cancelEvent(event.id);
    ref.invalidate(eventDetailProvider(event.id));
    ref.invalidate(myHostedEventsProvider);
    if (context.mounted) {
      showToast(context, l.event_cancel_success, success: true);
      context.go('/events');
    }
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const _SettingRow({required this.icon, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.tokens.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c)),
            ),
            if (onTap != null) Icon(Icons.chevron_right, size: 18, color: context.tokens.inkMute),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no compile errors**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze lib/features/events/panels/manage_panel.dart 2>&1 | tail -5`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/panels/manage_panel.dart
git commit -m "feat(manage-panel): create ManagePanel with status, review, and settings sections"
```

---

### Task 6: Rewrite EventDetailScreen — new tabs, collapsible info section, wire everything

**Files:**
- Modify: `lib/features/events/event_detail_screen.dart`

- [ ] **Step 1: Rewrite EventDetailScreen with new tab structure and _EventInfoSection**

Replace the entire file. Key changes:
1. Remove imports for `OverviewPanel` and `CompetitionPanel`
2. Add imports for `BracketPanel`, `StandingsPanel`, `ScorersPanel`, `ManagePanel`
3. Default tab is based on event status
4. `_Tabs` uses scrollable layout instead of `Expanded`
5. `_EventInfoSection` replaces OverviewPanel as collapsible section
6. EventHeader call simplified (no more isCreator/onEdit/onCancel/onRegister)
7. Remove `_confirmCancelEvent` and `_showCreatorRegisterSheet` methods
8. Bottom padding adjusts when CTA is hidden (creator)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/event.dart';
import '../../providers.dart';
import '../../services/map_launcher.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/network_avatar.dart';
import '../../widgets/typography.dart';

import 'panels/bracket_panel.dart';
import 'panels/chat_panel.dart';
import 'panels/manage_panel.dart';
import 'panels/scorers_panel.dart';
import 'panels/standings_panel.dart';
import 'panels/teams_panel.dart';
import 'widgets/bottom_cta.dart';
import 'widgets/event_header.dart';
import 'widgets/kpi_strip.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  String? _tab;

  String _defaultTab(Event event) {
    return switch (event.status) {
      EventStatus.draft || EventStatus.registering => 'teams',
      EventStatus.scheduling || EventStatus.ongoing => 'bracket',
      EventStatus.completed => 'standings',
      _ => 'teams',
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: async.when(
        data: (event) => _buildContent(event),
        loading: () =>
            Center(child: CircularProgressIndicator(color: context.tokens.accent)),
        error: (e, _) => _buildError(e),
      ),
    );
  }

  Widget _buildError(Object e) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: context.tokens.danger),
            const SizedBox(height: 8),
            Text(
              '${l.error_load_failed}: $e',
              style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => ref.invalidate(eventDetailProvider(widget.id)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l.common_retry,
                  style: TextStyle(color: context.tokens.ink, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Event event) {
    final l = context.l10n;
    final isCreator = event.creatorId != null && event.creatorId == currentUserId;
    final tab = _tab ?? _defaultTab(event);

    final tabs = <(String, String)>[
      ('teams', l.event_tab_teams),
      ('bracket', l.event_tab_bracket),
      ('standings', l.event_tab_standings),
      ('scorers', l.event_tab_scorers),
      ('chat', l.event_tab_chat),
      if (isCreator) ('manage', l.event_tab_manage),
    ];

    final showCta = !isCreator;
    final bottomPad = tab == 'chat' ? 166.0 : (showCta ? 110.0 : 24.0);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final panelMinHeight = (constraints.maxHeight - 349 - (showCta ? 110 : 0))
            .clamp(0.0, double.infinity);
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EventHeader(
                    event: event,
                    onBack: () => context.pop(),
                  ),
                  _EventInfoSection(event: event),
                  KpiStrip(
                    eventId: event.id,
                    prizeCents: event.prizeCents,
                    teamsMax: event.teamsMax,
                  ),
                  _Tabs(
                    current: tab,
                    tabs: tabs,
                    onChange: (v) => setState(() => _tab = v),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: panelMinHeight),
                    child: switch (tab) {
                      'teams' => TeamsPanel(
                          eventId: event.id,
                          teamsMax: event.teamsMax,
                        ),
                      'bracket' => BracketPanel(eventId: event.id),
                      'standings' => StandingsPanel(eventId: event.id),
                      'scorers' => ScorersPanel(eventId: event.id),
                      'chat' => ChatPanel(eventId: event.id),
                      'manage' => ManagePanel(event: event),
                      _ => TeamsPanel(eventId: event.id, teamsMax: event.teamsMax),
                    },
                  ),
                ],
              ),
            ),
            if (tab == 'chat')
              Positioned(
                bottom: 96,
                left: 0,
                right: 0,
                child: ChatInput(eventId: event.id),
              ),
            if (showCta)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BottomCta(event: event),
              ),
          ],
        );
      },
    );
  }
}

class _EventInfoSection extends ConsumerStatefulWidget {
  final Event event;
  const _EventInfoSection({required this.event});

  @override
  ConsumerState<_EventInfoSection> createState() => _EventInfoSectionState();
}

class _EventInfoSectionState extends ConsumerState<_EventInfoSection> {
  bool _expanded = false;

  bool get _canNavigate => widget.event.lat != null && widget.event.lng != null;

  String get _locationText {
    final parts = <String>[];
    if (widget.event.sub != null && widget.event.sub!.isNotEmpty) parts.add(widget.event.sub!);
    if (widget.event.address != null &&
        widget.event.address!.trim().isNotEmpty &&
        widget.event.address != widget.event.sub) {
      parts.add(widget.event.address!);
    }
    return parts.join(' · ');
  }

  void _openNav() {
    if (!_canNavigate) return;
    MapLauncher.openNavigation(
      context: context,
      lat: widget.event.lat!,
      lng: widget.event.lng!,
      name: widget.event.sub ?? (widget.event.address ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final event = widget.event;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.tokens.elev1,
          border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _expanded ? l.event_info_section : '${event.name}。',
                    maxLines: _expanded ? null : 1,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _expanded ? FontWeight.w600 : FontWeight.w400,
                      color: context.tokens.ink,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: context.tokens.inkDim,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              Text(
                '${event.name}。',
                style: TextStyle(fontSize: 14, color: context.tokens.ink, height: 1.6),
              ),
              const SizedBox(height: 16),
              Label(l.event_overview_rules),
              const SizedBox(height: 10),
              for (final r in [
                l.event_overview_rule_format,
                l.event_overview_rule_halves,
                l.event_overview_rule_subs,
                l.event_overview_rule_cards,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(color: context.tokens.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(r, style: TextStyle(fontSize: 13, color: context.tokens.inkSub)),
                    ],
                  ),
                ),
              if (event.sub != null && event.sub!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Label(l.event_overview_venue),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _canNavigate ? _openNav : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(color: context.tokens.line),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.near_me, size: 14, color: context.tokens.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
                          ),
                        ),
                        if (_canNavigate)
                          Text(
                            l.pickup_detail_navigate,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tokens.accent),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _buildOrganizer(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizer(BuildContext context) {
    final l = context.l10n;
    final event = widget.event;
    final creatorProfile = event.creatorId != null
        ? ref.watch(profileByIdProvider(event.creatorId!))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(l.event_overview_organizer),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: event.creatorId != null
              ? () => context.push('/user/${event.creatorId!}')
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                if (creatorProfile != null)
                  creatorProfile.when(
                    data: (p) => NetworkAvatar(
                      p?.name ?? '?',
                      url: p?.avatarUrl,
                      size: 36,
                      square: true,
                    ),
                    loading: () => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: context.tokens.elev3, borderRadius: BorderRadius.circular(6)),
                    ),
                    error: (_, _) => Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: context.tokens.elev3, borderRadius: BorderRadius.circular(6)),
                    ),
                  )
                else
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: context.tokens.elev3, borderRadius: BorderRadius.circular(6)),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creatorProfile?.valueOrNull?.name ?? '—',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.tokens.ink),
                      ),
                      Label(l.event_overview_organizer_label),
                    ],
                  ),
                ),
                if (event.creatorId != null)
                  Icon(Icons.chevron_right, size: 18, color: context.tokens.inkMute),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  final String current;
  final List<(String, String)> tabs;
  final ValueChanged<String> onChange;

  const _Tabs({
    required this.current,
    required this.tabs,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.line, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            for (final t in tabs)
              GestureDetector(
                onTap: () => onChange(t.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: current == t.$1 ? context.tokens.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: current == t.$1 ? FontWeight.w700 : FontWeight.w500,
                      color: current == t.$1 ? context.tokens.ink : context.tokens.inkSub,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify the full project compiles**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze 2>&1 | tail -10`
Expected: No errors. Warnings about unused imports in deleted files are OK if those files still exist.

- [ ] **Step 3: Commit**

```bash
git add lib/features/events/event_detail_screen.dart
git commit -m "feat(event-detail): new tab structure, collapsible info section, wire ManagePanel"
```

---

### Task 7: Delete obsolete files

**Files:**
- Delete: `lib/features/events/panels/overview_panel.dart`
- Delete: `lib/features/events/panels/competition_panel.dart`

- [ ] **Step 1: Delete overview_panel.dart and competition_panel.dart**

```bash
cd /home/coder/workspaces/qiuju_app
rm lib/features/events/panels/overview_panel.dart
rm lib/features/events/panels/competition_panel.dart
```

- [ ] **Step 2: Verify no remaining references**

Run: `cd /home/coder/workspaces/qiuju_app && grep -rn "overview_panel\|competition_panel" lib/ --include="*.dart"`
Expected: No matches (all imports have been removed in Task 6).

- [ ] **Step 3: Final project analysis**

Run: `cd /home/coder/workspaces/qiuju_app && flutter analyze 2>&1 | tail -10`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add -u lib/features/events/panels/overview_panel.dart lib/features/events/panels/competition_panel.dart
git commit -m "chore: delete OverviewPanel and CompetitionPanel (replaced by inline info section and flat tabs)"
```

---

### Task 8: Smoke test on device/emulator

- [ ] **Step 1: Run the app**

Run: `cd /home/coder/workspaces/qiuju_app && flutter run -d chrome --web-port=8080` (or appropriate device)

- [ ] **Step 2: Verify regular user flow**

Navigate to a registering event:
1. Confirm tabs show: 队伍 / 赛程 / 积分榜 / 射手榜 / 讨论 (no "管理")
2. Confirm collapsible "赛事信息" section works (tap to expand/collapse)
3. Confirm bottom CTA shows "立即报名"
4. Confirm no "more" menu button in top-right (only share)
5. Confirm default tab is "队伍" for registering events

- [ ] **Step 3: Verify organizer flow**

Navigate to an event you created:
1. Confirm tabs show the additional "管理" tab
2. Confirm "管理" tab has: status card + review section + settings section
3. Confirm status card shows appropriate action button for current status
4. Confirm no bottom CTA is shown
5. Confirm "编辑赛事" navigates to edit screen
6. Confirm default tab matches event status

- [ ] **Step 4: Verify tab defaults**

1. Registering event → default "队伍" tab
2. Ongoing event → default "赛程" tab
3. Completed event → default "积分榜" tab

- [ ] **Step 5: Commit all remaining changes (if any hotfixes were needed)**

```bash
git add -A
git commit -m "fix: smoke test adjustments for event detail redesign"
```
