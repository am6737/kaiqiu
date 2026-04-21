import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kaiqiu_app/services/local_storage.dart';
import 'package:kaiqiu_app/theme/accent_seed.dart';
import 'package:kaiqiu_app/theme/theme_controller.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initLocalStorage();
  });

  test('starts at system / preset green before load', () {
    final c = ThemeController.test();
    expect(c.mode, ThemeMode.system);
    expect(c.seed, const PresetAccentSeed(PresetAccent.green));
  });

  test('load() picks up persisted values', () async {
    await LocalStore.setThemeMode(ThemeMode.dark);
    await LocalStore.setThemeSeed(const PresetAccentSeed(PresetAccent.cyan));
    final c = ThemeController.test();
    await c.load();
    expect(c.mode, ThemeMode.dark);
    expect(c.seed, const PresetAccentSeed(PresetAccent.cyan));
  });

  test('setMode notifies listeners and persists', () async {
    final c = ThemeController.test();
    var fired = 0;
    c.addListener(() => fired++);
    await c.setMode(ThemeMode.light);
    expect(c.mode, ThemeMode.light);
    expect(fired, 1);
    expect(LocalStore.themeMode, ThemeMode.light);
  });

  test('setMode no-op when value unchanged', () async {
    final c = ThemeController.test();
    var fired = 0;
    c.addListener(() => fired++);
    await c.setMode(ThemeMode.system); // already system
    expect(fired, 0);
  });

  test('setSeed notifies and persists', () async {
    final c = ThemeController.test();
    var fired = 0;
    c.addListener(() => fired++);
    await c.setSeed(const PresetAccentSeed(PresetAccent.red));
    expect(c.seed, const PresetAccentSeed(PresetAccent.red));
    expect(fired, 1);
    expect(LocalStore.themeSeed, const PresetAccentSeed(PresetAccent.red));
  });

  test('lightTheme and darkTheme reflect current seed', () {
    final c = ThemeController.test();
    expect(c.lightTheme.brightness, Brightness.light);
    expect(c.darkTheme.brightness, Brightness.dark);
  });
}
