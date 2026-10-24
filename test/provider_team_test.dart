import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/utils/provider_team.dart';

/// Provider teams (owner order 2026-10-24): every panelist can
/// create a team; hospitals, labs and pharmacies can also add
/// drivers. Per-tab access is 'full' | 'view' | 'none'.
void main() {
  test('every panel offers its work tab first', () {
    expect(kProviderPanelTabs['doctor']!.first.$1, 'visits');
    expect(kProviderPanelTabs['hospital']!.first.$1, 'appointments');
    expect(kProviderPanelTabs['lab']!.first.$1, 'bookings');
    expect(kProviderPanelTabs['pharmacy']!.first.$1, 'orders');
  });

  test('only hospital, lab and pharmacy offer drivers', () {
    expect(
        kProviderPanelTabs['doctor']!.map((t) => t.$1), isNot(contains('drivers')));
    for (final type in ['hospital', 'lab', 'pharmacy']) {
      expect(kProviderPanelTabs[type]!.map((t) => t.$1),
          contains('drivers'));
    }
  });

  test('decode keeps known levels and fails closed on the rest', () {
    final access = decodeTeamAccess('pharmacy', {
      'orders': 'full',
      'medicines': 'view',
      'profile': 'bogus',
    });
    expect(access['orders'], 'full');
    expect(access['medicines'], 'view');
    expect(access['profile'], 'none');
    expect(access['reviews'], 'none');
    expect(access['drivers'], 'none');
  });

  test('decode drops tabs that do not belong to the panel', () {
    final access = decodeTeamAccess('doctor', {
      'visits': 'full',
      'medicines': 'full',
    });
    expect(access['visits'], 'full');
    expect(access.keys, isNot(contains('medicines')));
  });

  test('owner access is full on every tab', () {
    final access = fullTeamAccess('lab');
    expect(access.values.every((v) => v == 'full'), isTrue);
    expect(access.keys, containsAll(['bookings', 'my_tests', 'drivers']));
  });

  test('table and type map both ways', () {
    expect(providerTableFor('pharmacy'), 'pharmacies');
    expect(providerTypeForTable('pharmacies'), 'pharmacy');
    expect(providerTableFor('doctor'), 'doctors');
    expect(providerTypeForTable('labs'), 'lab');
  });

  test('access labels read plainly', () {
    expect(teamAccessLabel('full'), 'Full access');
    expect(teamAccessLabel('view'), 'View only');
    expect(teamAccessLabel('none'), 'No access');
    expect(teamAccessLevel({'orders': 'view'}, 'orders'), 'view');
    expect(teamAccessLevel({'orders': 'view'}, 'payments'), 'none');
  });
}
