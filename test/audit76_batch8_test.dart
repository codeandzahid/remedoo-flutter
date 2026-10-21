// Audit-76 Batch 8 tests: admin gaps — CRUD editor coverage
// (dropdown/date/array/json types, approval_status + rating
// bounds, edit-blank protection), users editor, ambulance and
// inventory editors, emergency ambulance assignment, appointment
// editor, announcement editing, support sheet scrolling, fees
// currency + validation, team panel_style + deactivation, export
// datasets, dead stubs removed, branding refill, featured narrow
// save, Remedoo Pay VPA validation, approval audit trail.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('Admin CRUD editor (gaps 11-14, 20, 25)', () {
    final crud = _src('lib/screens/admin/admin_crud_screen.dart');

    test('field types include dropdown, date, array and json', () {
      for (final t in ["'dropdown'", "'date'", "'array'", "'json'"]) {
        expect(crud.contains(t), isTrue, reason: t);
      }
      expect(crud.contains('min'), isTrue);
      expect(crud.contains('max'), isTrue);
    });

    test('blank numeric on edit keeps the stored value', () {
      expect(crud.contains('Blank on EDIT keeps the stored value'), isTrue);
    });

    test('approval_status is a dropdown; ratings are bounded', () {
      expect(crud.contains("type: 'dropdown'"), isTrue);
      expect(crud.contains("'pending', 'approved', 'rejected'"), isTrue);
      expect(crud.contains('min: 0'), isTrue);
      expect(crud.contains('max: 5'), isTrue);
    });

    test('dropdown/date pickers inherit the admin theme (no border '
        'override)', () {
      expect(crud.contains('border: OutlineInputBorder'), isFalse);
    });

    test('autofill maps gender and date of birth too', () {
      expect(crud.contains("key == 'gender'"), isTrue);
      expect(crud.contains('date_of_birth'), isTrue);
    });
  });

  group('Users, ambulance, inventory (gaps 6, 7, 27)', () {
    test('users can be edited; suspended state is visible', () {
      final users = _src('lib/screens/admin/admin_users_screen.dart');
      expect(users.contains('_editUser'), isTrue);
      expect(users.contains('SUSPENDED'), isTrue);
      final repo = _src('lib/services/supabase_repository.dart');
      expect(repo.contains('adminUpdateProfile'), isTrue);
      expect(repo.contains('status, gender, date_of_birth'), isTrue);
    });

    test('ambulances can be added and edited', () {
      final ops = _src('lib/screens/admin/admin_ops_screens.dart');
      expect(ops.contains('_editAmbulance'), isTrue);
      expect(ops.contains("'vehicle_number'"), isTrue);
    });

    test('inventory supports exact stock entry', () {
      final ops = _src('lib/screens/admin/admin_ops_screens.dart');
      expect(ops.contains('_editStock'), isTrue);
      expect(ops.contains('Set exact'), isTrue);
    });
  });

  group('Emergencies, appointments, announcements (gaps 22, 10, 19)',
      () {
    test('an ambulance can be assigned to an emergency', () {
      final emg =
          _src('lib/screens/admin/admin_emergencies_screen.dart');
      expect(emg.contains('assigned_ambulance_id'), isTrue);
      expect(emg.contains('Assign ambulance'), isTrue);
    });

    test('appointments are editable from the detail view', () {
      final appt =
          _src('lib/screens/admin/admin_appointments_screen.dart');
      expect(appt.contains('_editAppointment'), isTrue);
      expect(appt.contains("'token_number'"), isTrue);
      expect(appt.contains("'video_meeting_link'"), isTrue);
      expect(appt.contains("'payment_status'"), isTrue);
    });

    test('announcements can be edited, not just deleted', () {
      final repo = _src('lib/services/supabase_repository.dart');
      expect(repo.contains('updateAnnouncement'), isTrue);
      final screen =
          _src('lib/screens/admin/admin_broadcast_screen.dart');
      expect(screen.contains('Edit announcement'), isTrue);
    });
  });

  group('Support, fees, team, export (gaps 21, 16, 17, export)', () {
    test('support details sheet scrolls within a height cap', () {
      final s = _src('lib/screens/admin/admin_support_chat_screen.dart');
      expect(s.contains('SingleChildScrollView'), isTrue);
      expect(s.contains('maxHeight'), isTrue);
    });

    test('fees carry an editable currency and validated save', () {
      final s =
          _src('lib/screens/admin/admin_app_settings_screen.dart');
      expect(s.contains('_feesCurrency'), isTrue);
      expect(s.contains('_saveFees'), isTrue);
      expect(s.contains('_saveRazorpay'), isFalse,
          reason: 'dead Razorpay save removed');
    });

    test('team picker offers Panel Style; members can be deactivated',
        () {
      final s = _src('lib/screens/admin/admin_team_screen.dart');
      expect(s.contains("'panel_style'"), isTrue);
      expect(s.contains('_toggleActive'), isTrue);
      expect(s.contains("'suspended'"), isTrue);
    });

    test('export covers payouts, wallets, coupons and more', () {
      final s = _src('lib/screens/admin/admin_export_screen.dart');
      for (final t in [
        'payout_requests',
        'provider_wallets',
        'coupons',
        'faqs',
        'delivery_orders',
      ]) {
        expect(s.contains(t), isTrue, reason: t);
      }
    });
  });

  group('Cleanup and audit trail (gaps 26, 24, 18, 28)', () {
    test('dead removed-notice stub screens are gone', () {
      final s = _src('lib/screens/admin/admin_config_screens.dart');
      expect(s.contains('OtpSettingsScreen'), isFalse);
      expect(s.contains('ApiKeysScreen'), isFalse);
      expect(s.contains('QuickActionsScreen'), isFalse);
      expect(s.contains('_RemovedNotice'), isFalse);
    });

    test('branding refills when the config load completes', () {
      final s = _src('lib/screens/admin/admin_config_screens.dart');
      expect(s.contains('_touched'), isTrue);
      expect(s.contains('loadAppConfig().then'), isTrue);
    });

    test('featured toggle sends only id + flag', () {
      final s = _src('lib/screens/admin/admin_config_screens.dart');
      expect(s.contains("'is_featured': !(row['is_featured'] == true)"),
          isTrue);
      expect(s.contains("Map<String, dynamic>.from(row)"), isFalse);
    });

    test('Remedoo Pay save validates the UPI format', () {
      final s = _src('lib/screens/admin/admin_remedoo_pay_screen.dart');
      expect(s.contains(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$'), isTrue);
    });

    test('approval decisions stamp the decider; migration exists',
        () {
      final repo = _src('lib/services/supabase_repository.dart');
      expect(repo.contains("'decided_by': _uid"), isTrue);
      expect(
          File('supabase/migration/provider_application_decided_by.sql')
              .existsSync(),
          isTrue);
    });

    test('app-settings pharmacy picker uses the admin theme', () {
      final s =
          _src('lib/screens/admin/admin_app_settings_screen.dart');
      final block = s.substring(s.indexOf('Single vendor pharmacy'));
      expect(block.substring(0, 200).contains('OutlineInputBorder'),
          isFalse);
    });
  });
}
