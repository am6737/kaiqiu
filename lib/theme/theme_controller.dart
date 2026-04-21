// theme_controller.dart — runtime-switchable theme mode + accent.
// Mirrors the LocaleController pattern: a singleton ChangeNotifier
// backed by SharedPreferences, watched at the app root by AnimatedBuilder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_storage.dart';
import 'accent_seed.dart';
import 'theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Constructor exposed for unit tests so each test gets a fresh state.
  @visibleForTesting
  factory ThemeController.test() = ThemeController._;

  ThemeMode _mode = ThemeMode.system;
  AccentSeed _seed = AccentSeed.defaultSeed;

  ThemeMode get mode => _mode;
  AccentSeed get seed => _seed;

  Future<void> load() async {
    _mode = LocalStore.themeMode;
    _seed = LocalStore.themeSeed;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    await LocalStore.setThemeMode(m);
    notifyListeners();
  }

  Future<void> setSeed(AccentSeed s) async {
    if (_seed == s) return;
    _seed = s;
    await LocalStore.setThemeSeed(s);
    notifyListeners();
  }

  ThemeData get lightTheme => buildAppTheme(Brightness.light, _seed);
  ThemeData get darkTheme => buildAppTheme(Brightness.dark, _seed);
}

final themeControllerProvider = ChangeNotifierProvider<ThemeController>(
  (_) => ThemeController.instance,
);
