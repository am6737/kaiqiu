// city_picker_screen.dart — 城市选择
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';

class CityPickerScreen extends ConsumerWidget {
  const CityPickerScreen({super.key});

  static const _hot = [
    '北京',
    '上海',
    '广州',
    '深圳',
    '杭州',
    '成都',
    '武汉',
    '西安',
    '南京',
    '重庆',
    '苏州',
    '天津',
  ];

  static const _all = [
    '北京',
    '上海',
    '广州',
    '深圳',
    '杭州',
    '成都',
    '武汉',
    '西安',
    '南京',
    '重庆',
    '苏州',
    '天津',
    '青岛',
    '大连',
    '厦门',
    '福州',
    '郑州',
    '长沙',
    '合肥',
    '济南',
    '沈阳',
    '哈尔滨',
    '长春',
    '昆明',
    '南宁',
    '贵阳',
    '兰州',
    '乌鲁木齐',
    '呼和浩特',
    '银川',
    '拉萨',
    '西宁',
    '石家庄',
    '太原',
    '海口',
    '三亚',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = LocalStore.city;
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.city_picker_title,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: T.elev2,
                  border: Border.all(color: T.line),
                  borderRadius: BorderRadius.circular(T.r2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: T.live,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.city_picker_current,
                            style: const TextStyle(
                              fontSize: 11,
                              color: T.inkSub,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            current,
                            style: const TextStyle(
                              fontSize: 14,
                              color: T.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check, size: 16, color: T.live),
                  ],
                ),
              ),
            ),
            SectionHeader(title: l.city_picker_hot),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _hot)
                    _CityChip(
                      label: c,
                      active: c == current,
                      onTap: () => _pick(context, c),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SectionHeader(title: l.city_picker_all),
            for (final c in _all)
              _CityRow(
                city: c,
                active: c == current,
                onTap: () => _pick(context, c),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, String city) async {
    await LocalStore.setCity(city);
    if (context.mounted) context.pop();
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CityChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? T.liveDim : T.elev2,
          border: Border.all(color: active ? T.live : T.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? T.live : T.ink,
          ),
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final String city;
  final bool active;
  final VoidCallback onTap;
  const _CityRow({
    required this.city,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: T.line, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                city,
                style: TextStyle(
                  fontSize: 15,
                  color: active ? T.live : T.ink,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (active) const Icon(Icons.check, size: 16, color: T.live),
          ],
        ),
      ),
    );
  }
}
