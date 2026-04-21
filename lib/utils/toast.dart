// toast.dart — 统一 SnackBar 包装
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/app_tokens.dart';

void showToast(
  BuildContext context,
  String msg, {
  bool success = false,
  bool error = false,
}) {
  final Color bg = error
      ? context.tokens.danger
      : success
      ? context.tokens.accent
      : context.tokens.elev3;
  final Color fg = (success || error) ? Colors.black : context.tokens.ink;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.r2)),
    ),
  );
}
