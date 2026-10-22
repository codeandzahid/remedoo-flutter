import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/state/app_state.dart';

Medicine _med(String id, double price) => Medicine(
      id: id,
      pharmacyId: 'ph1',
      name: 'Med $id',
      pack: 'strip',
      brand: 'Brand',
      price: price,
      mrp: price,
      rxRequired: true,
      category: 'General',
    );

/// Form-pages audit Batch 3 — prescriptions end-to-end (M3):
/// checkout upload + orders.prescription_url, pharmacy view/verify,
/// admin order detail, doctor prescription creation/view fixes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('order prescription URL (M3a)', () {
    test('placeOrder stores the uploaded prescription URL', () async {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'ph1', pharmacyName: 'Pharmacy One');
      final o = await s.placeOrder(
        address: '1 Main Street',
        payment: 'Cash on Delivery',
        prescriptionUrl: 'https://example.test/rx.pdf',
      );
      expect(o?.prescriptionUrl, 'https://example.test/rx.pdf');
    });

    test('placeOrder without a file leaves the URL null', () async {
      final s = AppState();
      s.addToCart(_med('m1', 100),
          pharmacyId: 'ph1', pharmacyName: 'Pharmacy One');
      final o = await s.placeOrder(address: '1 Main Street', payment: 'COD');
      expect(o?.prescriptionUrl, isNull);
    });

    test('repository writes orders.prescription_url', () {
      final src = File('lib/services/supabase_repository.dart')
          .readAsStringSync();
      expect(src.contains("'prescription_url': prescriptionUrl"), isTrue);
    });

    test('both checkouts upload the picked file before ordering', () {
      for (final f in [
        'lib/screens/cart_screen.dart',
        'lib/screens/remedoo_checkout_screen.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src.contains('uploadOrderPrescription'), isTrue,
            reason: '$f must upload the prescription');
        expect(src.contains('_rxBytes'), isTrue,
            reason: '$f must keep the file bytes, not just the name');
      }
    });
  });

  group('pharmacy + admin surfaces (M3b/c)', () {
    test('pharmacy card views and verifies the prescription', () {
      final src = File('lib/screens/partner/pharmacy_dashboard.dart')
          .readAsStringSync();
      expect(src.contains('View prescription'), isTrue);
      expect(src.contains('setOrderPrescriptionVerified'), isTrue);
    });

    test('admin order card shows payment, prescription and refund data',
        () {
      final src = File('lib/screens/admin/admin_orders_screen.dart')
          .readAsStringSync();
      for (final needle in [
        'payment_method',
        'payment_status',
        'prescription_url',
        'refund_status',
        'customer_upi',
      ]) {
        expect(src.contains(needle), isTrue, reason: 'missing $needle');
      }
    });
  });

  group('doctor prescription creation + view (M3d/e)', () {
    test('repository creates prescriptions with items', () {
      final src = File('lib/services/supabase_repository.dart')
          .readAsStringSync();
      expect(src.contains("from('prescriptions').insert"), isTrue);
      expect(src.contains("from('prescription_items').insert"), isTrue);
    });

    test('doctor card opens the file instead of showing the raw URL',
        () {
      final src = File('lib/screens/partner/doctor_dashboard.dart')
          .readAsStringSync();
      expect(src.contains("Text('Prescription: \$url')"), isFalse);
      expect(src.contains('PrescriptionSheet.show'), isTrue);
    });

    test('prescription form file exists with the item columns', () {
      final src =
          File('lib/widgets/prescription_form.dart').readAsStringSync();
      for (final needle in [
        'medicine_name',
        'dosage',
        'frequency',
        'duration',
        'createPrescription',
      ]) {
        expect(src.contains(needle), isTrue, reason: 'missing $needle');
      }
    });
  });
}
