import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Add support user (owner order 2026-10-23): the Support section
/// had no way to add a support person. The create-staff dialog is
/// now shared, and Support Tickets shows an "Add support user"
/// button (super admin only) that creates a staff account locked
/// to the Support section via the same admin-staff server path.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('create-staff dialog is shared and supports locked presets', () {
    final s = read('lib/screens/admin/admin_team_screen.dart');
    expect(s.contains('class CreateStaffDialog extends StatefulWidget'),
        isTrue);
    expect(s.contains('presetSections'), isTrue);
    expect(s.contains('lockSections'), isTrue);
    // Team screen still uses the shared dialog with defaults.
    expect(s.contains('const CreateStaffDialog()'), isTrue);
  });

  test('support tickets screen offers Add support user', () {
    final s = read('lib/screens/admin/admin_support_tickets_screen.dart');
    expect(s.contains('Add support user'), isTrue);
    expect(s.contains("presetSections: {'support'}"), isTrue);
    expect(s.contains('lockSections: true'), isTrue);
    expect(s.contains('state.isAdmin'), isTrue);
    expect(s.contains("'action': 'create'"), isTrue);
  });
}
