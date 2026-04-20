// locale_controller.dart — 应用级语言切换
import 'package:flutter/widgets.dart';

import '../services/local_storage.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const List<Locale> supported = [Locale('zh'), Locale('en')];

  Locale _resolve(String? code) {
    if (code == 'zh') return const Locale('zh');
    if (code == 'en') return const Locale('en');
    // follow system
    final platform = WidgetsBinding.instance.platformDispatcher.locale;
    return platform.languageCode == 'zh'
        ? const Locale('zh')
        : const Locale('en');
  }

  Locale get current => _resolve(LocalStore.localeCode);

  /// null => follow system
  String? get explicitCode => LocalStore.localeCode;

  Future<void> set(String? code) async {
    await LocalStore.setLocaleCode(code);
    notifyListeners();
  }
}
