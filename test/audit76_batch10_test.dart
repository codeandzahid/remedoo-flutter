// Audit-76 Batch 10 tests: template consistency remainder
// (M28 / Patient gap 23) — patient forms on the shared
// RTextField, scrolling dialog bodies, panelist structured
// inputs as dropdowns — plus the final verification items
// (hospital fee at all entry points, doctor View Prescription,
// Remedoo Pay editors merge-safety).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('Patient forms use the shared field style (Patient 23)', () {
    test('RTextField supports inline errors now', () {
      final w = _src('lib/widgets/widgets.dart');
      expect(w.contains('final String? errorText;'), isTrue);
      expect(w.contains('errorText: errorText'), isTrue);
    });

    test('vitals add + edit use the shared field; dialog scrolls',
        () {
      final s = _src('lib/screens/vitals_screen.dart');
      expect(s.contains(' TextField('), isFalse);
      expect(s.contains('SingleChildScrollView'), isTrue);
    });

    test('lab report upload dialog uses the shared field', () {
      final s = _src('lib/screens/lab_reports_screen.dart');
      expect(s.contains("label: 'Report name'"), isTrue);
      // The only raw TextField left is the dark header search.
      expect(s.contains("hintText: 'Search tests or labs…'"), isTrue);
    });

    test('medical history + address dialogs use the shared field', () {
      final h = _src('lib/screens/medical_history_screen.dart');
      expect(h.contains(' TextField('), isFalse);
      // UI redesign: the address dialog grew House/Street, City and
      // PIN fields (composed into the same stored text) — the old
      // single 'Full address' field pin moved with it.
      final p = _src('lib/screens/profile_screen.dart');
      expect(p.contains("label: 'House / Street'"), isTrue);
      expect(p.contains("label: 'PIN code'"), isTrue);
      expect(p.contains('RLabelChips'), isTrue);
    });

    test('support ticket form fields use the kit field with errors',
        () {
      final s = _src('lib/screens/new_query_sheet.dart');
      // UI redesign: RTextField was superseded by the kit field.
      expect(s.contains('RKitField('), isTrue);
      expect(s.contains('errorText: _subjectError'), isTrue);
      expect(s.contains('errorText: _messageError'), isTrue);
    });
  });

  group('Panelist structured inputs are dropdowns (M28)', () {
    test('pharmacy medicine category + unit are dropdowns', () {
      final s = _src('lib/widgets/pharmacy_medicines_manager.dart');
      // UI redesign: the dropdowns wear the shared kit widget now
      // (stacked label) — same options, same local state.
      expect(s.contains("label: 'Category'"), isTrue);
      expect(s.contains('RKitDropdown<String>'), isTrue);
      expect(s.contains("'strip', 'bottle', 'tablet'"), isTrue);
      expect(s.contains('controller: category'), isFalse);
      expect(s.contains('controller: unit'), isFalse);
    });

    test('lab test category + sample type are dropdowns', () {
      final s = _src('lib/widgets/lab_catalogue_manager.dart');
      expect(s.contains("'Blood', 'Urine', 'Swab', 'Stool', 'Other'"),
          isTrue);
      expect(s.contains('controller: sampleType'), isFalse);
      expect(s.contains('controller: category'), isFalse);
    });
  });

  group('Final verification items', () {
    test('hospital fee comes from the backend at all entry points',
        () {
      expect(_src('lib/screens/hospital_detail_screen.dart')
          .contains('fee: h.fee'), isTrue);
      expect(_src('lib/screens/emergency_screen.dart')
          .contains('fee: h.fee'), isTrue);
    });

    test('doctor View Prescription opens the file (Panelist 8)', () {
      final s = _src('lib/screens/partner/doctor_dashboard.dart');
      expect(s.contains("label: 'View Prescription'"), isTrue);
      expect(s.contains('launchUrl'), isTrue);
    });

    test('Remedoo Pay editors both preserve the merged config '
        '(Admin gap 18)', () {
      final pay = _src('lib/screens/admin/admin_remedoo_pay_screen.dart');
      // Full-check 2026-10-22: _save no longer merges over the
      // load-time _fullConfig snapshot (it silently reverted App
      // Settings changes made in between); it re-reads the fresh
      // config and merges over that instead.
      expect(pay.contains("state.appConfigValue('payment_gateways')"),
          isTrue);
      expect(pay.contains('await state.loadAppConfig()'), isTrue);
      final settings =
          _src('lib/screens/admin/admin_app_settings_screen.dart');
      expect(settings.contains('..addAll(patch)'), isTrue);
    });
  });
}
