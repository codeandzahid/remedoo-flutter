import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Form-pages audit Batch 6 — registration & provider profiles:
/// M5 (real document uploads), Panelist 18 (rich registration +
/// approval mapping), Panelist 10 (hospital/lab/pharmacy profile
/// forms), Panelist 19 (UPI setup dialog completes the record +
/// appears in partner app), Panelist 14 (Route sheet linked,
/// Razorpay untouched), Panelist 20 (partner login links, no
/// diagnostic), Panelist 22 (RLS verified by design; OTP dialog
/// scrollable).
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('M5: registration keeps bytes and uploads them', () {
    final screen = read('lib/screens/provider_register_screen.dart');
    expect(screen.contains('Uint8List? bytes'), isTrue);
    expect(screen.contains('uploadProviderDocument'), isTrue);
    expect(screen.contains("'path': path"), isTrue);
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains("from('certificates').uploadBinary"), isTrue);
    expect(repo.contains('uploadProviderDocument'), isTrue);
    expect(repo.contains('signedStorageUrl'), isTrue);
  });

  test('Panelist 18: registration collects role details', () {
    final screen = read('lib/screens/provider_register_screen.dart');
    expect(screen.contains("'specialization': _specialization"), isTrue);
    expect(screen.contains("'consultation_fee'"), isTrue);
    expect(screen.contains("'icu_available': _icu"), isTrue);
    expect(screen.contains("'services': _services.text"), isTrue);
    expect(screen.contains("'details': details"), isTrue);
  });

  test('Panelist 18: approval maps details; address never into bio',
      () {
    final state = read('lib/state/app_state.dart');
    expect(state.contains("row['bio'] = app['address']"), isFalse);
    expect(state.contains("row['specialization']"), isTrue);
    expect(state.contains("row['consultation_fee'] = fee"), isTrue);
    expect(state.contains("row['total_beds'] = beds"), isTrue);
    expect(state.contains("row['license_url'] = licenseUrl"), isTrue);
    expect(state.contains("row['additional_docs_urls'] = extra"),
        isTrue);
    expect(state.contains('Address: '), isTrue);
  });

  test('details column migration exists + submit degrades', () {
    final sql =
        read('supabase/migration/provider_application_details.sql');
    expect(sql.contains('provider_applications'), isTrue);
    expect(sql.contains('details JSONB'), isTrue);
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains('retrying without'), isTrue);
  });

  test('Panelist 10: shared profile form wired into 3 dashboards',
      () {
    final form = read('lib/widgets/provider_profile_form.dart');
    expect(form.contains('updateOwnProviderRecord(widget.table'),
        isTrue);
    expect(form.contains('WorkingHoursEditor'), isTrue);
    for (final f in [
      'lib/screens/partner/hospital_dashboard.dart',
      'lib/screens/partner/lab_dashboard.dart',
      'lib/screens/partner/pharmacy_dashboard.dart',
    ]) {
      expect(read(f).contains('ProviderProfileForm('), isTrue,
          reason: f);
    }
  });

  test('Panelist 19: UPI dialog writes payee name + enables UPI',
      () {
    final dialog = read('lib/widgets/upi_setup_dialog.dart');
    expect(dialog.contains('payeeName: _upiName.text.trim()'), isTrue);
    expect(dialog.contains('maybePromptUpiSetup'), isTrue);
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains("'upi_enabled': true"), isTrue);
    expect(repo.contains("'upi_payee_name': payeeName"), isTrue);
    for (final f in [
      'lib/screens/partner/doctor_dashboard.dart',
      'lib/screens/partner/hospital_dashboard.dart',
      'lib/screens/partner/lab_dashboard.dart',
      'lib/screens/partner/pharmacy_dashboard.dart',
    ]) {
      expect(read(f).contains('maybePromptUpiSetup(context, _profile)'),
          isTrue,
          reason: f);
    }
  });

  test('Panelist 14: Route tile linked from all partner payments',
      () {
    final payments = read('lib/widgets/provider_payments.dart');
    expect(payments.contains('class RouteOnboardingTile'), isTrue);
    expect(payments.contains('showRouteOnboarding('), isTrue);
    for (final f in [
      'lib/screens/partner/doctor_dashboard.dart',
      'lib/screens/partner/hospital_dashboard.dart',
      'lib/screens/partner/lab_dashboard.dart',
      'lib/screens/partner/pharmacy_dashboard.dart',
    ]) {
      expect(read(f).contains('RouteOnboardingTile('), isTrue,
          reason: f);
    }
    // Ground rule: linking only — the tile must not flip any
    // gateway activation.
    expect(payments.contains('activeGateway'), isFalse);
  });

  test('Panelist 20: partner login has reset + register, no diag',
      () {
    final login =
        read('lib/screens/partner/partner_login_screen.dart');
    expect(login.contains('Test Connection'), isFalse);
    expect(login.contains('_testConnection'), isFalse);
    expect(login.contains('ForgotPasswordScreen'), isTrue);
    expect(login.contains('ProviderTypeScreen'), isTrue);
    expect(login.contains('Forgot password?'), isTrue);
  });

  test('Panelist 22: OTP dialog content scrolls', () {
    final payments = read('lib/widgets/provider_payments.dart');
    final otpStart = payments.indexOf('We sent a 6-digit code');
    final before = payments.substring(0, otpStart);
    expect(before.lastIndexOf('SingleChildScrollView') >
        before.lastIndexOf('content:'), isTrue);
  });

  test('admin approvals show details + document view buttons', () {
    final approvals =
        read('lib/screens/admin/admin_approvals_screen.dart');
    expect(approvals.contains('_detailsSummary'), isTrue);
    expect(approvals.contains('_viewDoc'), isTrue);
    expect(approvals.contains("signedStorageUrl('certificates', path)"),
        isTrue);
  });
}
