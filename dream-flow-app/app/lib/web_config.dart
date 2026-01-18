// Web-specific configuration
// This file contains hardcoded configuration for web builds
// since --dart-define doesn't work reliably in debug mode for web

class WebConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // Must be provided via environment variable
  );
}