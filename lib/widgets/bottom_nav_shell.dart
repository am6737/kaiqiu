// bottom_nav_shell.dart — 4-tab bottom nav, wraps StatefulShellRoute children
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n_extension.dart';
import '../providers.dart';
import '../theme/app_tokens.dart';
import 'in_app_notification.dart';

class BottomNavShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  const BottomNavShell({super.key, required this.shell});

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell> {
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(myProfileProvider, (_, next) {
      if (_checkedOnboarding) return;
      final profile = next.valueOrNull?.profile;
      if (profile != null &&
          profile.name == '新球友' &&
          profile.avatarUrl == null) {
        _checkedOnboarding = true;
        context.go('/onboarding');
      } else if (profile != null) {
        _checkedOnboarding = true;
      }
    });
    ref.listenManual(globalNewMessageProvider, (_, next) {
      next.whenData((msg) async {
        final activeConv = ref.read(activeConvIdProvider);
        if (msg.convId == activeConv) return;

        final convs = ref.read(conversationsProvider).valueOrNull ?? [];
        if (!convs.any((c) => c.id == msg.convId)) {
          ref.read(messagesRepoProvider).refreshConversations();
        }

        String senderName = '新消息';
        String? avatarUrl;
        if (msg.senderId != null) {
          try {
            final profile =
                await ref.read(profileByIdProvider(msg.senderId!).future);
            senderName = profile?.name ?? senderName;
            avatarUrl = profile?.avatarUrl;
          } catch (_) {}
        }
        if (!mounted) return;
        showInAppNotification(
          context,
          title: senderName,
          body: msg.body ?? '',
          avatarUrl: avatarUrl,
          onTap: () => context.push('/chat/${msg.convId}'),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabs = <(String, IconData, IconData)>[
      (l.tab_home, Icons.home_outlined, Icons.home),
      (l.tab_pickup, Icons.sports_soccer_outlined, Icons.sports_soccer),
      (l.tab_events, Icons.emoji_events_outlined, Icons.emoji_events),
      (l.tab_me, Icons.person_outline, Icons.person),
    ];
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: widget.shell,
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
                  active: widget.shell.currentIndex == i,
                  onTap: () => widget.shell.goBranch(
                    i,
                    initialLocation: i == widget.shell.currentIndex,
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
              color: active ? context.tokens.accent : context.tokens.inkDim,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? context.tokens.accent : context.tokens.inkDim,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
