/// Supabase project configuration for the Remedoo web app.
///
/// These values come from the user's own Supabase project ("remedoo",
/// created 2026-10-03 under the user's own Supabase account). The publishable
/// (anon) key is public by design for client-side apps - all data access is
/// protected by Row Level Security on the Supabase project. Never commit
/// service-role keys here.
abstract final class SupabaseConfig {
  /// Project URL, e.g. https://xyzcompany.supabase.co
  static const String url = 'https://zjlznbgcfzpcveqyjglf.supabase.co';

  /// Publishable/anon key (safe to ship in the client bundle).
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpqbHpuYmdjZnpwY3ZlcXlqZ2xmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwMjQ2MTQsImV4cCI6MjEwNjYwMDYxNH0.5OWjHug1QlWngoyv-OzhAJjxlu8WBtl7jZPQQdb8RFM';
}
