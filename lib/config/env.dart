// env.dart — Supabase config
//
// Resolution order:
//   1. --dart-define=SUPABASE_URL / SUPABASE_ANON_KEY (preferred for CI/prod)
//   2. Compile-time defaults below (convenience for local dev)
//
// The `anon` key is designed to be shipped in clients; security comes from
// Row Level Security policies on the database. Still, avoid committing
// production credentials — for a real release, switch to --dart-define
// and remove the defaults.

class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ejtkfaezztkwhmjqnvnb.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqdGtmYWV6enRrd2htanFudm5iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2Nzc2OTgsImV4cCI6MjA5MjI1MzY5OH0.xleOCLO9cp1KBxH3-bfozphZdNYSGTlX5EGrd9Z_Ao0',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
