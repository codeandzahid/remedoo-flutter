import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/utils/staff_access.dart';

/// Detailed staff access levels (owner order 2026-10-23): every
/// option in the Team picker gets No access / View only / Full
/// access, stored in staff_permissions.sections as base keys plus
/// 'view:' markers so the live RLS read checks keep working.
void main() {
  test('encode: full is a bare key, view adds a marker', () {
    final out = staffSectionsEncode({
      'doctors': 'full',
      'coupons': 'view',
      'orders': 'none',
    });
    expect(out, containsAll(<String>['doctors', 'coupons', 'view:coupons']));
    expect(out, isNot(contains('orders')));
    expect(out.length, 3);
  });

  test('decode round-trips levels', () {
    final stored = staffSectionsEncode({
      'doctors': 'full',
      'coupons': 'view',
    });
    final back = staffLevelsDecode(stored);
    expect(back['doctors'], 'full');
    expect(back['coupons'], 'view');
  });

  test('decode: plain old-style sections are all full access', () {
    final back = staffLevelsDecode(['doctors', 'support']);
    expect(back, {'doctors': 'full', 'support': 'full'});
    expect(staffViewOnlyKeys(['doctors', 'support']), isEmpty);
  });

  test('view-only keys and accessible keys split correctly', () {
    final stored = ['doctors', 'coupons', 'view:coupons'];
    expect(staffViewOnlyKeys(stored), {'coupons'});
    expect(staffAccessibleKeys(stored), {'doctors', 'coupons'});
  });

  test('picker is grouped with per-option levels in the team screen', () {
    final s = File('lib/screens/admin/admin_team_screen.dart')
        .readAsStringSync();
    expect(s.contains('kStaffSectionGroups'), isTrue);
    expect(s.contains("'View only'"), isFalse); // chip label is 'View'
    expect(s.contains("_levelButton(o.\$1, 'View', 'view')"), isTrue);
    expect(s.contains("_levelButton(o.\$1, 'Full', 'full')"), isTrue);
    expect(s.contains('All full access'), isTrue);
  });

  test('groups cover exactly the flat option list', () {
    final s = File('lib/screens/admin/admin_team_screen.dart')
        .readAsStringSync();
    final flatStart = s.indexOf('const kStaffSectionOptions');
    final flatEnd = s.indexOf('];', flatStart);
    final flatKeys = RegExp(r"\('([a-z_]+)',")
        .allMatches(s.substring(flatStart, flatEnd))
        .map((m) => m.group(1)!)
        .toSet();
    final groupStart = s.indexOf('const kStaffSectionGroups');
    final groupEnd = s.indexOf('];', groupStart);
    final groupKeys = RegExp(r"\('([a-z_]+)',")
        .allMatches(s.substring(groupStart, groupEnd))
        .map((m) => m.group(1)!)
        .toSet();
    expect(groupKeys, flatKeys);
  });

  test('shell wires read-only into list screens and shows the banner', () {
    final s = File('lib/screens/admin/admin_shell.dart').readAsStringSync();
    expect(s.contains('staffCanWrite'), isTrue);
    expect(s.contains('View only — you can see this option'), isTrue);
    final crud =
        File('lib/screens/admin/admin_crud_screen.dart').readAsStringSync();
    expect(crud.contains('final bool readOnly;'), isTrue);
    expect(crud.contains('if (!widget.readOnly)'), isTrue);
  });

  test('enforcement migration exists with staff_can_write', () {
    final s = File('supabase/migration/staff_view_only_enforcement.sql')
        .readAsStringSync();
    expect(s.contains('staff_can_write'), isTrue);
    expect(s.contains('"Staff section read"'), isTrue);
  });
}
