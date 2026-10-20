import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/state/app_state.dart';

Medicine _med(String id, double price, {bool rx = false}) => Medicine(
      id: id,
      pharmacyId: 'p1',
      name: 'Med $id',
      pack: 'strip',
      brand: 'Brand',
      price: price,
      mrp: price,
      rxRequired: rx,
      category: 'General',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('placeOrder (patient-panel audit batch 1)', () {
    test('checkout notes are stored on the order (were silently dropped)',
        () {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      final o = s.placeOrder(
        address: '1 Main Street',
        payment: 'Cash on Delivery',
        notes: 'Leave at the door',
      );
      expect(o.notes, 'Leave at the door');
      expect(o.pharmacyId, 'p1');
    });

    test('no notes -> empty string', () {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      final o = s.placeOrder(
        address: '1 Main Street',
        payment: 'Cash on Delivery',
      );
      expect(o.notes, '');
    });

    test('free delivery at/above the 499 threshold', () {
      final s = AppState();
      s.addToCart(_med('m1', 500),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      final o = s.placeOrder(
        address: '1 Main Street',
        payment: 'Cash on Delivery',
      );
      expect(o.deliveryFee, 0);
      expect(o.total, 500);
    });

    test('delivery fee charged below the threshold', () {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      final o = s.placeOrder(
        address: '1 Main Street',
        payment: 'Cash on Delivery',
      );
      expect(o.deliveryFee, 30);
      expect(o.total, 130);
    });

    test('cart is cleared and the order is recorded', () {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'p1', pharmacyName: 'Pharmacy One');
      s.placeOrder(address: '1 Main Street', payment: 'Cash on Delivery');
      expect(s.cart, isEmpty);
      expect(s.orders.length, 1);
    });
  });
}
