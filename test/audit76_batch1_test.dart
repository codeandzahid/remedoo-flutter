import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/state/app_state.dart';

Medicine _med(String id, double price) => Medicine(
      id: id,
      pharmacyId: 'p1',
      name: 'Med $id',
      pack: 'strip',
      brand: 'Brand',
      price: price,
      mrp: price,
      rxRequired: false,
      category: 'General',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('form-pages audit batch 1 — orders (M1)', () {
    test('Pay Online order carries canonical online/paid fields',
        () async {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      final o = (await s.placeOrder(
          address: '1 Main Street', payment: 'Pay Online'))!;
      expect(o.paymentMethod, 'online');
      expect(o.paymentStatus, 'paid');
      expect(o.isPaidOnline, isTrue);
    });

    test('COD order stays cod/pending', () async {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      final o = (await s.placeOrder(
          address: '1 Main Street', payment: 'Cash on Delivery'))!;
      expect(o.paymentMethod, 'cod');
      expect(o.paymentStatus, 'pending');
      expect(o.isPaidOnline, isFalse);
    });
  });

  group('form-pages audit batch 1 — reschedule (M2)', () {
    test('moves the same appointment, preserving id and all fields',
        () async {
      final s = AppState();
      final appt = (await s.bookAppointment(
        kind: 'doctor',
        refId: 'd1',
        title: 'Dr. One',
        subtitle: 'General Surgery',
        place: 'Clinic',
        date: DateTime(2026, 11, 1),
        timeLabel: '09:00',
        fee: 500,
        payment: 'Pay Online',
        notes: 'Bring reports',
        bookingForMemberId: 'F1',
        bookingForName: 'Mother',
        paymentRef: 'APT123',
        customerUpi: 'patient@upi',
      ))!;
      final countBefore = s.appointments.length;
      final newDate = DateTime(2026, 11, 3);
      await s.rescheduleAppointment(appt.id, newDate, '10:30');

      expect(s.appointments.length, countBefore);
      final moved = s.appointments.singleWhere((a) => a.id == appt.id);
      expect(moved.date, newDate);
      expect(moved.timeLabel, '10:30');
      expect(moved.status, isNot('cancelled'));
      expect(moved.bookingForMemberId, 'F1');
      expect(moved.bookingForName, 'Mother');
      expect(moved.paymentRef, 'APT123');
      expect(moved.customerUpi, 'patient@upi');
      expect(moved.notes, 'Bring reports');
      expect(moved.fee, 500);
    });

    test('unknown id is a no-op', () async {
      final s = AppState();
      final ok =
          await s.rescheduleAppointment('nope', DateTime(2026, 11, 3), '10:30');
      expect(ok, isFalse);
      expect(s.appointments, isEmpty);
    });
  });

  group('form-pages audit batch 1 — profile address (M9)', () {
    test('no fabricated default address', () {
      final s = AppState();
      expect(s.address, '');
      expect(s.defaultDeliveryAddress, isNull);
    });

    test('updateProfile stores the address for prefill', () async {
      final s = AppState();
      await s.updateProfile(address: 'Real Street 5');
      expect(s.address, 'Real Street 5');
      expect(s.defaultDeliveryAddress, 'Real Street 5');
    });
  });

  group('form-pages audit batch 1 — preference toggles (M10)', () {
    test('toggles flip locally without a session', () {
      final s = AppState();
      expect(s.darkMode, isFalse);
      s.toggleDarkMode();
      expect(s.darkMode, isTrue);
      s.toggleEmailNotif();
      expect(s.emailNotif, isFalse);
      s.togglePushNotif();
      expect(s.pushNotif, isFalse);
    });
  });
}
