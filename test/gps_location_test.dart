// GPS location fill (owner order, 2026-10-23): admin Add/Edit
// forms take latitude/longitude from the device GPS via the
// shared fetchCurrentCoordinates() helper instead of relying on
// typed values. These tests pin the wiring: every provider
// table's field spec carries the lat/lng pair, and both admin
// editors (generic CRUD dialog + Service Areas) show the
// "Use GPS" button with the two feedback messages.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

/// The field-spec block for one table inside adminTableFields():
/// from its `case '<table>':` up to the next case (or EOF).
String _tableBlock(String src, String table) {
  final start = src.indexOf("case '$table':");
  expect(start, greaterThanOrEqualTo(0), reason: 'no case for $table');
  final rest = src.substring(start);
  final next = rest.indexOf("\n    case '", 10);
  return next < 0 ? rest : rest.substring(0, next);
}

void main() {
  group('GPS latitude/longitude fields (provider tables)', () {
    final crud = _src('lib/screens/admin/admin_crud_screen.dart');

    for (final table
        in ['doctors', 'hospitals', 'labs', 'pharmacies']) {
      test('$table spec has latitude + longitude double fields', () {
        final block = _tableBlock(crud, table);
        expect(
            block.contains(
                "key: 'latitude', label: 'Latitude', type: 'double'"),
            isTrue);
        expect(
            block.contains(
                "key: 'longitude', label: 'Longitude', type: 'double'"),
            isTrue);
      });
    }
  });

  group('GPS fill button wiring', () {
    test('CRUD add/edit dialog calls the GPS helper', () {
      final s = _src('lib/screens/admin/admin_crud_screen.dart');
      expect(s.contains("import '../../utils/device_actions.dart';"),
          isTrue);
      expect(s.contains('fetchCurrentCoordinates()'), isTrue);
      expect(
          s.contains('Use GPS (fill Latitude & Longitude)'), isTrue);
      expect(s.contains('Location set from GPS'), isTrue);
      // The message is two adjacent string literals in source.
      expect(s.contains('Could not get GPS location.'), isTrue);
      expect(s.contains('Check location permission.'), isTrue);
      // Values land in both controllers at 6 decimal places.
      expect(s.contains("ctrls['latitude']!.text"), isTrue);
      expect(s.contains("ctrls['longitude']!.text"), isTrue);
      expect(s.contains('toStringAsFixed(6)'), isTrue);
    });

    test('Service Areas editor calls the GPS helper', () {
      final s = _src('lib/screens/admin/admin_config_screens.dart');
      expect(s.contains("import '../../utils/device_actions.dart';"),
          isTrue);
      expect(s.contains('fetchCurrentCoordinates()'), isTrue);
      expect(
          s.contains('Use GPS (fill Latitude & Longitude)'), isTrue);
      expect(s.contains('Location set from GPS'), isTrue);
      // The message is two adjacent string literals in source.
      expect(s.contains('Could not get GPS location.'), isTrue);
      expect(s.contains('Check location permission.'), isTrue);
      // The existing lat/lng controllers are the ones filled.
      expect(s.contains('lat.text'), isTrue);
      expect(s.contains('lng.text'), isTrue);
      expect(s.contains('toStringAsFixed(6)'), isTrue);
    });
  });
}
