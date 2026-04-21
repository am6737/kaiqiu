// primary_button.dart — matches React Button (primary/secondary/ghost/warn)
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../theme/app_tokens.dart';

enum BtnVariant { primary, secondary, ghost, warn }

enum BtnSize { sm, md, lg }

class PrimaryButton extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final BtnVariant variant;
  final BtnSize size;
  final bool full;
  final bool disabled;

  const PrimaryButton({
    super.key,
    this.label,
    this.child,
    this.onPressed,
    this.variant = BtnVariant.primary,
    this.size = BtnSize.md,
    this.full = false,
    this.disabled = false,
  }) : assert(label != null || child != null);

  @override
  Widget build(BuildContext context) {
    final (h, px, fs) = switch (size) {
      BtnSize.sm => (32.0, 12.0, 13.0),
      BtnSize.md => (44.0, 18.0, 15.0),
      BtnSize.lg => (52.0, 24.0, 16.0),
    };
    final (bg, fg, border) = switch (variant) {
      BtnVariant.primary => (context.tokens.accent, Colors.black, Colors.transparent),
      BtnVariant.secondary => (context.tokens.elev3, context.tokens.ink, context.tokens.line),
      BtnVariant.ghost => (Colors.transparent, context.tokens.ink, context.tokens.lineStrong),
      BtnVariant.warn => (context.tokens.warn, Colors.black, Colors.transparent),
    };
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: px),
          width: full ? double.infinity : null,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(context.tokens.r2),
            border: Border.all(color: border),
          ),
          child:
              child ??
              Text(
                label!,
                style: TextStyle(
                  fontSize: fs,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: -0.2,
                ),
              ),
        ),
      ),
    );
  }
}
