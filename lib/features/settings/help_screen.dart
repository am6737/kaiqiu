// help_screen.dart — 帮助与反馈
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../services/local_storage.dart';
import '../../theme/tokens.dart';
import '../../utils/toast.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _fbC = TextEditingController();
  int? _openIdx;

  @override
  void dispose() {
    _fbC.dispose();
    super.dispose();
  }

  List<(String, String)> _faqs(AppL10n l) => [
    (l.settings_help_faq_1_q, l.settings_help_faq_1_a),
    (l.settings_help_faq_2_q, l.settings_help_faq_2_a),
    (l.settings_help_faq_3_q, l.settings_help_faq_3_a),
    (l.settings_help_faq_4_q, l.settings_help_faq_4_a),
    (l.settings_help_faq_5_q, l.settings_help_faq_5_a),
    (l.settings_help_faq_6_q, l.settings_help_faq_6_a),
  ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final faqs = _faqs(l);
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            PageTitleBar(
              title: l.settings_help_title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: T.elev2,
                        border: Border.all(color: T.line),
                        borderRadius: BorderRadius.circular(T.r2),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < faqs.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: T.line),
                            _FaqRow(
                              q: faqs[i].$1,
                              a: faqs[i].$2,
                              open: _openIdx == i,
                              onTap: () => setState(
                                () => _openIdx = _openIdx == i ? null : i,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      l.settings_help_feedback,
                      style: const TextStyle(
                        fontSize: 13,
                        color: T.inkSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: T.elev2,
                        border: Border.all(color: T.line),
                        borderRadius: BorderRadius.circular(T.r2),
                      ),
                      child: TextField(
                        controller: _fbC,
                        maxLines: 5,
                        style: const TextStyle(color: T.ink, fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: l.settings_help_feedback_hint,
                          hintStyle: const TextStyle(
                            color: T.inkDim,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PrimaryButton(
                      label: l.settings_help_feedback_submit,
                      variant: BtnVariant.primary,
                      size: BtnSize.md,
                      full: true,
                      onPressed: () async {
                        final t = _fbC.text.trim();
                        if (t.isEmpty) return;
                        await LocalStore.pushFeedback(t);
                        _fbC.clear();
                        if (!mounted) return;
                        showToast(
                          context,
                          l.settings_help_feedback_thanks,
                          success: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  final String q, a;
  final bool open;
  final VoidCallback onTap;
  const _FaqRow({
    required this.q,
    required this.a,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    q,
                    style: const TextStyle(
                      fontSize: 14,
                      color: T.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  color: T.inkSub,
                  size: 18,
                ),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 8),
              Text(
                a,
                style: const TextStyle(
                  fontSize: 13,
                  color: T.inkSub,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
