// bottom_nav_shell.dart — 5-tab bottom nav, wraps StatefulShellRoute children
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/tokens.dart';

class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const BottomNavShell({super.key, required this.shell});

  static const _tabs = [
    ('首页', Icons.home_outlined, Icons.home),
    ('约球', Icons.map_outlined, Icons.map),
    ('赛事', Icons.emoji_events_outlined, Icons.emoji_events),
    ('消息', Icons.chat_bubble_outline, Icons.chat_bubble),
    ('我的', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: T.elev1,
          border: Border(top: BorderSide(color: T.line, width: 1)),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        child: Row(
          children: [
            for (final (i, (label, icon, iconActive)) in _tabs.indexed)
              Expanded(
                child: _Tab(
                  label: label,
                  icon: icon,
                  iconActive: iconActive,
                  active: shell.currentIndex == i,
                  onTap: () => shell.goBranch(i,
                      initialLocation: i == shell.currentIndex),
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
            Icon(active ? iconActive : icon,
                size: 22, color: active ? T.ink : T.inkDim),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? T.ink : T.inkDim,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
