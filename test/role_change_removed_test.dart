import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Role change removal (owner order 2026-10-23): the Admin Users
/// list used to let the admin change any user's role (patient →
/// doctor etc.) from a dialog on the role badge. The owner
/// ordered it removed. The role now shows as a plain label; roles
/// are set at account creation / provider approval only.
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('admin users screen has no role-change control', () {
    final s = read('lib/screens/admin/admin_users_screen.dart');
    expect(s.contains('_showRoleDialog'), isFalse);
    expect(s.contains('_changeRole'), isFalse);
    expect(s.contains('Role for '), isFalse);
    expect(s.contains('setUserRole'), isFalse);
    expect(s.contains('Only the super admin can change roles'), isFalse);
  });

  test('role still shows as a plain label on the row', () {
    final s = read('lib/screens/admin/admin_users_screen.dart');
    expect(s.contains(r"'${u['role'] ?? 'user'}'"), isTrue);
  });

  test('approval role grant still exists in the repository', () {
    final s = read('lib/services/supabase_repository.dart');
    expect(s.contains('grantUserRole'), isTrue);
  });
}
