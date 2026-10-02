/// Supabase project configuration for the Remedoo web app.
///
/// These values come from the user's own Supabase project (see
/// remedoo-react-ref/.env). The publishable (anon) key is public by design
/// for client-side apps - all data access is protected by Row Level Security
/// on the Supabase project. Never commit service-role keys here.
abstract final class SupabaseConfig {
  /// Project URL, e.g. https://xyzcompany.supabase.co
  static const String url = 'https://suicqpfijnsortcszqep.supabase.co';

  /// Publishable/anon key (safe to ship in the client bundle).
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1aWNxcGZpam5zb3J0Y3N6cWVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyMDc4MjQsImV4cCI6MjA4Nzc4MzgyNH0.teNIccPIhtIoPmAHd9OtNHi0XyPOXsJcoiHygjuA1RQ';
}
