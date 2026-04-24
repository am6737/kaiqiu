// profile_settings_screen.dart — 设置与管理 hub
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/typography.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    final regEventsCount = ref.watch(myRegisteredEventsProvider).valueOrNull?.length ?? 0;
    final hostedEventsCount = ref.watch(myHostedEventsProvider).valueOrNull?.length ?? 0;
    final eventsCount = regEventsCount + hostedEventsCount;

    final hostedPickupsCount = ref.watch(myHostedPickupsProvider).valueOrNull?.length ?? 0;
    final joinedPickupsCount = ref.watch(myJoinedPickupsProvider).valueOrNull?.length ?? 0;
    final pickupsCount = hostedPickupsCount + joinedPickupsCount;

    final venuesCount = ref.watch(myVenuesProvider).valueOrNull?.length ?? 0;
    final teammatesAsync = ref.watch(teammatesProvider);

    final activity = <_MenuItem>[
      _MenuItem(
        icon: Icons.calendar_today,
        label: l.profile_menu_my_events,
        badge: eventsCount > 0 ? '$eventsCount' : null,
        onTap: () => context.push('/me/events'),
      ),
      _MenuItem(
        icon: Icons.map_outlined,
        label: l.profile_menu_my_pickups,
        badge: pickupsCount > 0 ? '$pickupsCount' : null,
        onTap: () => context.push('/me/pickups'),
      ),
      _MenuItem(
        icon: Icons.stadium_outlined,
        label: '我的场馆',
        badge: venuesCount > 0 ? '$venuesCount' : null,
        onTap: () => context.push('/me/venues'),
      ),
      _MenuItem(
        icon: Icons.person_outline,
        label: l.profile_menu_my_teams,
        badge: (teammatesAsync.valueOrNull?.length ?? 0) > 0
            ? '${teammatesAsync.valueOrNull?.length ?? 0}'
            : null,
        onTap: () => context.push('/me/teams'),
      ),
      _MenuItem(
        icon: Icons.bookmark_border,
        label: l.profile_menu_favorites,
        onTap: () => context.push('/me/favorites'),
      ),
    ];

    final settings = <_MenuItem>[
      _MenuItem(
        icon: Icons.settings_outlined,
        label: l.profile_menu_account,
        onTap: () => context.push('/settings/account'),
      ),
      _MenuItem(
        icon: Icons.notifications_none,
        label: l.profile_menu_notif,
        onTap: () => context.push('/settings/notifications'),
      ),
      _MenuItem(
        icon: Icons.palette_outlined,
        label: l.profile_menu_appearance,
        onTap: () => context.push('/settings/appearance'),
      ),
      _MenuItem(
        icon: Icons.chat_bubble_outline,
        label: l.profile_menu_help,
        onTap: () => context.push('/settings/help'),
      ),
      _MenuItem(
        icon: Icons.emoji_events_outlined,
        label: l.profile_menu_about,
        trailing: 'v0.1',
        onTap: () => context.push('/settings/about'),
      ),
    ];

    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            PageTitleBar(title: l.profile_settings_title, onBack: () => context.pop()),
            _EntrySection(title: l.profile_section_activity, items: activity),
            _EntrySection(title: l.profile_section_settings, items: settings),
            // Sign-out
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: () async {
                  final ok =
                      await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.tokens.elev2,
                          content: Text(
                            l.profile_logout_confirm,
                            style: TextStyle(color: context.tokens.ink),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(
                                l.common_cancel,
                                style: TextStyle(color: context.tokens.inkSub),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text(
                                l.settings_account_logout,
                                style: TextStyle(color: context.tokens.danger),
                              ),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (!ok) return;
                  await supabase.auth.signOut();
                  await LocalStore.setRemember(false, null);
                  // Router redirect will push to /sign-in automatically.
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.tokens.elev2,
                    border: Border.all(color: context.tokens.line),
                    borderRadius: BorderRadius.circular(context.tokens.r2),
                  ),
                  child: Text(
                    l.profile_logout,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.danger,
                    ),
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

class _MenuItem {
  final IconData icon;
  final String label;
  final String? badge;
  final String? trailing;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.trailing,
    this.onTap,
  });
}

class _EntrySection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _EntrySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(title),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) _row(context, items[i], i > 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _MenuItem item, bool divider) {
    return InkWell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: divider
            ? BoxDecoration(
                border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tokens.elev3,
                border: Border.all(color: context.tokens.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(item.icon, size: 14, color: context.tokens.inkSub),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  color: context.tokens.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: context.tokens.elev3,
                  border: Border.all(color: context.tokens.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.badge!,
                  style: TextStyle(
                    fontFamily: context.tokens.fontMono,
                    fontFamilyFallback: context.tokens.monoFallbacks,
                    fontSize: 10,
                    color: context.tokens.inkSub,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (item.trailing != null) ...[
              Label(item.trailing!),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 14, color: context.tokens.inkDim),
          ],
        ),
      ),
    );
  }
}
