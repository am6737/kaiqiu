import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../theme/app_tokens.dart';
import 'bracket_panel.dart';
import 'standings_panel.dart';

class CompetitionPanel extends StatefulWidget {
  final String eventId;
  const CompetitionPanel({super.key, required this.eventId});

  @override
  State<CompetitionPanel> createState() => _CompetitionPanelState();
}

class _CompetitionPanelState extends State<CompetitionPanel> {
  String _sub = 'bracket';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _SegmentedControl(
            value: _sub,
            items: [
              ('bracket', l.event_tab_bracket),
              ('standings', l.event_tab_standings),
            ],
            onChanged: (v) => setState(() => _sub = v),
          ),
        ),
        if (_sub == 'bracket')
          BracketPanel(eventId: widget.eventId)
        else
          StandingsPanel(eventId: widget.eventId),
      ],
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  const _SegmentedControl({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.tokens.elev2,
        borderRadius: BorderRadius.circular(context.tokens.r2),
        border: Border.all(color: context.tokens.line),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: value == item.$1
                        ? context.tokens.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      context.tokens.r2 - 2,
                    ),
                  ),
                  child: Text(
                    item.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value == item.$1
                          ? context.tokens.accentInk
                          : context.tokens.inkSub,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
