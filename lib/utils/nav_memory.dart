import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which tab/section the user was on for each app
/// surface, so a page refresh (or an app relaunch) returns them
/// to the same screen instead of throwing them back to the
/// dashboard (owner report 2026-10-23). The admin key carries a
/// versioned suffix: the sidebar order changed on 2026-10-23, and the old
/// saved index would have landed on a different section.
///
/// Keys are cleared on logout (AppState.logout) so the next
/// account never inherits the previous one's place.
abstract final class NavMemory {
  static const mainTab = 'nav_main_tab';
  static const adminTab = 'nav_admin_tab_v3';
  static const doctorTab = 'nav_doctor_tab';
  static const driverTab = 'nav_driver_tab';

  static const allKeys = [mainTab, adminTab, doctorTab, driverTab];

  static Future<int?> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String key, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, index);
    } catch (_) {
      // Remembering the place is best-effort; navigation must
      // never fail because storage did.
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in allKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
