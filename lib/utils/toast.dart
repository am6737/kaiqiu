// toast.dart — 统一 SnackBar 包装
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

void showToast(
  BuildContext context,
  String msg, {
  bool success = false,
  bool error = false,
}) {
  final Color bg = error
      ? T.danger
      : success
      ? T.live
      : T.elev3;
  final Color fg = (success || error) ? Colors.black : T.ink;
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
