// bottom_nav_shell.dart — 5-tab bottom nav, wraps StatefulShellRoute children
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../theme/app_tokens.dart';

class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const BottomNavShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = <(String, IconData, IconData)>[
      (l.tab_home, Icons.home_outlined, Icons.home),
      (l.tab_pickup, Icons.map_outlined, Icons.map),
      (l.tab_events, Icons.emoji_events_outlined, Icons.emoji_events),
      (l.tab_me, Icons.person_outline, Icons.person),
    ];
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.tokens.elev1,
          border: Border(top: BorderSide(color: context.tokens.line, width: 1)),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        child: Row(
          children: [
            for (final (i, (label, icon, iconActive)) in tabs.indexed)
              Expanded(
                child: _Tab(
                  label: label,
                  icon: icon,
                  iconActive: iconActive,
                  active: shell.currentIndex == i,
                  onTap: () => shell.goBranch(
                    i,
                    initialLocation: i == shell.currentIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData iconActive;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.iconActive,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? iconActive : icon,
              size: 22,
              color: active ? context.tokens.ink : context.tokens.inkDim,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? context.tokens.ink : context.tokens.inkDim,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
