// lib/widgets/interaction_btn.dart
import 'package:flutter/material.dart';

class InteractionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const InteractionBtn(
      {super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ],
    );
  }
}
