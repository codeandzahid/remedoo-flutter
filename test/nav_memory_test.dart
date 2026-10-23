import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Refresh restore (owner order 2026-10-23): a page refresh used
/// to restart the app on the dashboard. Every shell now remembers
/// its tab/section in NavMemory and restores it on start; logout
/// forgets it. These are source assertions, matching the repo's
/// other audit test files.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('NavMemory helper stores per-surface tab keys', () {
    final s = read('lib/utils/nav_memory.dart');
    expect(s.contains("static const mainTab = 'nav_main_tab'"), isTrue);
    expect(s.contains("static const adminTab = 'nav_admin_tab'"), isTrue);
    expect(s.contains("static const doctorTab = 'nav_doctor_tab'"), isTrue);
    expect(s.contains("static const driverTab = 'nav_driver_tab'"), isTrue);
    expect(s.contains('clearAll'), isTrue);
  });

  test('patient shell saves and restores its tab', () {
    final s = read('lib/screens/main_shell.dart');
    expect(s.contains('NavMemory.save(NavMemory.mainTab'), isTrue);
    expect(s.contains('NavMemory.read(NavMemory.mainTab)'), isTrue);
  });

  test('admin shell saves and restores its section', () {
    final s = read('lib/screens/admin/admin_shell.dart');
    expect(s.contains('NavMemory.save(NavMemory.adminTab'), isTrue);
    expect(s.contains('NavMemory.read(NavMemory.adminTab)'), isTrue);
  });

  test('doctor dashboard saves and restores its tab', () {
    final s = read('lib/screens/partner/doctor_dashboard.dart');
    expect(s.contains('NavMemory.save(NavMemory.doctorTab'), isTrue);
    expect(s.contains('NavMemory.read(NavMemory.doctorTab)'), isTrue);
  });

  test('driver dashboard saves and restores its tab', () {
    final s = read('lib/screens/driver_dashboard_screen.dart');
    expect(s.contains('NavMemory.save(NavMemory.driverTab'), isTrue);
    expect(s.contains('NavMemory.read(NavMemory.driverTab)'), isTrue);
  });

  test('logout forgets the remembered place', () {
    final s = read('lib/state/app_state.dart');
    expect(s.contains('NavMemory.clearAll()'), isTrue);
  });
}
