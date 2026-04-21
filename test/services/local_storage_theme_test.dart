import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  test('themeMode defaults to system', () {
    expect(LocalStore.themeMode, ThemeMode.system);
  });

  test('themeMode round-trips light/dark/system', () async {
    await LocalStore.setThemeMode(ThemeMode.light);
    expect(LocalStore.themeMode, ThemeMode.light);
    await LocalStore.setThemeMode(ThemeMode.dark);
    expect(LocalStore.themeMode, ThemeMode.dark);
    await LocalStore.setThemeMode(ThemeMode.system);
    expect(LocalStore.themeMode, ThemeMode.system);
  });

  test('themeSeed defaults to preset:green', () {
    final seed = LocalStore.themeSeed;
    expect(seed, isA<PresetAccentSeed>());
    expect((seed as PresetAccentSeed).preset, PresetAccent.green);
  });

  test('themeSeed round-trips preset', () async {
    await LocalStore.setThemeSeed(const PresetAccentSeed(PresetAccent.orange));
    final seed = LocalStore.themeSeed;
    expect(seed, const PresetAccentSeed(PresetAccent.orange));
  });

  test('themeSeed round-trips custom', () async {
    await LocalStore.setThemeSeed(const CustomAccentSeed(0xFF7A3DEC));
    final seed = LocalStore.themeSeed;
    expect(seed, const CustomAccentSeed(0xFF7A3DEC));
  });
}
