// typography.dart — N (mono number), Label (small caps uppercase)
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/app_tokens.dart';

/// Mono number — for scores/stats/ratings. Uses JetBrainsMono with tabular digits.
class N extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;
  final TextAlign? textAlign;

  const N(
    this.text, {
    super.key,
    this.size = 14,
    this.weight = FontWeight.w500,
    this.color,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: size,
        fontWeight: weight,
        color: color ?? context.tokens.ink,
        letterSpacing: -0.02,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      ),
    );
  }
}

/// Small caps uppercase section marker.
class Label extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;

  const Label(this.text, {super.key, this.color, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: context.tokens.fontMono,
        fontFamilyFallback: context.tokens.monoFallbacks,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: color ?? context.tokens.inkDim,
      ),
    );
  }
}
