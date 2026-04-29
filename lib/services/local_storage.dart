// local_storage.dart — 本地持久化（收藏/关注/提醒/竞猜/通知/语言/城市）
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/accent_seed.dart';

late SharedPreferences _prefs;

Future<void> initLocalStorage() async {
  _prefs = await SharedPreferences.getInstance();
}

const _kFavPickups = 'fav_pickups';
const _kFavEvents = 'fav_events';
const _kReminders = 'reminders';
const _kPredictions = 'predictions';
const _kPinnedConvs = 'pinned_convs';
const _kCity = 'city';
const _kRecentCities = 'recent_cities';
const _kLocale = 'locale';
const _kNotifPush = 'notif_push';
const _kNotifInApp = 'notif_in_app';
const _kNotifEmail = 'notif_email';
const _kNotifMatchReminder = 'notif_match_reminder';
const _kSearchHistory = 'search_history';
const _kFeedback = 'feedback';
const _kMyTeams = 'my_teams';
const _kDraftEvent = 'draft_event';
const _kRememberMe = 'remember_me';
const _kRememberedEmail = 'remembered_email';
const _kMutedConvs = 'muted_convs';
const _kThemeMode = 'theme_mode';
const _kThemeSeed = 'theme_seed';
const _kDanmakuEnabled = 'danmaku_enabled';

class LocalStoreNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}

final localStoreNotifier = LocalStoreNotifier();

class LocalStore {
  LocalStore._();

  // ─── favorites: pickups
  static Set<String> get favoritePickups =>
      _prefs.getStringList(_kFavPickups)?.toSet() ?? <String>{};
  static bool isPickupFavorited(String id) => favoritePickups.contains(id);
  static Future<void> toggleFavoritePickup(String id) async {
    final s = favoritePickups;
    s.contains(id) ? s.remove(id) : s.add(id);
    await _prefs.setStringList(_kFavPickups, s.toList());
    localStoreNotifier.bump();
  }

  // ─── favorites: events
  static Set<String> get favoriteEvents =>
      _prefs.getStringList(_kFavEvents)?.toSet() ?? <String>{};
  static bool isEventFavorited(String id) => favoriteEvents.contains(id);
  static Future<void> toggleFavoriteEvent(String id) async {
    final s = favoriteEvents;
    s.contains(id) ? s.remove(id) : s.add(id);
    await _prefs.setStringList(_kFavEvents, s.toList());
    localStoreNotifier.bump();
  }

  // ─── reminders for matches
  static Set<String> get reminders =>
      _prefs.getStringList(_kReminders)?.toSet() ?? <String>{};
  static bool hasReminder(String matchId) => reminders.contains(matchId);
  static Future<void> toggleReminder(String matchId) async {
    final s = reminders;
    s.contains(matchId) ? s.remove(matchId) : s.add(matchId);
    await _prefs.setStringList(_kReminders, s.toList());
    localStoreNotifier.bump();
  }

  // ─── predictions: matchId → 'A' / 'draw' / 'B' + optional amount
  static Map<String, String> get predictions {
    final raw = _prefs.getString(_kPredictions);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  static String? getPrediction(String matchId) => predictions[matchId];

  static Future<void> setPrediction(
    String matchId,
    String choice, {
    int? stake,
  }) async {
    final m = predictions;
    m[matchId] = stake != null ? '$choice:$stake' : choice;
    await _prefs.setString(_kPredictions, jsonEncode(m));
    localStoreNotifier.bump();
  }

  // ─── pinned / muted conversations
  static Set<String> get pinnedConversations =>
      _prefs.getStringList(_kPinnedConvs)?.toSet() ?? <String>{};
  static bool isPinned(String convId) => pinnedConversations.contains(convId);
  static Future<void> togglePinned(String convId) async {
    final s = pinnedConversations;
    s.contains(convId) ? s.remove(convId) : s.add(convId);
    await _prefs.setStringList(_kPinnedConvs, s.toList());
    localStoreNotifier.bump();
  }

  static Set<String> get mutedConversations =>
      _prefs.getStringList(_kMutedConvs)?.toSet() ?? <String>{};
  static bool isMuted(String convId) => mutedConversations.contains(convId);
  static Future<void> toggleMuted(String convId) async {
    final s = mutedConversations;
    s.contains(convId) ? s.remove(convId) : s.add(convId);
    await _prefs.setStringList(_kMutedConvs, s.toList());
    localStoreNotifier.bump();
  }

  // ─── city (stored as "省/市/区" path, e.g. "广西壮族自治区/南宁市/青秀区")
  static String get cityPath => _prefs.getString(_kCity) ?? '广西壮族自治区/南宁市';
  static List<String> get cityPathParts => cityPath.split('/');
  static String get city {
    final parts = cityPathParts;
    if (parts.length >= 2) return parts[1];
    return parts.last;
  }

  static Future<void> setCityPath(String path) async {
    await _prefs.setString(_kCity, path);
    await addRecentCity(path);
    localStoreNotifier.bump();
  }

  // keep old API working
  static Future<void> setCity(String city) async {
    await _prefs.setString(_kCity, city);
    localStoreNotifier.bump();
  }

  // ─── recent cities (stores full paths)
  static List<String> get recentCities =>
      _prefs.getStringList(_kRecentCities) ?? <String>[];

  static Future<void> addRecentCity(String path) async {
    final list = recentCities;
    list.remove(path);
    list.insert(0, path);
    while (list.length > 5) {
      list.removeLast();
    }
    await _prefs.setStringList(_kRecentCities, list);
    localStoreNotifier.bump();
  }

  // ─── locale
  static String? get localeCode => _prefs.getString(_kLocale);
  static Future<void> setLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
    localStoreNotifier.bump();
  }

  // ─── notifications
  static bool get notifPush => _prefs.getBool(_kNotifPush) ?? true;
  static Future<void> setNotifPush(bool v) async {
    await _prefs.setBool(_kNotifPush, v);
    localStoreNotifier.bump();
  }

  static bool get notifInApp => _prefs.getBool(_kNotifInApp) ?? true;
  static Future<void> setNotifInApp(bool v) async {
    await _prefs.setBool(_kNotifInApp, v);
    localStoreNotifier.bump();
  }

  static bool get notifEmail => _prefs.getBool(_kNotifEmail) ?? false;
  static Future<void> setNotifEmail(bool v) async {
    await _prefs.setBool(_kNotifEmail, v);
    localStoreNotifier.bump();
  }

  static bool get notifMatchReminder =>
      _prefs.getBool(_kNotifMatchReminder) ?? true;
  static Future<void> setNotifMatchReminder(bool v) async {
    await _prefs.setBool(_kNotifMatchReminder, v);
    localStoreNotifier.bump();
  }

  // ─── live danmaku overlay
  static bool get danmakuEnabled => _prefs.getBool(_kDanmakuEnabled) ?? true;
  static Future<void> setDanmakuEnabled(bool v) async {
    await _prefs.setBool(_kDanmakuEnabled, v);
    localStoreNotifier.bump();
  }

  // ─── search history (last 10)
  static List<String> get searchHistory =>
      _prefs.getStringList(_kSearchHistory) ?? <String>[];

  static Future<void> pushSearch(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    final list = searchHistory;
    list.remove(q);
    list.insert(0, q);
    while (list.length > 10) {
      list.removeLast();
    }
    await _prefs.setStringList(_kSearchHistory, list);
    localStoreNotifier.bump();
  }

  static Future<void> clearSearchHistory() async {
    await _prefs.remove(_kSearchHistory);
    localStoreNotifier.bump();
  }

  // ─── feedback history
  static List<String> get feedbackHistory =>
      _prefs.getStringList(_kFeedback) ?? <String>[];
  static Future<void> pushFeedback(String s) async {
    s = s.trim();
    if (s.isEmpty) return;
    final list = feedbackHistory
      ..insert(0, '${DateTime.now().toIso8601String()}|$s');
    while (list.length > 30) {
      list.removeLast();
    }
    await _prefs.setStringList(_kFeedback, list);
    localStoreNotifier.bump();
  }

  // ─── my teams
  static List<Map<String, dynamic>> get myTeams {
    final raw = _prefs.getString(_kMyTeams);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addTeam(Map<String, dynamic> team) async {
    final list = myTeams..insert(0, team);
    await _prefs.setString(_kMyTeams, jsonEncode(list));
    localStoreNotifier.bump();
  }

  static Future<void> removeTeam(String id) async {
    final list = myTeams..removeWhere((t) => t['id'] == id);
    await _prefs.setString(_kMyTeams, jsonEncode(list));
    localStoreNotifier.bump();
  }

  // ─── event draft
  static Map<String, dynamic>? get draftEvent {
    final raw = _prefs.getString(_kDraftEvent);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDraftEvent(Map<String, dynamic> data) async {
    await _prefs.setString(_kDraftEvent, jsonEncode(data));
    localStoreNotifier.bump();
  }

  static Future<void> clearDraftEvent() async {
    await _prefs.remove(_kDraftEvent);
    localStoreNotifier.bump();
  }

  // ─── remember me
  static bool get rememberMe => _prefs.getBool(_kRememberMe) ?? false;
  static String? get rememberedEmail => _prefs.getString(_kRememberedEmail);
  static Future<void> setRemember(bool v, String? email) async {
    await _prefs.setBool(_kRememberMe, v);
    if (v && email != null) {
      await _prefs.setString(_kRememberedEmail, email);
    } else {
      await _prefs.remove(_kRememberedEmail);
    }
    localStoreNotifier.bump();
  }

  static Future<void> clearAll() async {
    await _prefs.clear();
    localStoreNotifier.bump();
  }

  // ─── theme
  static ThemeMode get themeMode {
    final raw = _prefs.getString(_kThemeMode) ?? 'system';
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    final raw = switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeMode, raw);
    localStoreNotifier.bump();
  }

  static AccentSeed get themeSeed =>
      AccentSeed.parse(_prefs.getString(_kThemeSeed));

  static Future<void> setThemeSeed(AccentSeed s) async {
    await _prefs.setString(_kThemeSeed, s.serialize());
    localStoreNotifier.bump();
  }
}
