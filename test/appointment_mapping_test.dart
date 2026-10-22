import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/screens/admin/admin_appointments_screen.dart';
import 'package:remedoo_app/state/app_state.dart';

/// Regression tests for the four defects found by Live Test 2
/// (2026-10-20, booking 13bfcd29 — Dr. Ghulam Nabi Lone, fee ₹1,
/// Pay at Clinic):
///  D1 the receipt/details showed fee ₹0 and payment "online";
///  D2 admin approval produced no patient notification;
///  D3 the admin list showed "doctor" instead of names, duplicated
///     rows, and never refreshed after approving;
///  D4 the receipt specialty read "doctor" instead of the real one.
/// Plus the follow-up found while fixing them:
///  D5 a still-pending appointment displayed as "Upcoming" with a
///     CONFIRMED receipt badge, because the row mapper collapsed
///     every non-cancelled stored status into 'upcoming'.
void main() {
  Map<String, dynamic> doctorRow(
          {String? paymentMethod = 'at_clinic',
          String status = 'pending'}) =>
      {
        'id': '13bfcd29-a8b6-47ed-aef9-f8ec05e3c103',
        'service_type': 'doctor',
        'doctor_id': 'doc-1',
        'appointment_date': '2026-10-20',
        'appointment_time': '09:00:00',
        'status': status,
        'payment_method': paymentMethod,
        'notes': '',
        'doctors': {
          'name': 'Dr. Ghulam Nabi Lone',
          'specialization': 'General Surgery',
          'consultation_fee': 1,
        },
      };

  group('D1/D4: backend appointment row -> patient display model', () {
    test('fee, specialty and payment come from the stored row', () {
      final a = AppState.apptFromRowForTest(doctorRow());
      expect(a.doctorName, 'Dr. Ghulam Nabi Lone');
      expect(a.fee, 1.0, reason: 'fee is the doctor consultation_fee');
      expect(a.specialty, 'General Surgery',
          reason: 'specialty is the doctor specialization, not the '
              'service_type');
      expect(a.payment, 'At Clinic',
          reason: "stored 'at_clinic' displays as the booking label");
      expect(a.isPaidOnline, isFalse);
      expect(a.remoteStatus, 'pending');
    });

    test("stored 'online' displays as Pay Online", () {
      final a = AppState.apptFromRowForTest(
          doctorRow(paymentMethod: 'online'));
      expect(a.payment, 'Pay Online');
      expect(a.isPaidOnline, isTrue);
    });

    test('missing payment_method falls back to the column default', () {
      final a = AppState.apptFromRowForTest(doctorRow(paymentMethod: null));
      expect(a.payment, 'At Clinic');
    });

    test('row without the doctor embed keeps the legacy fallbacks', () {
      final row = doctorRow()..remove('doctors');
      final a = AppState.apptFromRowForTest(row);
      expect(a.fee, 0);
      expect(a.specialty, 'doctor');
    });
  });

  group('D1: display label -> stored payment_method (booking write)', () {
    test('Pay Online stores online, everything else at_clinic', () {
      expect(AppState.dbPaymentMethod('Pay Online'), 'online');
      expect(AppState.dbPaymentMethod('At Clinic'), 'at_clinic');
    });
  });

  group('D2: the approved status written to the backend', () {
    test('is a status the appointments CHECK constraint allows', () {
      // schema_part_01: status IN ('pending','confirmed','completed',
      // 'cancelled'). Writing the display word 'upcoming' violated
      // it, so approvals failed and the trigger-sent approval
      // notification never fired.
      expect(AppState.approvedDbStatus, 'confirmed');
      expect(AppState.approvedDbStatus, isNot('upcoming'));
    });
  });

  group('D5: stored status -> local display status', () {
    test('pending stays pending — not upcoming, not confirmed', () {
      final a = AppState.apptFromRowForTest(doctorRow(status: 'pending'));
      expect(a.status, 'pending',
          reason: 'an unapproved booking must not display as '
              '"Upcoming" or get a CONFIRMED receipt badge');
      expect(a.remoteStatus, 'pending');
    });

    test('confirmed displays as upcoming (the local vocabulary)', () {
      final a = AppState.apptFromRowForTest(doctorRow(status: 'confirmed'));
      expect(a.status, 'upcoming');
      expect(a.remoteStatus, 'confirmed');
    });

    test('cancelled stays cancelled', () {
      final a = AppState.apptFromRowForTest(doctorRow(status: 'cancelled'));
      expect(a.status, 'cancelled');
      expect(a.remoteStatus, 'cancelled');
    });

    test('completed maps to completed so it lands in Past', () {
      // Full-check fix 2026-10-22: completed used to collapse into
      // 'upcoming', so finished visits never left the Upcoming list.
      final a = AppState.apptFromRowForTest(doctorRow(status: 'completed'));
      expect(a.status, 'completed');
      expect(a.remoteStatus, 'completed');
    });

    test('a row without a status defaults to pending, never confirmed',
        () {
      final row = doctorRow()..remove('status');
      final a = AppState.apptFromRowForTest(row);
      expect(a.status, 'pending');
    });

    test('localStatusFor maps the full stored vocabulary', () {
      expect(AppState.localStatusFor('pending'), 'pending');
      expect(AppState.localStatusFor('confirmed'), 'upcoming');
      expect(AppState.localStatusFor('completed'), 'completed');
      expect(AppState.localStatusFor('cancelled'), 'cancelled');
    });
  });

  group('D3: admin appointment row names', () {
    test('patient name and embedded doctor name are used', () {
      final names = adminAppointmentNames({
        'patient_name': 'Test A',
        'service_type': 'doctor',
        'doctors': {'name': 'Dr. Ghulam Nabi Lone'},
      });
      expect(names.patient, 'Test A');
      expect(names.provider, 'Dr. Ghulam Nabi Lone');
    });

    test('falls back gracefully when names are missing', () {
      final names = adminAppointmentNames({'service_type': 'doctor'});
      expect(names.patient, 'Patient');
      expect(names.provider, 'doctor');
    });

    test('hospital embeds resolve too', () {
      final names = adminAppointmentNames({
        'patient_name': 'Test B',
        'service_type': 'hospital',
        'hospitals': {'name': 'SKIMS'},
      });
      expect(names.provider, 'SKIMS');
    });
  });
}
