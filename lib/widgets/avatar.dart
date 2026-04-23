import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class Avatar extends StatelessWidget {
  final String name;
  final double size;

  const Avatar(this.name, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightness = isDark ? 0.22 : 0.82;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, 220, 0.12, lightness).toColor(),
        shape: BoxShape.circle,
        border: Border.all(color: context.tokens.line, width: 1),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: context.tokens.inkDim,
      ),
    );
  }
}
