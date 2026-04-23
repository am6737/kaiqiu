// step_basic_info.dart — Step 2: basic event information
import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import '../../models/picked_location.dart';
import '../../theme/app_tokens.dart';
import 'event_form_fields.dart';

class StepBasicInfo extends StatelessWidget {
  final TextEditingController nameController;
  final DateTime? startDate;
  final DateTime? endDate;
  final PickedLocation? pickedLocation;
  final VoidCallback onPickLocation;
  final VoidCallback onClearLocation;
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
    required this.pickedLocation,
    required this.onPickLocation,
    required this.onClearLocation,
    required this.feeController,
    required this.prizeController,
    required this.errors,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final hasError = errors['venue'] != null;
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
          // Venue picker (replaces EventField text input)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.create_event_f_venue,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.inkDim,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onPickLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.tokens.elev2,
                      border: Border.all(
                        color: hasError ? Colors.red : context.tokens.line,
                      ),
                      borderRadius: BorderRadius.circular(context.tokens.r2),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 20,
                          color: pickedLocation != null
                              ? context.tokens.accent
                              : context.tokens.inkDim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: pickedLocation != null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pickedLocation!.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.tokens.ink,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pickedLocation!.address,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.tokens.inkDim,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                )
                              : Text(
                                  l.create_event_f_venue,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.tokens.inkDim,
                                  ),
                                ),
                        ),
                        if (pickedLocation != null)
                          GestureDetector(
                            onTap: onClearLocation,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: context.tokens.inkDim,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: context.tokens.inkDim,
                          ),
                      ],
                    ),
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 4),
                  Text(
                    errors['venue']!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
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
