import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Panels check (owner order 2026-10-23): hospital, lab and
/// pharmacy panels moved from one long scroll (profile form on
/// top, work at the bottom) to the doctor panel's tab layout —
/// work first, then profile, payments, reviews. Nothing that was
/// on the scroll page may be lost in the move. The driver panel
/// gained the Profile tab every other panel already had.
void main() {
  String read(String p) => File(p).readAsStringSync();

  const sharedWidgets = [
    'ProviderProfileForm',
    'ProviderUpiSettingsCard',
    'ProviderOnlinePayments',
    'ProviderWalletCard',
    'ProviderReviewsList',
    'RouteOnboardingTile',
  ];

  test('hospital panel is tabbed and loses nothing', () {
    final s = read('lib/screens/partner/hospital_dashboard.dart');
    expect(s.contains('BottomNavigationBar'), isTrue);
    expect(s.contains("label: 'Appointments'"), isTrue);
    expect(s.contains("label: 'Profile'"), isTrue);
    expect(s.contains("label: 'Payments'"), isTrue);
    expect(s.contains("label: 'Reviews'"), isTrue);
    expect(s.contains('NavMemory.hospitalTab'), isTrue);
    for (final w in [...sharedWidgets, 'HospitalUnitsManager']) {
      expect(s.contains(w), isTrue, reason: w);
    }
  });

  test('lab panel is tabbed with My Tests and loses nothing', () {
    final s = read('lib/screens/partner/lab_dashboard.dart');
    expect(s.contains("label: 'Bookings'"), isTrue);
    expect(s.contains("label: 'My Tests'"), isTrue);
    expect(s.contains('NavMemory.labTab'), isTrue);
    for (final w in [
      ...sharedWidgets,
      'LabCatalogueManager',
      'LabSamplesManager',
    ]) {
      expect(s.contains(w), isTrue, reason: w);
    }
  });

  test('pharmacy panel is tabbed with Medicines and loses nothing', () {
    final s = read('lib/screens/partner/pharmacy_dashboard.dart');
    expect(s.contains("label: 'Orders'"), isTrue);
    expect(s.contains("label: 'Medicines'"), isTrue);
    expect(s.contains('NavMemory.pharmacyTab'), isTrue);
    for (final w in [...sharedWidgets, 'PharmacyMedicinesManager']) {
      expect(s.contains(w), isTrue, reason: w);
    }
  });

  test('driver panel has a Profile tab', () {
    final s = read('lib/screens/driver_dashboard_screen.dart');
    expect(s.contains('TabController(length: 4'), isTrue);
    expect(s.contains("Tab(text: 'Profile')"), isTrue);
    expect(s.contains('_profileTab()'), isTrue);
  });

  test('nav memory knows every panel tab key', () {
    final s = read('lib/utils/nav_memory.dart');
    expect(s.contains("hospitalTab = 'nav_hospital_tab'"), isTrue);
    expect(s.contains("labTab = 'nav_lab_tab'"), isTrue);
    expect(s.contains("pharmacyTab = 'nav_pharmacy_tab'"), isTrue);
  });
}
