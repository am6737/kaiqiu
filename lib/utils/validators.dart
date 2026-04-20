// validators.dart — 表单校验
final _emailRe = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'empty';
  if (!_emailRe.hasMatch(s)) return 'format';
  return null;
}

String? validatePassword(String? v) {
  final s = v ?? '';
  if (s.isEmpty) return 'empty';
  if (s.length < 6) return 'too_short';
  return null;
}

String? validateRequired(String? v) {
  if ((v ?? '').trim().isEmpty) return 'empty';
  return null;
}

String? validateInt(String? v, {int? min, int? max}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'empty';
  final n = int.tryParse(s);
  if (n == null) return 'not_int';
  if (min != null && n < min) return 'too_small';
  if (max != null && n > max) return 'too_big';
  return null;
}

String? validateDateString(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'empty';
  try {
    DateTime.parse(s);
    return null;
  } catch (_) {
    return 'format';
  }
}

String? validatePhone(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'empty';
  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(s)) return 'format';
  return null;
}
