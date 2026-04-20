// main.dart — entry point
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/env.dart';
import 'services/local_storage.dart';
import 'services/push.dart';
import 'services/supabase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initLocalStorage();

  // Initialize Supabase only if env is configured. This lets the scaffold
  // run without credentials; once you plug them in via --dart-define, it boots fully.
  if (Env.isConfigured) {
    await initSupabase();
  } else {
    // ignore: avoid_print
    print(
      '[kaiqiu] Supabase not configured — running in offline scaffold mode. '
      'Pass --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  // Push wiring (no-op unless FIREBASE_* dart-defines are set).
  await PushService.instance.init();

  runApp(const ProviderScope(child: KaiqiuApp()));
}
