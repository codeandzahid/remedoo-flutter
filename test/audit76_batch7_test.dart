import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';

/// Form-pages audit Batch 7 — provider verticals: lab
/// catalogue/packages/samples (Panelist 2, M11), patient lab
/// catalogue + home collection (Patient 10/11), pharmacy
/// medicines + preparing step (Panelist 3/16), hospital units +
/// ambulance config (Panelist 4), wallet/payouts (Panelist 11,
/// M20), driver wiring (Panelist 9, M19).
void main() {
  String read(String p) => File(p).readAsStringSync();

  test('lab tests carry their lab + clinical flags (Patient 10)',
      () {
    const t = LabTest(
      id: 'x',
      name: 'CBC',
      price: 300,
      labId: 'lab-1',
      requiresFasting: true,
      homeCollection: true,
      homeCollectionFee: 50,
    );
    expect(t.labId, 'lab-1');
    expect(t.homeCollectionFee, 50);
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains("labId: r['lab_id']?.toString()"), isTrue);
    expect(repo.contains("r['home_collection_fee']"), isTrue);
    final detail = read('lib/screens/lab_detail_screen.dart');
    expect(detail.contains('take(12)'), isFalse);
    expect(detail.contains('t.labId == widget.lab.id'), isTrue);
  });

  test('lab catalogue + packages CRUD exist and are wired (M11)',
      () {
    final repo = read('lib/services/supabase_repository.dart');
    for (final m in [
      'fetchOwnLabTests',
      'upsertOwnLabTest',
      'deleteOwnLabTest',
      'fetchOwnLabPackages',
      'upsertOwnLabPackage',
      'deleteOwnLabPackage',
    ]) {
      expect(repo.contains(m), isTrue, reason: m);
    }
    final dash = read('lib/screens/partner/lab_dashboard.dart');
    expect(dash.contains('LabCatalogueManager'), isTrue);
    expect(dash.contains('LabSamplesManager'), isTrue);
  });

  test('sample workflow + report upload (Panelist 2, Patient 11)',
      () {
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains('fetchLabSamples'), isTrue);
    expect(repo.contains('createLabSample'), isTrue);
    expect(repo.contains("from('lab-reports').uploadBinary"), isTrue);
    expect(repo.contains('fetchPatientLabSamples'), isTrue);
    final state = read('lib/state/app_state.dart');
    expect(state.contains('loadPatientLabSamples'), isTrue);
    expect(state.contains('Tests: '), isTrue);
  });

  test('home collection choice flows into the booking (Patient 11)',
      () {
    final booking = read('lib/screens/booking_screen.dart');
    expect(booking.contains("value: 'home'"), isTrue);
    expect(booking.contains('collectionType:'), isTrue);
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains("'collection_type': collectionType"), isTrue);
    expect(repo.contains('retrying without collection'), isTrue);
    final sql =
        read('supabase/migration/appointments_collection_type.sql');
    expect(sql.contains('collection_type'), isTrue);
  });

  test('pharmacy medicines CRUD + preparing step (Panelist 3/16)',
      () {
    final repo = read('lib/services/supabase_repository.dart');
    for (final m in [
      'fetchOwnMedicines',
      'upsertOwnMedicine',
      'deleteOwnMedicine',
      'updateMedicineStock',
    ]) {
      expect(repo.contains(m), isTrue, reason: m);
    }
    final dash = read('lib/screens/partner/pharmacy_dashboard.dart');
    expect(dash.contains('PharmacyMedicinesManager'), isTrue);
    expect(dash.contains("'preparing'"), isTrue);
    expect(dash.contains('Start preparing'), isTrue);
    final sql =
        read('supabase/migration/pharmacy_medicines_policy.sql');
    expect(sql.contains('Pharmacies can manage own medicines'),
        isTrue);
  });

  test('hospital units + ambulance config (Panelist 4)', () {
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains('fetchOwnHospitalUnits'), isTrue);
    expect(repo.contains('upsertHospitalUnit'), isTrue);
    expect(repo.contains('saveAmbulanceConfig'), isTrue);
    final dash = read('lib/screens/partner/hospital_dashboard.dart');
    expect(dash.contains('HospitalUnitsManager'), isTrue);
  });

  test('wallet + payout surface in all four dashboards (M20)', () {
    final repo = read('lib/services/supabase_repository.dart');
    expect(repo.contains('fetchProviderWallet'), isTrue);
    expect(repo.contains('createPayoutRequest'), isTrue);
    for (final f in [
      'lib/screens/partner/doctor_dashboard.dart',
      'lib/screens/partner/hospital_dashboard.dart',
      'lib/screens/partner/lab_dashboard.dart',
      'lib/screens/partner/pharmacy_dashboard.dart',
    ]) {
      expect(read(f).contains('ProviderWalletCard'), isTrue,
          reason: f);
    }
  });

  test('driver is reachable and real (M19)', () {
    final gate = read('lib/main_partner.dart');
    expect(gate.contains("case 'driver'"), isTrue);
    expect(gate.contains('DriverDashboardScreen'), isTrue);
    final login =
        read('lib/screens/partner/partner_login_screen.dart');
    expect(login.contains("'driver'"), isTrue);
    final auth = read('lib/services/auth_service.dart');
    expect(auth.contains("'hospital', 'driver'"), isTrue);
    final screen = read('lib/screens/driver_dashboard_screen.dart');
    expect(screen.contains('fetchDriverDeliveries'), isTrue);
    expect(screen.contains('fetchOwnDriverRecord'), isTrue);
    // The fabricated 10% earnings formula is gone.
    expect(screen.contains('* 0.1'), isFalse);
    expect(screen.contains('state.deliveries'), isFalse);
    final sql = read('supabase/migration/driver_role.sql');
    expect(sql.contains("ADD VALUE 'driver'"), isTrue);
  });
}
