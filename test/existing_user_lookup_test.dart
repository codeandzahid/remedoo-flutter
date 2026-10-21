import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remedoo_app/services/supabase_repository.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:remedoo_app/widgets/existing_user_lookup.dart';

/// The admin/panel form autofill popup (owner order, 2026-10-21):
/// typing a complete email or mobile that exactly matches an
/// existing PATIENT account offers "Existing user found" with
/// Fill / Cancel. Pinned here: completeness gating (never per
/// keystroke), the popup + Fill behaviour, Cancel's no-re-pop rule,
/// no popup on no-match or partial values, the patient-only rule
/// (a provider email produces nothing — enforced by the
/// SECURITY DEFINER RPC, whose contract is pinned against the
/// migration file), and graceful behaviour while the RPC is not
/// applied / Supabase is not initialised.
void main() {
  const patient = FormUserRecord(
    userId: 'patient-1',
    fullName: 'Test A',
    email: 'testa@example.com',
    phone: '9906000001',
    address: 'Bakura, Srinagar, J&K 190006',
    gender: 'Female',
    dateOfBirth: '1990-05-04',
  );

  group('complete-value gating', () {
    test('emails must be complete', () {
      expect(isCompleteEmailValue('testa@example.com'), isTrue);
      expect(isCompleteEmailValue(' testa@example.com '), isTrue);
      expect(isCompleteEmailValue('testa@example'), isFalse);
      expect(isCompleteEmailValue('testa@'), isFalse);
      expect(isCompleteEmailValue('testa.example.com'), isFalse);
      expect(isCompleteEmailValue(''), isFalse);
    });

    test('mobiles must hold a full 10-digit number', () {
      expect(completeMobileDigits('9906000001'), '9906000001');
      expect(completeMobileDigits('+91 99060 00001'), '9906000001');
      expect(completeMobileDigits('09906000001'), '9906000001');
      expect(completeMobileDigits('99060'), isNull);
      expect(completeMobileDigits('990600000'), isNull);
      expect(completeMobileDigits(''), isNull);
      expect(isLookupReadyValue('9906000001'), isTrue);
      expect(isLookupReadyValue('99060'), isFalse);
    });
  });

  group('record parsing', () {
    test('a full RPC row maps to display fields', () {
      final r = FormUserRecord.fromRow({
        'user_id': 'patient-1',
        'full_name': 'Test A',
        'email': 'testa@example.com',
        'phone': '9906000001',
        'address': 'Bakura, Srinagar, J&K 190006',
        'gender': 'Female',
        'date_of_birth': '1990-05-04',
      });
      expect(r.userId, 'patient-1');
      expect(r.fullName, 'Test A');
      expect(r.email, 'testa@example.com');
      expect(r.phone, '9906000001');
      expect(r.address, 'Bakura, Srinagar, J&K 190006');
      expect(r.gender, 'Female');
      expect(r.dateOfBirthLabel, '4/5/1990');
    });

    test('missing fields stay empty', () {
      final r = FormUserRecord.fromRow({'user_id': 'p2'});
      expect(r.fullName, isEmpty);
      expect(r.email, isEmpty);
      expect(r.dateOfBirthLabel, isEmpty);
    });
  });

  group('migration contract (lookup_user_for_form)', () {
    final sql =
        File('supabase/migration/lookup_user_for_form.sql').readAsStringSync();

    test('is a SECURITY DEFINER function granted to authenticated only',
        () {
      expect(sql, contains('lookup_user_for_form'));
      expect(sql, contains('SECURITY DEFINER'));
      expect(sql, contains('TO authenticated'));
      expect(sql, isNot(contains('TO anon')));
    });

    test('the caller must hold an admin/staff/provider role', () {
      for (final role in ['admin', 'staff', 'doctor', 'hospital', 'lab', 'pharmacy']) {
        expect(sql, contains("has_role(auth.uid(), '$role'"),
            reason: 'caller gate must include $role');
      }
    });

    test('matches are patient-only: any non-user role excludes the row',
        () {
      // One role per account: a patient is role 'user' or role-less.
      // The function excludes every account holding any other role,
      // so a doctor/hospital/lab/pharmacy/driver/admin/staff email
      // or mobile can never produce a record.
      expect(sql, contains("r.role <> 'user'"));
      expect(sql, contains('user_roles'));
    });
  });

  group('repository degradation', () {
    test('returns null while Supabase is not initialised (no popup)',
        () async {
      final row = await SupabaseRepository.instance
          .lookupUserForForm('testa@example.com');
      expect(row, isNull);
    });
  });

  group('popup widget', () {
    late AppState state;
    late TextEditingController nameCtrl;
    late TextEditingController triggerCtrl;
    int lookupCalls = 0;
    String? lastQuery;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
      nameCtrl = TextEditingController();
      triggerCtrl = TextEditingController();
      lookupCalls = 0;
      lastQuery = null;
    });

    tearDown(() {
      state.debugSetUserLookup(null);
      nameCtrl.dispose();
      triggerCtrl.dispose();
    });

    Widget harness() {
      return AppStateScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: ExistingUserLookup(
              trigger: triggerCtrl,
              debounce: const Duration(milliseconds: 50),
              onFill: (record) {
                if (record.fullName.isNotEmpty) {
                  nameCtrl.text = record.fullName;
                }
                if (record.phone.isNotEmpty) {
                  triggerCtrl.text = record.phone;
                }
              },
              child: Column(
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: triggerCtrl,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> typeValue(WidgetTester tester, String value) async {
      await tester.enterText(
          find.widgetWithText(TextField, 'Mobile'), value);
      // Let the debounce fire and the lookup future resolve.
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();
    }

    testWidgets('exact patient match pops up the saved details',
        (tester) async {
      state.debugSetUserLookup((q) async {
        lookupCalls++;
        lastQuery = q;
        return q == '9906000001' ? patient : null;
      });
      await tester.pumpWidget(harness());
      await typeValue(tester, '9906000001');
      await tester.pumpAndSettle();
      expect(lookupCalls, 1);
      expect(lastQuery, '9906000001');
      expect(find.text('Existing user found'), findsOneWidget);
      expect(find.text('Test A'), findsWidgets);
      expect(find.text('9906000001'), findsWidgets);
      expect(find.text('Fill'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Fill populates the form and closes the popup',
        (tester) async {
      state.debugSetUserLookup((q) async => patient);
      await tester.pumpWidget(harness());
      await typeValue(tester, '9906000001');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill'));
      await tester.pumpAndSettle();
      expect(find.text('Existing user found'), findsNothing);
      expect(nameCtrl.text, 'Test A');
      expect(triggerCtrl.text, '9906000001');
    });

    testWidgets(
        'Cancel changes nothing and the popup does not re-appear for '
        'the same value, but re-arms when the value changes',
        (tester) async {
      state.debugSetUserLookup(
          (q) async => q.endsWith('1') || q.endsWith('2') ? patient : null);
      await tester.pumpWidget(harness());
      await typeValue(tester, '9906000001');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Existing user found'), findsNothing);
      expect(nameCtrl.text, isEmpty,
          reason: 'Cancel must not fill anything');

      // Same value typed again: still no popup.
      await typeValue(tester, '990600000');
      await typeValue(tester, '9906000001');
      await tester.pumpAndSettle();
      expect(find.text('Existing user found'), findsNothing);

      // A different complete value re-arms the popup.
      await typeValue(tester, '9906000002');
      await tester.pumpAndSettle();
      expect(find.text('Existing user found'), findsOneWidget);
    });

    testWidgets('no match means no popup', (tester) async {
      state.debugSetUserLookup((q) async => null);
      await tester.pumpWidget(harness());
      await typeValue(tester, '9906000009');
      await tester.pumpAndSettle();
      expect(find.text('Existing user found'), findsNothing);
    });

    testWidgets('a provider email produces no popup (patient-only)',
        (tester) async {
      // The RPC returns rows for patient accounts only — for a
      // provider's email it returns nothing, exactly like no match.
      state.debugSetUserLookup((q) async =>
          q == 'testa@example.com' ? patient : null);
      await tester.pumpWidget(harness());
      await typeValue(tester, 'doctor@remedoo.com');
      await tester.pumpAndSettle();
      expect(find.text('Existing user found'), findsNothing);
      expect(nameCtrl.text, isEmpty);
    });

    testWidgets('partial values never trigger a lookup', (tester) async {
      state.debugSetUserLookup((q) async {
        lookupCalls++;
        return patient;
      });
      await tester.pumpWidget(harness());
      await typeValue(tester, '99060');
      await typeValue(tester, 'testa@exam');
      await tester.pumpAndSettle();
      expect(lookupCalls, 0);
      expect(find.text('Existing user found'), findsNothing);
    });

    testWidgets('the lookup is debounced to the completed value',
        (tester) async {
      state.debugSetUserLookup((q) async {
        lookupCalls++;
        lastQuery = q;
        return null;
      });
      await tester.pumpWidget(harness());
      // Type the number in two steps inside the debounce window.
      await tester.enterText(
          find.widgetWithText(TextField, 'Mobile'), '99060000');
      await tester.enterText(
          find.widgetWithText(TextField, 'Mobile'), '9906000001');
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();
      expect(lookupCalls, 1);
      expect(lastQuery, '9906000001');
    });
  });
}
