import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remedoo_app/data/mock_data.dart';
import 'package:remedoo_app/screens/appointments_screen.dart';
import 'package:remedoo_app/screens/booking_screen.dart';
import 'package:remedoo_app/screens/online_payment_screen.dart';
import 'package:remedoo_app/screens/main_shell.dart';
import 'package:remedoo_app/screens/profile_screen.dart';
import 'package:remedoo_app/screens/remedoo_pharmacy_screen.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:remedoo_app/app_navigator.dart';
import 'package:remedoo_app/screens/login_screen.dart';
import 'package:remedoo_app/widgets/widgets.dart';

Widget _wrap(Widget child, AppState state) {
  return AppStateScope(
    state: state,
    child: MaterialApp(navigatorKey: appNavigatorKey, home: child),
  );
}

// Sets a phone-sized test viewport; call at the start of each test.
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets(
      'guest redirect zombie state cannot bypass login gates', (tester) async {
    // Reproduces the reported bypass: a guest taps a gated button, the
    // toast shows, then the delayed logout fires while app pages are still
    // on screen. Even in that logged-out limbo state, checkLogin must keep
    // blocking — repeated tapping must never walk through an open gate.
    final state = AppState();
    state.loginAsGuest();
    expect(state.isGuest, isTrue);
    state.logout(); // what checkLogin's delayed redirect does
    expect(state.isGuest, isFalse);
    expect(state.isSignedIn, isFalse);
    expect(state.isLoggedIn, isFalse);

    bool? gateResult;
    await tester.pumpWidget(_wrap(
        Scaffold(
            body: Builder(builder: (context) {
          return ElevatedButton(
              onPressed: () => gateResult = checkLogin(context),
              child: const Text('Go'));
        })),
        state));
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(gateResult, isFalse,
        reason: 'checkLogin must block when not really signed in');
    // Flush checkLogin's delayed redirect timer so the test ends clean.
    await tester.pump(const Duration(milliseconds: 1500));
  });


  SharedPreferences.setMockInitialValues({});
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
    state.login(name: 'Test User', email: 'test@example.com');
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

    // No payment gateway is configured in tests, so "Pay Online" is
    // hidden and only the offline option remains.
    await reveal(find.text('At Clinic'));
    expect(find.text('Pay Online'), findsNothing);
    expect(
        find.textContaining('Online payment is not available'), findsWidgets);
    final atClinicCard = find.ancestor(
      of: find.text('At Clinic'),
      matching: find.byType(InkWell),
    );
    expect(atClinicCard.evaluate().isNotEmpty, isTrue);
    await tester.tap(atClinicCard);
    await tester.pump();

    await tester.drag(pageList, const Offset(0, -10000));
    await tester.pumpAndSettle();
    final confirmBtn = find.ancestor(
      of: find.textContaining('Confirm Booking'),
      matching: find.byType(FilledButton),
    );
    expect(confirmBtn.evaluate().isNotEmpty, isTrue);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Pay-at-clinic double confirmation, then the booking is made.
    await tester.tap(find.text('I Understand, Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Book Appointment')));
    await tester.pumpAndSettle();

    expect(state.appointments, hasLength(1));
    expect(state.appointments.first.payment, 'At Clinic');
  });

  testWidgets('booking with At Clinic payment books directly',
      (tester) async {
    usePhoneSize(tester);
    final state = AppState();
    state.login(name: 'Test User', email: 'test@example.com');
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

    final pageList = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    );
    Future<void> reveal(Finder target) async {
      for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
        await tester.drag(pageList, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(target.evaluate().isNotEmpty, isTrue);
    }

    await reveal(find.text('At Clinic'));
    final atClinicCard = find.ancestor(
      of: find.text('At Clinic'),
      matching: find.byType(InkWell),
    );
    await tester.tap(atClinicCard);
    await tester.pump();

    await tester.drag(pageList, const Offset(0, -10000));
    await tester.pumpAndSettle();
    final confirmBtn = find.ancestor(
      of: find.textContaining('Confirm Booking'),
      matching: find.byType(FilledButton),
    );
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Pay-at-clinic double confirmation.
    await tester.tap(find.text('I Understand, Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Book Appointment')));
    await tester.pumpAndSettle();

    expect(state.appointments, hasLength(1));
    expect(state.appointments.first.doctorName, d.name);
    expect(state.appointments.first.payment, 'At Clinic');
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

  testWidgets('guest profile Sign In opens the login screen',
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

    // Login page opens on top; the guest session stays intact.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(state.isGuest, isTrue);
  });
}
