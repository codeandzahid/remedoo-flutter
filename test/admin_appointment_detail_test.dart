import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remedoo_app/screens/admin/admin_appointments_screen.dart';
import 'package:remedoo_app/state/app_state.dart';

/// The admin appointment detail view (owner order after Live Test 2
/// found the admin list rows opened nothing). The detail is the
/// admin panel's usual record dialog; these tests pin: the fields
/// it derives from a backend row, that a row tap opens it, that
/// approving from inside it writes the storable 'confirmed' status
/// through the same AppState path the list uses and re-renders both
/// the dialog and the list, and that finished bookings offer no
/// actions — the list's own rules.
void main() {
  Map<String, dynamic> doctorRow({
    String status = 'pending',
    String? paymentMethod = 'at_clinic',
  }) =>
      {
        'id': '13bfcd29-a8b6-47ed-aef9-f8ec05e3c103',
        'service_type': 'doctor',
        'doctor_id': 'doc-1',
        'patient_id': 'patient-1',
        'patient_name': 'Test A',
        'patient_email': 'testa@example.com',
        'patient_phone': '9906000001',
        'appointment_date': '2026-10-20',
        'appointment_time': '09:00:00',
        'status': status,
        'payment_method': paymentMethod,
        'notes': 'Fever since Monday',
        'created_at': '2026-10-19T10:30:00Z',
        'doctors': {
          'name': 'Dr. Ghulam Nabi Lone',
          'specialization': 'General Surgery',
          'consultation_fee': 1,
        },
      };

  group('detail derivation from a backend row', () {
    test('patient, contact, doctor, fee and payment all resolve', () {
      final d = adminAppointmentDetail(doctorRow());
      expect(d.patient, 'Test A');
      expect(d.email, 'testa@example.com');
      expect(d.phone, '9906000001');
      expect(d.provider, 'Dr. Ghulam Nabi Lone');
      expect(d.specialty, 'General Surgery',
          reason: 'specialty is the doctor specialization');
      expect(d.fee, 1.0,
          reason: 'fee is the embedded doctor consultation_fee — '
              'appointments has no fee column');
      expect(d.payment, 'At Clinic');
      expect(d.status, 'pending');
      expect(d.date, '20/10/2026');
      expect(d.time, '09:00',
          reason: 'seconds are trimmed, like the patient mapper');
      expect(d.notes, 'Fever since Monday');
    });

    test("stored 'online' displays as Pay Online", () {
      final d = adminAppointmentDetail(doctorRow(paymentMethod: 'online'));
      expect(d.payment, 'Pay Online');
    });

    test('a hospital booking has no fee or specialty to derive', () {
      final d = adminAppointmentDetail({
        'id': 'h1',
        'service_type': 'hospital',
        'patient_name': 'Test B',
        'appointment_date': '2026-10-21',
        'appointment_time': '10:30:00',
        'status': 'confirmed',
        'payment_method': 'at_clinic',
        'hospitals': {'name': 'SKIMS'},
      });
      expect(d.provider, 'SKIMS');
      expect(d.specialty, isEmpty);
      expect(d.fee, isNull);
      expect(d.email, isEmpty);
      expect(d.phone, isEmpty);
    });

    test('a row without contact stamps shows no contact fields', () {
      final row = doctorRow()
        ..remove('patient_email')
        ..remove('patient_phone');
      final d = adminAppointmentDetail(row);
      expect(d.email, isEmpty);
      expect(d.phone, isEmpty);
      expect(d.patient, 'Test A');
    });
  });

  group('detail dialog', () {
    // The Scaffold stands in for the AdminShell, which hosts the
    // section screens (and their snackbars) the same way.
    Widget wrap(AppState state) => AppStateScope(
          state: state,
          child: const MaterialApp(
              home: Scaffold(body: AdminAppointmentsScreen())),
        );

    /// Pumps the screen past its initial (empty, no-backend) load,
    /// then seeds the rows the way loadAdminAppointments would have.
    Future<void> pumpSeeded(
        WidgetTester tester, AppState state, List<Map<String, dynamic>> rows) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrap(state));
      await tester.pumpAndSettle();
      state.debugSeedAdminAppointments(rows);
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a row opens the detail with the booking data',
        (tester) async {
      final state = AppState();
      await pumpSeeded(tester, state, [doctorRow()]);

      await tester.tap(find.text('Test A'));
      await tester.pumpAndSettle();

      expect(find.text('Appointment details'), findsOneWidget);
      expect(find.text('Test A'), findsWidgets);
      expect(find.text('testa@example.com'), findsOneWidget);
      expect(find.text('9906000001'), findsOneWidget);
      expect(find.text('Dr. Ghulam Nabi Lone'), findsWidgets);
      expect(find.text('General Surgery'), findsOneWidget);
      expect(find.text('20/10/2026'), findsWidgets);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('₹1'), findsOneWidget,
          reason: 'fee formatted like the patient receipt');
      expect(find.text('At Clinic'), findsOneWidget);
      expect(find.text('Fever since Monday'), findsOneWidget);
      // A pending booking offers the list's actions inside the detail.
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets(
        'approve from the detail writes confirmed and updates dialog + list',
        (tester) async {
      final state = AppState()..debugSetAdminWritesLocal(true);
      await pumpSeeded(tester, state, [doctorRow()]);

      await tester.tap(find.text('Test A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      // The list handler's own confirmation step appears on top.
      expect(find.text('Approve appointment?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(state.adminAppointments.single['status'],
          AppState.approvedDbStatus,
          reason: "the written status is the storable 'confirmed', "
              "never the display word 'upcoming'");
      expect(find.text('Appointment approved. Patient notified.'),
          findsOneWidget);
      // The still-open detail now reflects the new status: the
      // pending actions are gone, the confirmed-row action (cancel)
      // is what remains.
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel appointment'), findsOneWidget);

      // And the list behind it shows the same confirmed state.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNothing,
          reason: 'a confirmed row no longer offers approve');
      expect(find.text('confirmed'), findsOneWidget);
      // Flush the snackbar timer so the test ends clean.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a cancelled appointment shows no actions in the detail',
        (tester) async {
      final state = AppState();
      await pumpSeeded(tester, state, [doctorRow(status: 'cancelled')]);

      await tester.tap(find.text('Test A'));
      await tester.pumpAndSettle();

      expect(find.text('Appointment details'), findsOneWidget);
      expect(find.text('cancelled'), findsWidgets);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel appointment'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('a completed appointment shows no actions in the detail',
        (tester) async {
      final state = AppState();
      await pumpSeeded(tester, state, [doctorRow(status: 'completed')]);

      await tester.tap(find.text('Test A'));
      await tester.pumpAndSettle();

      expect(find.text('Appointment details'), findsOneWidget);
      expect(find.text('completed'), findsWidgets);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Cancel appointment'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
