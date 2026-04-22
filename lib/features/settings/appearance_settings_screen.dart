// appearance_settings_screen.dart — 外观设置(主题模式 + 主题色)
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/accent_seed.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/section_header.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = context.l10n;
    ref.watch(themeControllerProvider); // rebuild on change
    final tc = ThemeController.instance;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            PageTitleBar(
              title: l.settings_appearance_title,
              onBack: () => context.pop(),
            ),
            _SectionHeader(label: l.appearance_theme_mode_section),
            _ModeSelector(controller: tc),
            const SizedBox(height: 18),
            _SectionHeader(label: l.appearance_accent_section),
            _AccentSelector(controller: tc),
            const SizedBox(height: 18),
            _SectionHeader(label: l.appearance_preview_section),
            const _PreviewCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: t.inkSub,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final ThemeController controller;
  const _ModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final entries = <(ThemeMode, String)>[
      (ThemeMode.system, l.appearance_theme_mode_system),
      (ThemeMode.light, l.appearance_theme_mode_light),
      (ThemeMode.dark, l.appearance_theme_mode_dark),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r2),
        ),
        child: Column(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) Divider(height: 1, color: t.line),
              InkWell(
                onTap: () => controller.setMode(entries[i].$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entries[i].$2,
                          style: TextStyle(
                            fontSize: 14,
                            color: t.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (controller.mode == entries[i].$1)
                        Icon(Icons.check, color: t.accent, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccentSelector extends StatelessWidget {
  final ThemeController controller;
  const _AccentSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    // Show resolved color for each preset using *current* brightness for swatch.
    final brightness = Theme.of(context).brightness;
    final presets = <(PresetAccent, String)>[
      (PresetAccent.green, l.appearance_accent_green),
      (PresetAccent.orange, l.appearance_accent_orange),
      (PresetAccent.cyan, l.appearance_accent_cyan),
      (PresetAccent.red, l.appearance_accent_red),
    ];

    bool isSelectedPreset(PresetAccent p) {
      final s = controller.seed;
      return s is PresetAccentSeed && s.preset == p;
    }
    final isCustom = controller.seed is CustomAccentSeed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r2),
        ),
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (p, label) in presets)
              _AccentSwatch(
                color: _resolvePresetColor(p, brightness),
                label: label,
                selected: isSelectedPreset(p),
                onTap: () => controller.setSeed(PresetAccentSeed(p)),
              ),
            _AccentSwatch(
              color: isCustom ? (controller.seed as CustomAccentSeed).color : t.elev3,
              label: l.appearance_accent_custom,
              selected: isCustom,
              isCustomEntry: true,
              onTap: () => _openColorPicker(context),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolvePresetColor(PresetAccent p, Brightness brightness) {
    // Mirror the spec §5.2 hand-tuned values for swatch display.
    return switch ((p, brightness)) {
      (PresetAccent.green, Brightness.dark) => const Color(0xFF34D399),
      (PresetAccent.green, Brightness.light) => const Color(0xFF00A864),
      (PresetAccent.orange, Brightness.dark) => const Color(0xFFFF8A3D),
      (PresetAccent.orange, Brightness.light) => const Color(0xFFE25A0A),
      (PresetAccent.cyan, Brightness.dark) => const Color(0xFF00E5FF),
      (PresetAccent.cyan, Brightness.light) => const Color(0xFF0090A8),
      (PresetAccent.red, Brightness.dark) => const Color(0xFFFF3D5A),
      (PresetAccent.red, Brightness.light) => const Color(0xFFD32647),
    };
  }

  Future<void> _openColorPicker(BuildContext context) async {
    final l = context.l10n;
    Color picked = controller.seed is CustomAccentSeed
        ? (controller.seed as CustomAccentSeed).color
        : const Color(0xFF7A3DEC);
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        Color current = picked;
        return AlertDialog(
          backgroundColor: ctx.tokens.elev2,
          title: Text(l.appearance_picker_title,
              style: TextStyle(color: ctx.tokens.ink)),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: current,
              onColorChanged: (c) => current = c,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.appearance_picker_cancel,
                  style: TextStyle(color: ctx.tokens.inkSub)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(current),
              child: Text(l.appearance_picker_confirm,
                  style: TextStyle(color: ctx.tokens.accent)),
            ),
          ],
        );
      },
    );
    if (result != null) {
      await controller.setSeed(CustomAccentSeed(result.toARGB32()));
    }
  }
}

class _AccentSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final bool isCustomEntry;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCustomEntry = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? t.ink : t.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: isCustomEntry && !selected
                ? Icon(Icons.add, color: t.ink, size: 20)
                : (selected
                    ? Icon(Icons.check,
                        color: _onColor(color), size: 20)
                    : null),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: t.inkSub),
          ),
        ],
      ),
    );
  }

  Color _onColor(Color c) {
    // Simple luminance check using new float API (r, g, b are 0.0–1.0).
    final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return lum > 0.6 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.elev2,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(t.r2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.appearance_preview_card_title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.appearance_preview_card_meta,
              style: TextStyle(fontSize: 12, color: t.inkSub),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(t.r1),
                  ),
                  child: Text(
                    l.appearance_preview_card_cta,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.accentInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: t.accentSubtle,
                    borderRadius: BorderRadius.circular(t.r1),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: t.accent,
                      fontFamily: t.fontMono,
                      fontFamilyFallback: t.monoFallbacks,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
