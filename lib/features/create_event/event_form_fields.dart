// event_form_fields.dart — shared form field widgets for create event steps
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/typography.dart';

class EventField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final bool mono;
  final String? errorText;
  final TextInputType? keyboardType;
  const EventField({
    super.key,
    required this.label,
    required this.controller,
    this.prefix,
    this.mono = false,
    this.errorText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.tokens.elev2,
              border: Border.all(color: hasError ? Colors.red : context.tokens.line),
              borderRadius: BorderRadius.circular(context.tokens.r2),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: N(prefix!, size: 15, color: context.tokens.inkDim),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: TextStyle(
                      color: context.tokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      fontFamily: mono ? context.tokens.fontMono : null,
                      fontFamilyFallback: mono ? context.tokens.monoFallbacks : null,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

class EventDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  const EventDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final display = value != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(value!)
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.tokens.elev2,
                border: Border.all(color: hasError ? Colors.red : context.tokens.line),
                borderRadius: BorderRadius.circular(context.tokens.r2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        color: display.isEmpty ? context.tokens.inkDim : context.tokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        fontFamily: context.tokens.fontMono,
                        fontFamilyFallback: context.tokens.monoFallbacks,
                      ),
                    ),
                  ),
                  Icon(Icons.calendar_today, size: 16, color: context.tokens.inkSub),
                ],
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}
