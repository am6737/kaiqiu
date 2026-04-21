// avatar.dart — monogram-on-tinted-bg avatar
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class Avatar extends StatelessWidget {
  final String name;
  final double size;

  const Avatar(this.name, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '•' : name.characters.first.toUpperCase();
    final hue = name.isEmpty ? 140 : (name.codeUnitAt(0) * 37) % 360;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HSLColor.fromAHSL(1, hue.toDouble(), 0.2, 0.22).toColor(),
        shape: BoxShape.circle,
        border: Border.all(color: context.tokens.line, width: 1),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: context.tokens.fontMono,
          fontFamilyFallback: context.tokens.monoFallbacks,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: context.tokens.ink,
        ),
      ),
    );
  }
}
