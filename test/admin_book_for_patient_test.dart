import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/state/app_state.dart';

/// Admin Book for patient (owner order 2026-11-11): the admin books
/// a doctor appointment for a patient who already has a Remedoo
/// account. The form needs a found patient, a doctor, a date and a
/// time slot; the booking starts pending, like a patient-made one.
void main() {
  test('validator: needs patient, doctor, date and slot', () {
    final future = DateTime.now().add(const Duration(days: 1));
    expect(
        validateAdminBookingForPatient(
            patientId: '',
            doctorId: 'd1',
            date: future,
            timeLabel: '09:00'),
        'Find the patient first — type their phone or email and tap Fill.');
    expect(
        validateAdminBookingForPatient(
            patientId: 'uid-1',
            doctorId: '',
            date: future,
            timeLabel: '09:00'),
        'Choose a doctor.');
    expect(
        validateAdminBookingForPatient(
            patientId: 'uid-1',
            doctorId: 'd1',
            date: null,
            timeLabel: '09:00'),
        'Choose a date.');
    expect(
        validateAdminBookingForPatient(
            patientId: 'uid-1',
            doctorId: 'd1',
            date: future,
            timeLabel: ''),
        'Choose a time slot.');
    expect(
        validateAdminBookingForPatient(
            patientId: 'uid-1',
            doctorId: 'd1',
            date: future,
            timeLabel: '09:00'),
        isNull);
  });

  test('validator: today is allowed, past dates are not', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    expect(
        validateAdminBookingForPatient(
            patientId: 'uid-1',
            doctorId: 'd1',
            date: today,
            timeLabel: '09:00'),
        isNull);
    expect(
        validateAdminBookingForPatient(
            patientId: 'uid-1',
            doctorId: 'd1',
            date: yesterday,
            timeLabel: '09:00'),
        'Choose today or a later date.');
  });

  test('payment labels map to stored values', () {
    expect(AppState.dbPaymentMethod('Pay Online'), 'online');
    expect(AppState.dbPaymentMethod('At Clinic'), 'at_clinic');
    expect(AppState.paymentLabelFor('online'), 'Pay Online');
    expect(AppState.paymentLabelFor('at_clinic'), 'At Clinic');
  });

  test('bookAppointmentForPatient returns null without a signed-in admin',
      () async {
    final state = AppState();
    expect(
        await state.bookAppointmentForPatient(
          patientId: 'uid-1',
          doctorId: 'd1',
          doctorName: 'Dr A',
          date: DateTime.now().add(const Duration(days: 1)),
          timeLabel: '09:00',
        ),
        isNull);
  });

  test('bookAppointmentForPatient rejects bad input without a backend call',
      () async {
    final state = AppState();
    expect(
        await state.bookAppointmentForPatient(
          patientId: '',
          doctorId: '',
          doctorName: '',
          date: DateTime.now().add(const Duration(days: 1)),
          timeLabel: '',
        ),
        isNull);
  });
}
