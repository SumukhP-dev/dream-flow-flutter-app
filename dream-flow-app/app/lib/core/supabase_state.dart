/// Tracks whether Supabase has been initialized for this app run.
///
/// `supabase_flutter` throws/asserts if you call `Supabase.instance` before
/// `Supabase.initialize(...)`. This flag lets the app gracefully run in modes
/// where Supabase is optional (e.g. local backend / web without Supabase).
class SupabaseState {
  static bool isInitialized = false;
}

