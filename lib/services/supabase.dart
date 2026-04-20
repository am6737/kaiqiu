// supabase.dart — Supabase client singleton + auth helpers
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

/// Global Supabase client. Call [initSupabase] once in main() before use.
SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase() async {
  if (!Env.isConfigured) {
    throw StateError(
      'Supabase not configured. Run with --dart-define=SUPABASE_URL=... '
      '--dart-define=SUPABASE_ANON_KEY=..., or fill lib/config/env.dart.',
    );
  }
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    debug: false,
  );
}

/// Currently-signed-in user's id, or null.
String? get currentUserId => supabase.auth.currentUser?.id;

/// True if a user is signed in.
bool get isSignedIn => supabase.auth.currentUser != null;
