// chip_pill.dart — filter / pill chip
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/app_tokens.dart';

class ChipPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final double height;

  const ChipPill({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.height = 26,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? T.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? T.ink : context.tokens.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.black : T.inkSub,
          ),
        ),
      ),
    );
  }
}
