// step_template.dart — Step 1: tournament template selection
import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import 'bracket_mini_painter.dart';

class StepTemplate extends StatelessWidget {
  final String selectedTemplate;
  final ValueChanged<String> onTemplateChanged;

  const StepTemplate({
    super.key,
    required this.selectedTemplate,
    required this.onTemplateChanged,
  });

  List<(String, String, String)> _tpls(BuildContext context) {
    final l = context.l10n;
    return [
      ('group8', l.create_event_tpl_group8, l.create_event_tpl_group8_desc),
      (
        'knockout16',
        l.create_event_tpl_knockout16,
        l.create_event_tpl_knockout16_desc,
      ),
      ('wc', l.create_event_tpl_wc, l.create_event_tpl_wc_desc),
      ('league', l.create_event_tpl_league, l.create_event_tpl_league_desc),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tpls = _tpls(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_tpl_title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.create_event_tpl_subtitle,
            style: TextStyle(fontSize: 13, color: context.tokens.inkSub),
          ),
          const SizedBox(height: 18),
          for (final t in tpls) ...[
            GestureDetector(
              onTap: () => onTemplateChanged(t.$1),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selectedTemplate == t.$1 ? context.tokens.elev3 : context.tokens.elev2,
                  border: Border.all(color: selectedTemplate == t.$1 ? context.tokens.accent : context.tokens.line),
                  borderRadius: BorderRadius.circular(context.tokens.r3),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CustomPaint(
                        painter: BracketMiniPainter(t.$1, selectedTemplate == t.$1, inkSub: context.tokens.inkSub, inkMute: context.tokens.inkMute, accent: context.tokens.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.$2,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t.$3,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.tokens.inkSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedTemplate == t.$1 ? context.tokens.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedTemplate == t.$1 ? context.tokens.accent : context.tokens.line,
                          width: 1.5,
                        ),
                      ),
                      child: selectedTemplate == t.$1
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
