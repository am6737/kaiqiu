// step_basic_info.dart — Step 2: basic event information
import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../theme/app_tokens.dart';
import 'event_form_fields.dart';

class StepBasicInfo extends StatelessWidget {
  final TextEditingController nameController;
  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController venueController;
  final TextEditingController feeController;
  final TextEditingController prizeController;
  final Map<String, String?> errors;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const StepBasicInfo({
    super.key,
    required this.nameController,
    required this.startDate,
    required this.endDate,
    required this.venueController,
    required this.feeController,
    required this.prizeController,
    required this.errors,
    required this.onPickStart,
    required this.onPickEnd,
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
            l.create_event_step_basic,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.tokens.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          EventField(label: l.create_event_f_name, controller: nameController, errorText: errors['name']),
          Row(
            children: [
              Expanded(
                child: EventDateField(
                  label: l.create_event_f_start,
                  value: startDate,
                  errorText: errors['start'],
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EventDateField(
                  label: l.create_event_f_end,
                  value: endDate,
                  errorText: errors['end'],
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          EventField(label: l.create_event_f_venue, controller: venueController, errorText: errors['venue']),
          Row(
            children: [
              Expanded(
                child: EventField(
                  label: l.create_event_f_fee,
                  controller: feeController,
                  prefix: '¥',
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: errors['fee'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EventField(
                  label: l.create_event_f_prize,
                  controller: prizeController,
                  prefix: '¥',
                  mono: true,
                  keyboardType: TextInputType.number,
                  errorText: errors['prize'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
