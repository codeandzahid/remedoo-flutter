import 'package:web/web.dart' as web;

/// Removes auth-callback parameters (PKCE code / implicit tokens) from
/// the address bar after they have been exchanged for a session, so
/// they don't linger in the URL, get copied into bookmarks, or get
/// re-processed on a reload. Mirrors what supabase_flutter does
/// internally after its own (disabled here) deeplink handling.
void clearAuthUrlParameters() {
  final location = web.window.location;
  web.window.history
      .replaceState(null, '', location.origin + location.pathname);
}
