// step_registration.dart — Step 3: registration settings
import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/typography.dart';
import 'event_form_fields.dart';

class StepRegistration extends StatelessWidget {
  final DateTime? deadlineDate;
  final String review;
  final TextEditingController teamSizeController;
  final TextEditingController maxTeamsController;
  final Map<String, String?> errors;
  final ValueChanged<String> onReviewChanged;
  final VoidCallback onPickDeadline;

  const StepRegistration({
    super.key,
    required this.deadlineDate,
    required this.review,
    required this.teamSizeController,
    required this.maxTeamsController,
    required this.errors,
    required this.onReviewChanged,
    required this.onPickDeadline,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.create_event_step_registration,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          EventDateField(
            label: l.create_event_f_deadline,
            value: deadlineDate,
            errorText: errors['deadline'],
            onTap: onPickDeadline,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Label(l.create_event_review_title),
          ),
          Row(
            children: [
              for (final opt in [
                ('auto', l.create_event_review_auto),
                ('manual', l.create_event_review_manual),
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onReviewChanged(opt.$1),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: review == opt.$1 ? context.tokens.elev3 : context.tokens.elev2,
                        border: Border.all(
                          color: review == opt.$1 ? context.tokens.accent : context.tokens.line,
                        ),
                        borderRadius: BorderRadius.circular(context.tokens.r2),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: review == opt.$1 ? context.tokens.accent : context.tokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                if (opt.$1 == 'auto') const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: EventField(
                  label: l.create_event_f_teamsize,
                  controller: teamSizeController,
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: errors['teamSize'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EventField(
                  label: l.create_event_f_maxteams,
                  controller: maxTeamsController,
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: errors['maxTeams'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 14, color: context.tokens.warn),
                    const SizedBox(width: 8),
                    Label(l.create_event_organizer_tip_title, color: context.tokens.warn),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l.create_event_organizer_tip_body,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.tokens.inkSub,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
