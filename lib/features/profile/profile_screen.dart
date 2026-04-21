// profile_screen.dart — 我的 (tab root, menu-style)
// Matches new prototype: identity strip → archive entry card → activity → settings
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock.dart' show MockUser;
import '../../l10n/l10n_extension.dart';
import '../../providers.dart';
import '../../services/local_storage.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // Real profile from Supabase (name, handle, city, position), mock
    // fallback for stats/attrs/honors which require real match history.
    final MockUser u =
        ref.watch(myProfileProvider).valueOrNull ?? ref.watch(userProvider);
    final teammates = ref.watch(teammatesProvider);
    ref.watch(localStoreProvider);

    final activity = <_MenuItem>[
      _MenuItem(
        icon: Icons.calendar_today,
        label: l.profile_menu_my_events,
        badge: '2',
        onTap: () => context.push('/me/events'),
      ),
      _MenuItem(
        icon: Icons.map_outlined,
        label: l.profile_menu_my_pickups,
        badge: '1',
        onTap: () => context.push('/me/pickups'),
      ),
      _MenuItem(
        icon: Icons.person_outline,
        label: l.profile_menu_my_teams,
        badge: '${teammates.length}',
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
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  Text(
                    l.profile_title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.tokens.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/settings/account'),
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.settings_outlined,
                        color: context.tokens.ink,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Identity strip (avatar + name + @handle + 编辑)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Row(
                children: [
                  Avatar(u.name, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.tokens.ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u.handle,
                          style: TextStyle(
                            fontFamily: T.fontMono,
                            fontFamilyFallback: T.monoFallbacks,
                            fontSize: 12,
                            color: context.tokens.inkSub,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    label: l.profile_edit_btn,
                    variant: BtnVariant.ghost,
                    size: BtnSize.sm,
                    onPressed: () => context.push('/profile/edit'),
                  ),
                ],
              ),
            ),
            // Archive entry card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: GestureDetector(
                onTap: () => context.push('/archive'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        HSLColor.fromAHSL(1, 150, 0.25, 0.20).toColor(),
                        HSLColor.fromAHSL(1, 150, 0.10, 0.14).toColor(),
                      ],
                    ),
                    border: Border.all(color: const Color(0x6600FF85)),
                    borderRadius: BorderRadius.circular(T.r3),
                  ),
                  child: Row(
                    children: [
                      // Position big tag
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: T.liveDim,
                          border: Border.all(color: const Color(0x6600FF85)),
                          borderRadius: BorderRadius.circular(T.r2),
                        ),
                        child: Text(
                          u.position,
                          style: const TextStyle(
                            fontFamily: T.fontMono,
                            fontFamilyFallback: T.monoFallbacks,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: T.live,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  l.profile_archive_title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.tokens.ink,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: T.liveDim,
                                    border: Border.all(
                                      color: const Color(0x6600FF85),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    l.profile_archive_new_badge,
                                    style: const TextStyle(
                                      fontFamily: T.fontMono,
                                      fontFamilyFallback: T.monoFallbacks,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: T.live,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${u.positionFull} · ${u.city} ${u.district}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.tokens.inkSub,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 2,
                              children: [
                                _MiniStat(
                                  label: l.profile_mini_overall,
                                  value: '${u.rating}',
                                  color: T.live,
                                ),
                                _MiniStat(
                                  label: l.profile_mini_matches,
                                  value: '${u.stats.matches}',
                                  color: context.tokens.ink,
                                ),
                                _MiniStat(
                                  label: l.profile_mini_goals,
                                  value: '${u.stats.goals}',
                                  color: context.tokens.ink,
                                ),
                                _MiniStat(
                                  label: l.profile_mini_mvp,
                                  value: '${u.stats.mvp}',
                                  color: T.warn,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: context.tokens.inkDim,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                                style: const TextStyle(color: T.danger),
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
                    borderRadius: BorderRadius.circular(T.r2),
                  ),
                  child: Text(
                    l.profile_logout,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: T.danger,
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

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 11, color: context.tokens.inkSub)),
        N(value, size: 11, weight: FontWeight.w700, color: color),
      ],
    );
  }
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
              borderRadius: BorderRadius.circular(T.r2),
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
                    fontFamily: T.fontMono,
                    fontFamilyFallback: T.monoFallbacks,
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
