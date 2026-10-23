import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Support > Users (owner order 2026-10-23): the Support section
/// gains a Users item — add users, make them active/inactive and
/// change their details — reusing the Admin Users screen with the
/// Add user button on. Creation runs through the admin-staff
/// function's create_user action (role 'user', never staff).
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('support section has a Users item with add-user enabled', () {
    final s = read('lib/screens/admin/admin_shell.dart');
    expect(s.contains("_NavItem('Support', 'Users'"), isTrue);
    expect(s.contains('AdminUsersScreen(allowAddUser: true,'), isTrue);
  });

  test('admin users screen gates the Add user button on the flag', () {
    final s = read('lib/screens/admin/admin_users_screen.dart');
    expect(s.contains('final bool allowAddUser;'), isTrue);
    expect(s.contains('if (widget.allowAddUser && !widget.readOnly)'),
        isTrue);
    expect(s.contains("'action': 'create_user'"), isTrue);
  });

  test('admin-staff function implements create_user as a plain user', () {
    final s = read('supabase/functions/admin-staff/index.ts');
    expect(s.contains("action === 'create_user'"), isTrue);
    expect(s.contains("role: 'user'"), isTrue);
  });

  test('manage actions still come from the shared edit dialog', () {
    final s = read('lib/screens/admin/admin_users_screen.dart');
    // Account status (active/suspended) lives in the edit dialog.
    expect(s.contains('Account status'), isTrue);
  });
}
