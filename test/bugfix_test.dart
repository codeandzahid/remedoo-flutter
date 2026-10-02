import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/data/mock_data.dart';
import 'package:remedoo_app/screens/appointments_screen.dart';
import 'package:remedoo_app/screens/booking_screen.dart';
import 'package:remedoo_app/screens/main_shell.dart';
import 'package:remedoo_app/screens/profile_screen.dart';
import 'package:remedoo_app/screens/remedoo_pharmacy_screen.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:remedoo_app/widgets/widgets.dart';

Widget _wrap(Widget child, AppState state) {
  return AppStateScope(
    state: state,
    child: MaterialApp(home: child),
  );
}

// Sets a phone-sized test viewport; call at the start of each test.
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets('drawer opens from the dashboard menu button on phones',
      (tester) async {
    usePhoneSize(tester);
    final state = AppState();
    await tester.pumpWidget(_wrap(const MainShell(), state));
    await tester.pump(); // header (with menu button) builds immediately

    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // The dashboard's own (inner) scaffold must report the drawer open.
    final innerScaffold =
        tester.state<ScaffoldState>(find.byType(Scaffold).at(1));
    expect(innerScaffold.isDrawerOpen, isTrue);
    // Drawer destinations reachable again.
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets(
      'confirm booking creates the appointment and payment toggles',
      (tester) async {
    usePhoneSize(tester);
    final state = AppState();
    final d = doctors.first;
    await tester.pumpWidget(_wrap(
        BookingScreen(
          kind: 'doctor',
          refId: d.id,
          title: d.name,
          subtitle: d.specialty,
          place: d.hospital,
          fee: d.fee,
        ),
        state));
    await tester.pumpAndSettle();

    // The page's vertical list (the date strip has its own horizontal one).
    final pageList = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    );
    expect(pageList.evaluate().isNotEmpty, isTrue);

    // Drag until a lazily-built child exists.
    Future<void> reveal(Finder target) async {
      for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
        await tester.drag(pageList, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(target.evaluate().isNotEmpty, isTrue);
    }

    // Payment cards live below the fold on phones — scroll them into view.
    await reveal(find.text('Pay Online'));

    // Payment method radio toggles.
    final payOnlineCard = find.ancestor(
      of: find.text('Pay Online'),
      matching: find.byType(InkWell),
    );
    expect(payOnlineCard.evaluate().isNotEmpty, isTrue);
    await tester.tap(payOnlineCard);
    await tester.pump();

    // Scroll to the confirm button and complete the booking.
    await tester.drag(pageList, const Offset(0, -10000));
    await tester.pumpAndSettle();
    final confirmBtn = find.ancestor(
      of: find.textContaining('Confirm Booking'),
      matching: find.byType(FilledButton),
    );
    expect(confirmBtn.evaluate().isNotEmpty, isTrue);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(state.appointments, hasLength(1));
    expect(state.appointments.first.doctorName, d.name);
    expect(state.appointments.first.payment, 'Pay Online');
    expect(find.byType(AppointmentsScreen), findsOneWidget);
  });

  testWidgets('pharmacy ADD adds to cart and morphs into stepper',
      (tester) async {
    usePhoneSize(tester);
    final state = AppState();
    await tester.pumpWidget(_wrap(const RemedooPharmacyScreen(), state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // skeleton done
    await tester.pumpAndSettle(); // stagger animations done

    final addButtons = find.widgetWithText(OutlinedButton, 'ADD');
    expect(addButtons.evaluate().isNotEmpty, isTrue);
    await tester.ensureVisible(addButtons.first);
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();

    expect(state.cartCount, 1);
    expect(find.byType(QtyStepper), findsWidgets);
    // Checkout is reachable from the cart bar.
    expect(find.textContaining('Checkout'), findsOneWidget);
  });

  testWidgets('medicine detail sheet has a working Add to Cart button',
      (tester) async {
    usePhoneSize(tester);
    final state = AppState();
    final m = medicines.first;
    await tester.pumpWidget(_wrap(
        Scaffold(
          body: Builder(
            builder: (c) => Center(
              child: TextButton(
                onPressed: () => MedicineDetailSheet.show(c, m),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
        state));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(MedicineDetailSheet), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to Cart'));
    await tester.pumpAndSettle();

    expect(state.cartCount, 1);
    expect(state.cart.first.medicine.id, m.id);
    // Sheet now shows a quantity stepper instead of the button.
    expect(find.byType(QtyStepper), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add to Cart'), findsNothing);
  });

  testWidgets('guest profile Sign In logs out to the login screen',
      (tester) async {
    usePhoneSize(tester);
    final state = AppState();
    state.loginAsGuest();
    expect(state.isGuest, isTrue);
    await tester.pumpWidget(_wrap(const ProfileScreen(), state));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // Guest session ends; RootGate rebuilds straight to LoginScreen.
    expect(state.isLoggedIn, isFalse);
    expect(state.isGuest, isFalse);
  });
}
