import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/screens/care_match_screen.dart';
import 'package:remedoo_app/state/app_state.dart';

/// Form-pages audit Batch 4 — patient extras: family record
/// (Patient 9 + 26), reminders backend (14), Care Match notes (16),
/// Emergency SOS (17), hospital fee (19), profile extras (20),
/// delete pointer (21), field labels (22), history dates (24),
/// checkout unification (25).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('family record (Patient 9)', () {
    test('ageFromDob respects the birthday boundary', () {
      final dob = DateTime(2000, 6, 15);
      expect(FamilyMember.ageFromDob(dob, DateTime(2026, 6, 14)), 25);
      expect(FamilyMember.ageFromDob(dob, DateTime(2026, 6, 15)), 26);
      expect(FamilyMember.ageFromDob(dob, DateTime(2026, 1, 1)), 25);
    });

    test('payload writes every backend column', () {
      final p = AppState.familyPayload(
        name: 'Amina',
        relation: 'Mother',
        dateOfBirth: DateTime(1970, 3, 4),
        gender: 'Female',
        bloodGroup: 'O+',
        allergies: 'Penicillin',
        chronicConditions: 'Diabetes',
      );
      expect(p['name'], 'Amina');
      expect(p['relationship'], 'Mother');
      expect(p['date_of_birth'], '1970-03-04');
      expect(p['gender'], 'Female');
      expect(p['blood_group'], 'O+');
      expect(p['allergies'], 'Penicillin');
      expect(p['chronic_conditions'], 'Diabetes');
    });

    test('payload cleans empty optionals to null', () {
      final p = AppState.familyPayload(
        name: 'X',
        relation: 'Self',
        gender: '  ',
        allergies: '',
      );
      expect(p['gender'], isNull);
      expect(p['allergies'], isNull);
      expect(p.containsKey('date_of_birth'), isFalse);
    });

    test('addFamilyMember derives age from the date of birth', () {
      final s = AppState();
      final dob = DateTime.now().subtract(const Duration(days: 365 * 10 + 3));
      s.addFamilyMember(
        name: 'Kid',
        relation: 'Son',
        age: 99, // must be ignored in favour of the DOB
        dateOfBirth: dob,
        bloodGroup: 'A+',
      );
      expect(s.family.single.age, 10);
      expect(s.family.single.bloodGroup, 'A+');
      expect(s.family.single.dateOfBirth, dob);
    });
  });

  group('reminders vocabulary + time (Patient 14)', () {
    test('recurrence maps both ways', () {
      expect(AppState.reminderDbRecurrence('Daily'), 'daily');
      expect(AppState.reminderDbRecurrence('Weekly'), 'weekly');
      expect(AppState.reminderDbRecurrence('Once'), 'none');
      expect(AppState.reminderUiRepeat('daily'), 'Daily');
      expect(AppState.reminderUiRepeat('weekly'), 'Weekly');
      expect(AppState.reminderUiRepeat('none'), 'Once');
      expect(AppState.reminderUiRepeat(null), 'Daily');
    });

    test('time labels convert to TIME values and back', () {
      expect(AppState.reminderDbTime('9:05 PM'), '21:05:00');
      expect(AppState.reminderDbTime('09:00'), '09:00:00');
      expect(AppState.reminderDbTime('12:00 AM'), '00:00:00');
      expect(AppState.reminderDbTime('12:30 PM'), '12:30:00');
      expect(AppState.reminderDbTime('whenever'), isNull);
      expect(AppState.reminderLabelFromDbTime('21:05:00'), '9:05 PM');
      expect(AppState.reminderLabelFromDbTime('00:00:00'), '12:00 AM');
    });
  });

  group('care match notes (Patient 16)', () {
    test('explicit asks are detected', () {
      expect(careMatchPreferences('cheapest please').cheapest, isTrue);
      expect(careMatchPreferences('nearest to me').nearest, isTrue);
      expect(careMatchPreferences('only the best rated').bestRated, isTrue);
      expect(careMatchPreferences('prefer a female doctor').anySort, isFalse);
      expect(careMatchPreferences('').anySort, isFalse);
    });

    test('notes join the symptom text for specialty relevance', () {
      final specs =
          relevantSpecialtiesForSymptom('feeling unwell skin rash');
      expect(specs, contains('Dermatology'));
    });
  });

  group('profile extras (Patient 20)', () {
    test('language code mapping round-trips', () {
      expect(AppState.languageCodeForName('Hindi'), 'hi');
      expect(AppState.languageNameForCode('hi'), 'Hindi');
      expect(AppState.languageNameForCode('en'), 'English');
      expect(AppState.languageNameForCode(''), 'English');
    });

    test('updateProfile stores DOB, language and UPI locally', () async {
      final s = AppState();
      final dob = DateTime(1990, 5, 6);
      await s.updateProfile(
        dateOfBirth: dob,
        language: 'Urdu',
        upiId: 'patient@okhdfc',
      );
      expect(s.dateOfBirth, dob);
      expect(s.language, 'Urdu');
      expect(s.patientUpiId, 'patient@okhdfc');
    });
  });

  group('source guards (Patients 17, 19, 21, 22, 25)', () {
    test('hospital fee is no longer hardcoded anywhere', () {
      for (final f in [
        'lib/screens/hospital_detail_screen.dart',
        'lib/screens/emergency_screen.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src.contains('fee: 300'), isFalse, reason: f);
        expect(src.contains('inr(300)'), isFalse, reason: f);
      }
    });

    test('emergency screen uses live hospitals and reports SOS', () {
      final src =
          File('lib/screens/emergency_screen.dart').readAsStringSync();
      expect(src.contains('activeHospitals'), isTrue);
      expect(src.contains('reportSos'), isTrue);
      expect(src.contains('fetchCurrentCoordinates'), isTrue);
    });

    test('settings delete pointer names the real location', () {
      final src =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(src.contains('delete your account from Settings'), isFalse);
      expect(src.contains('Danger Zone'), isTrue);
    });

    test('checkout fields carry labels', () {
      final cart = File('lib/screens/cart_screen.dart').readAsStringSync();
      expect(cart.contains("label: 'Delivery Address'"), isTrue);
      expect(cart.contains("label: 'Special instructions (optional)'"),
          isTrue);
      final co = File('lib/screens/remedoo_checkout_screen.dart')
          .readAsStringSync();
      expect(co.contains("label: 'Delivery Address'"), isTrue);
      expect(co.contains("label: 'Notes'"), isTrue);
      final cm =
          File('lib/screens/care_match_screen.dart').readAsStringSync();
      expect(cm.contains("label: 'Describe your symptoms'"), isTrue);
    });

    test('cart delivery uses the configured fee and threshold', () {
      final cart = File('lib/screens/cart_screen.dart').readAsStringSync();
      expect(cart.contains('subtotal > 500 ? 0.0 : 30.0'), isFalse);
      expect(cart.contains('state.freeDeliveryThreshold'), isTrue);
    });
  });
}
