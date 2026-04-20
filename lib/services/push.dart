// push.dart — Firebase Cloud Messaging + push_subscriptions 注册 + deep link.
//
// init() 是幂等的，且在 Firebase 未配置时（`Env.isFirebaseConfigured` 为 false）
// 直接静默跳过。真实生产接入步骤见 docs/setup-push.md。
//
// 调用流程：
//   main.dart → await initSupabase() → await PushService().init();

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/env.dart';
import 'supabase.dart';

/// Singleton to handle platform push wiring.
class PushService {
  PushService._();
  static final PushService instance = PushService._();
  factory PushService() => instance;

  bool _initialised = false;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Background message handler. Must be a top-level or static function,
  /// registered as `pragma('vm:entry-point')` to survive tree-shaking.
  @pragma('vm:entry-point')
  static Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
    // Runs in a separate isolate. Keep this tiny — heavy work belongs in
    // the Edge Function or app-foreground handlers.
    if (kDebugMode) debugPrint('[push:bg] ${message.messageId}');
  }

  /// Navigator callback. Wire this up from `app.dart` so we can route
  /// to the right screen on notification tap.
  void Function(String route)? onOpenRoute;

  Future<void> init() async {
    if (_initialised) return;
    if (!Env.isFirebaseConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[push] Firebase not configured (missing FIREBASE_API_KEY / '
          'FIREBASE_APP_ID) — PushService.init() is a no-op.',
        );
      }
      return;
    }
    if (kIsWeb) {
      // Web push needs a VAPID key and service-worker registration — out of
      // scope for the initial mobile-focused rollout.
      if (kDebugMode) debugPrint('[push] web push skipped');
      return;
    }

    try {
      await Firebase.initializeApp(options: _firebaseOptions());
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _initLocalNotifications();

      final token = await FirebaseMessaging.instance.getToken();
      await _registerToken(token);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

      _initialised = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[push] init failed: $e');
    }
  }

  FirebaseOptions _firebaseOptions() {
    // Replace with FlutterFire-CLI-generated `firebase_options.dart` once
    // you've run `flutterfire configure`. For now this relies on
    // --dart-define values for CI and hand-edits locally.
    return FirebaseOptions(
      apiKey: Env.firebaseApiKey,
      appId: Env.firebaseAppId,
      messagingSenderId: Env.firebaseMessagingSenderId,
      projectId: Env.firebaseProjectId,
    );
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (r) {
        final route = r.payload;
        if (route != null && route.isNotEmpty) {
          onOpenRoute?.call(route);
        }
      },
    );
  }

  Future<void> _registerToken(String? token) async {
    if (token == null || token.isEmpty) return;
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await supabase.from('push_subscriptions').upsert({
        'user_id': uid,
        'token': token,
        'platform': _platformName(),
        'last_seen_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (e) {
      if (kDebugMode) debugPrint('[push] token registration failed: $e');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'web';
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    // App is open — show an in-app local notification so users notice.
    final n = message.notification;
    if (n == null) return;
    final route = message.data['route'] as String?;
    _local.show(
      message.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default',
          '默认通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      onOpenRoute?.call(route);
    }
  }

  /// Show an immediate local notification (used by foreground / test flows).
  /// True scheduling requires `timezone` package init + TZDateTime — that
  /// lives outside this skeleton; the server pg_cron path is the primary
  /// reminder mechanism.
  Future<void> showLocalNow({
    required int id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_initialised) return;
    await _local.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          '比赛提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }
}
