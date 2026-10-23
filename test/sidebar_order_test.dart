import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sidebar rearrangement (owner order 2026-10-23): plans moved
/// from Settings to Catalog, Payments (UPI) joined Remedoo Pay
/// under Payments, Export Data moved to Insights, Announcements
/// and Broadcasts sit together, a Drivers item was added, and
/// Settings was later split into Settings + Management
/// (delivery_drivers had no admin screen). The permission keys,
/// the Team section catalog and the dashboard's absolute links
/// must all follow the same order.
void main() {
  String read(String path) => File(path).readAsStringSync();

  List<String> permKeys(String shell) {
    final start = shell.indexOf('const _permKeys = [');
    final end = shell.indexOf('];', start);
    final block = shell.substring(start, end);
    return RegExp(r"'([a-z_]+)'")
        .allMatches(block)
        .map((m) => m.group(1)!)
        .toList();
  }

  test('perm keys match the new sidebar order and count', () {
    final keys = permKeys(read('lib/screens/admin/admin_shell.dart'));
    expect(keys.length, 43);
    expect(keys[0], 'dashboard');
    expect(keys[10], 'corporate');
    expect(keys[11], 'packages');
    expect(keys[12], 'subscriptions');
    expect(keys[13], 'applications');
    expect(keys[15], 'drivers');
    expect(keys[16], 'remedoo_pay');
    expect(keys[17], 'provider_payments');
    expect(keys[23], 'support');
    // Support > Users (2026-10-23) also rides the 'support' key.
    expect(keys[25], 'support');
    expect(keys[26], 'announcements');
    expect(keys[27], 'broadcasts');
    expect(keys[32], 'revenue');
    expect(keys[34], 'export_data');
    expect(keys[38], 'platform_settings');
    expect(keys[39], 'panel_style');
    expect(keys[40], 'service_areas');
    expect(keys[41], 'featured');
    expect(keys[42], 'team');
  });

  test('drivers item exists in sidebar, team catalog and CRUD', () {
    final shell = read('lib/screens/admin/admin_shell.dart');
    expect(shell.contains("'Drivers'"), isTrue);
    expect(shell.contains("table: 'delivery_drivers'"), isTrue);
    final team = read('lib/screens/admin/admin_team_screen.dart');
    expect(team.contains("('drivers', 'Drivers')"), isTrue);
    final crud = read('lib/screens/admin/admin_crud_screen.dart');
    expect(crud.contains("case 'delivery_drivers':"), isTrue);
  });

  test('dashboard cards point at the new absolute indexes', () {
    final s = read('lib/screens/admin/admin_dashboard_screen.dart');
    expect(s.contains('onNavigate?.call(13))'), isTrue); // Approvals
    expect(s.contains('onNavigate?.call(19))'), isTrue); // Appointments
    expect(s.contains('onNavigate?.call(18))'), isTrue); // Orders
    expect(s.contains('onNavigate?.call(21))'), isTrue); // Emergencies
    expect(s.contains('onNavigate?.call(23))'), isTrue); // Support
    expect(s.contains('onNavigate?.call(32))'), isTrue); // Revenue
    expect(s.contains("value: 26, child: Text('Send Announcement')"),
        isTrue);
  });

  test('team catalog mirrors the sidebar sections', () {
    final team = read('lib/screens/admin/admin_team_screen.dart');
    final driversAt = team.indexOf("('drivers', 'Drivers')");
    final paymentsAt = team.indexOf("('provider_payments'");
    final remedooPayAt = team.indexOf("('remedoo_pay'");
    expect(driversAt, greaterThan(0));
    // Payments (UPI) sits right after Remedoo Pay in Payments.
    expect(paymentsAt, greaterThan(remedooPayAt));
    // Plans are under Catalog: before Applications.
    expect(team.indexOf("('corporate'"),
        lessThan(team.indexOf("('applications'")));
  });
}
