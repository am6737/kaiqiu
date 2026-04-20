// profile_screen.dart — 我的 (tab root, menu-style)
// Matches new prototype: identity strip → archive entry card → activity → settings
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock.dart' show MockUser;
import '../../providers.dart';
import '../../services/supabase.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/typography.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Real profile from Supabase (name, handle, city, position), mock
    // fallback for stats/attrs/honors which require real match history.
    final MockUser u = ref.watch(myProfileProvider).valueOrNull ??
        ref.watch(userProvider);
    final teammates = ref.watch(teammatesProvider);

    final activity = [
      (Icons.calendar_today, '我报名的赛事', '2', null),
      (Icons.map_outlined, '我组织的球局', '1', null),
      (Icons.person_outline, '我的队伍', '${teammates.length}', null),
      (Icons.bookmark_border, '收藏与足迹', null, null),
    ];

    final settings = <(IconData, String, String?, String?)>[
      (Icons.settings_outlined, '账号设置', null, null),
      (Icons.notifications_none, '通知与消息', null, null),
      (Icons.chat_bubble_outline, '帮助与反馈', null, null),
      (Icons.emoji_events_outlined, '关于开球', null, 'v0.1'),
    ];

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: const [
                  Text('我的',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: T.ink,
                          letterSpacing: -0.5)),
                  Spacer(),
                  Icon(Icons.settings_outlined, color: T.ink, size: 20),
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
                        Text(u.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: T.ink,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 4),
                        Text(
                          u.handle,
                          style: const TextStyle(
                              fontFamily: T.fontMono,
                              fontFamilyFallback: T.monoFallbacks,
                              fontSize: 12,
                              color: T.inkSub,
                              letterSpacing: 0.2),
                        ),
                      ],
                    ),
                  ),
                  const PrimaryButton(
                    label: '编辑',
                    variant: BtnVariant.ghost,
                    size: BtnSize.sm,
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
                              color: T.live),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('我的球员档案',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: T.ink)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: T.liveDim,
                                    border: Border.all(
                                        color: const Color(0x6600FF85)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text('NEW',
                                      style: TextStyle(
                                          fontFamily: T.fontMono,
                                          fontFamilyFallback: T.monoFallbacks,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: T.live)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${u.positionFull} · ${u.city} ${u.district}',
                              style: const TextStyle(
                                  fontSize: 11, color: T.inkSub),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 2,
                              children: [
                                _MiniStat(
                                    label: '综合',
                                    value: '${u.rating}',
                                    color: T.live),
                                _MiniStat(
                                    label: '场次',
                                    value: '${u.stats.matches}',
                                    color: T.ink),
                                _MiniStat(
                                    label: '进球',
                                    value: '${u.stats.goals}',
                                    color: T.ink),
                                _MiniStat(
                                    label: 'MVP',
                                    value: '${u.stats.mvp}',
                                    color: T.warn),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          size: 14, color: T.inkDim),
                    ],
                  ),
                ),
              ),
            ),
            _EntrySection(title: '我的活动', items: activity),
            _EntrySection(title: '设置', items: settings),
            // Sign-out
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: GestureDetector(
                onTap: () async {
                  await supabase.auth.signOut();
                  // Router redirect will push to /sign-in automatically.
                },
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: T.elev2,
                    border: Border.all(color: T.line),
                    borderRadius: BorderRadius.circular(T.r2),
                  ),
                  child: const Text('退出登录',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: T.danger)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: const TextStyle(fontSize: 11, color: T.inkSub)),
        N(value, size: 11, weight: FontWeight.w700, color: color),
      ],
    );
  }
}

class _EntrySection extends StatelessWidget {
  final String title;
  // (icon, label, badge, trailing)
  final List<(IconData, String, String?, String?)> items;
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
              color: T.elev2,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(T.r2),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) _row(items[i], i > 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row((IconData, String, String?, String?) item, bool divider) {
    final (icon, label, badge, trailing) = item;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: divider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: T.line, width: 1)))
          : null,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.elev3,
              border: Border.all(color: T.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: T.inkSub),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: T.ink,
                    fontWeight: FontWeight.w500)),
          ),
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: T.elev3,
                border: Border.all(color: T.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                    fontFamily: T.fontMono,
                    fontFamilyFallback: T.monoFallbacks,
                    fontSize: 10,
                    color: T.inkSub,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (trailing != null) ...[
            Label(trailing),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, size: 14, color: T.inkDim),
        ],
      ),
    );
  }
}
