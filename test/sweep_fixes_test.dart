// Sweep fixes (2026-10-20, live click-through as Patient A):
//  F1 the checkout order note was stored and mapped but never
//     rendered on any patient screen;
//  F2 a removed cart line resurrected after reload because the
//     remove methods never persisted the cart;
//  F3 both checkouts opened with a blank delivery address even
//     when the patient had saved addresses on file.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/screens/order_tracking_screen.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Medicine med(String id, String name) => Medicine(
      id: id,
      pharmacyId: 'p1',
      name: name,
      pack: 'strip',
      brand: 'Test',
      price: 50,
      mrp: 60,
      rxRequired: false,
      category: 'General',
    );

/// Lets the fire-and-forget SharedPreferences writes land.
Future<void> flushPrefs() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('F1: order note survives the backend row -> model mapping', () {
    Map<String, dynamic> orderRow({Object? notes = 'Leave at the door'}) => {
          'id': '0c8b7a2e-0000-4000-8000-000000000001',
          'pharmacy_id': 'p1',
          'pharmacies': {'name': 'Remedoo Pharmacy'},
          'status': 'placed',
          'payment_method': 'cod',
          'payment_status': 'pending',
          'subtotal': 25,
          'delivery_fee': 30,
          'total': 55,
          'delivery_address': 'TESTA-HOME',
          'notes': notes,
          'placed_at': '2026-10-20T07:02:00.000Z',
          'order_items': [
            {
              'medicine_id': 'm1',
              'medicine_name': 'Crocin Advance',
              'quantity': 1,
              'unit_price': 25,
            },
          ],
        };

    test('notes column maps onto MedOrder.notes', () {
      final o = AppState.orderFromRowForTest(orderRow());
      expect(o.notes, 'Leave at the door');
    });

    test('missing/null notes map to empty string', () {
      expect(AppState.orderFromRowForTest(orderRow(notes: null)).notes, '');
      final noKey = orderRow()..remove('notes');
      expect(AppState.orderFromRowForTest(noKey).notes, '');
    });
  });

  group('F1: tracking screen renders the note', () {
    MedOrder order({String notes = ''}) => MedOrder(
          id: 'R742890',
          pharmacyName: 'Remedoo Pharmacy',
          items: [CartLine(medicine: med('m1', 'Crocin Advance'))],
          subtotal: 25,
          deliveryFee: 30,
          total: 55,
          address: 'TESTA-HOME',
          payment: 'Cash on Delivery',
          placedAt: DateTime(2026, 10, 20),
          notes: notes,
        );

    testWidgets('note card shows when the order has a note',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AppStateScope(
        state: AppState(),
        child: MaterialApp(
          home: OrderTrackingScreen(
              order: order(notes: 'Ring the bell twice')),
        ),
      ));
      await tester.pump();
      expect(find.text('Order Note'), findsOneWidget);
      expect(find.text('Ring the bell twice'), findsOneWidget);
    });

    testWidgets('no note card when the order has none', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(AppStateScope(
        state: AppState(),
        child: MaterialApp(home: OrderTrackingScreen(order: order())),
      ));
      await tester.pump();
      expect(find.text('Order Note'), findsNothing);
    });
  });

  group('F2: cart removals persist across reload', () {
    Future<AppState> reloaded() async {
      final s = AppState();
      await s.loadPersistedState();
      return s;
    }

    AppState stocked() {
      final s = AppState();
      s.addToCart(med('a', 'Azithral 500'),
          pharmacyId: 'p1', pharmacyName: 'Remedoo Pharmacy');
      s.addToCart(med('b', 'Crocin Advance'),
          pharmacyId: 'p1', pharmacyName: 'Remedoo Pharmacy');
      return s;
    }

    test('removeCartLine: removed item stays removed after reload',
        () async {
      final s = stocked();
      await flushPrefs();
      s.removeCartLine(
          s.cart.firstWhere((l) => l.medicine.id == 'a'));
      expect(s.cart.map((l) => l.medicine.id), ['b']);
      await flushPrefs();
      final back = await reloaded();
      expect(back.cart.map((l) => l.medicine.id), ['b'],
          reason: 'the removed line must not resurrect from storage');
      expect(back.cartPharmacyName, 'Remedoo Pharmacy');
    });

    test('removeFromCart: removed item stays removed after reload',
        () async {
      final s = stocked();
      await flushPrefs();
      s.removeFromCart('a');
      await flushPrefs();
      final back = await reloaded();
      expect(back.cart.map((l) => l.medicine.id), ['b']);
    });

    test('removing the last line clears the persisted cart', () async {
      final s = AppState();
      s.addToCart(med('a', 'Azithral 500'),
          pharmacyId: 'p1', pharmacyName: 'Remedoo Pharmacy');
      await flushPrefs();
      s.removeFromCart('a');
      await flushPrefs();
      final back = await reloaded();
      expect(back.cart, isEmpty);
      expect(back.cartPharmacyId, isNull);
    });

    test('no removal: reload restores the full cart (restore intact)',
        () async {
      stocked();
      await flushPrefs();
      final back = await reloaded();
      expect(back.cart.map((l) => l.medicine.id), ['a', 'b']);
    });

    test('clearCart still clears the persisted cart', () async {
      final s = stocked();
      await flushPrefs();
      s.clearCart();
      await flushPrefs();
      final back = await reloaded();
      expect(back.cart, isEmpty);
    });
  });

  group('F3: defaultDeliveryAddress', () {
    test('first saved-address book entry wins', () async {
      final s = AppState();
      await s.updateProfile(address: 'Profile Address 1');
      s.addSavedAddress(const SavedAddress(
          id: 'a1', label: 'Home', address: 'Book Address 1'));
      s.addSavedAddress(const SavedAddress(
          id: 'a2', label: 'Office', address: 'Book Address 2'));
      expect(s.defaultDeliveryAddress, 'Book Address 1');
    });

    test('falls back to the profile Saved Address', () async {
      final s = AppState();
      await s.updateProfile(address: 'Profile Address 9');
      expect(s.defaultDeliveryAddress, 'Profile Address 9');
    });

    test('empty book entries are skipped for the profile address',
        () async {
      final s = AppState();
      await s.updateProfile(address: 'Profile Address 9');
      s.addSavedAddress(
          const SavedAddress(id: 'a1', label: 'Home', address: '  '));
      expect(s.defaultDeliveryAddress, 'Profile Address 9');
    });
  });
}
