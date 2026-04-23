class EventValidators {
  static String? requiredText(String? value, String errorMsg) {
    if ((value ?? '').trim().isEmpty) return errorMsg;
    return null;
  }

  static String? futureDate(DateTime? date, String requiredMsg, String futureMsg) {
    if (date == null) return requiredMsg;
    if (!date.isAfter(DateTime.now())) return futureMsg;
    return null;
  }

  static String? dateAfter(DateTime? date, DateTime? after, String requiredMsg, String afterMsg) {
    if (date == null) return requiredMsg;
    if (after != null && !date.isAfter(after)) return afterMsg;
    return null;
  }

  static String? dateBefore(DateTime? date, DateTime? before, String requiredMsg, String beforeMsg) {
    if (date == null) return requiredMsg;
    if (before != null && !date.isBefore(before)) return beforeMsg;
    return null;
  }

  static String? nonNegativeInt(String? value, String errorMsg) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null || n < 0) return errorMsg;
    return null;
  }

  static String? positiveInt(String? value, String errorMsg) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return errorMsg;
    final n = int.tryParse(s);
    if (n == null || n <= 0) return errorMsg;
    return null;
  }

  static String? minInt(String? value, int min, String errorMsg) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return errorMsg;
    final n = int.tryParse(s);
    if (n == null || n < min) return errorMsg;
    return null;
  }

  static String? phone(String? value, String requiredMsg, String formatMsg) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return requiredMsg;
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(s)) return formatMsg;
    return null;
  }
}
