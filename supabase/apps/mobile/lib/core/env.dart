/// Compile-time configuration. Pass with --dart-define-from-file=env.json
/// (keys SUPABASE_URL and SUPABASE_ANON_KEY). Both are client-safe: use the publishable/anon key only,
/// never a service-role key.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
