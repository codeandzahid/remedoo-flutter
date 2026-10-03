import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/main.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:remedoo_app/services/auth_service.dart';
import 'package:remedoo_app/screens/doctors_screen.dart';
import 'package:remedoo_app/screens/settings_screen.dart';
import 'package:remedoo_app/screens/pharmacy_detail_screen.dart';
import 'package:remedoo_app/screens/booking_screen.dart';
import 'package:remedoo_app/screens/appointments_screen.dart';
import 'package:remedoo_app/screens/admin/admin_login_screen.dart';
import 'package:remedoo_app/screens/admin/admin_shell.dart';
import 'package:remedoo_app/data/mock_data.dart';

Widget _wrap(Widget child) {
  return AppStateScope(
    state: AppState(),
    child: MaterialApp(home: child),
  );
}

void main() {
  // Supabase's token auto-refresh uses a periodic Timer that would keep
  // pumpAndSettle from ever settling; disable it in widget tests.
  AuthService.disableAutoRefresh = true;


  testWidgets('guest login lands on dashboard with greeting',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
        AppStateScope(state: AppState(), child: const RemedooApp()));
    // RootGate waits for Supabase auth init (or its timeout) before routing.
    for (var i = 0;
        i < 40 &&
            find.text('Book Appointments').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    // Onboarding first launch
    expect(find.text('Book Appointments'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    // Sign in as guest
    await tester.tap(find.text('Skip, continue as guest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello,'), findsOneWidget);
    expect(find.text('Smart Care Finder'), findsOneWidget);
  });

  testWidgets('doctor search filters the list', (tester) async {
    await tester.pumpWidget(_wrap(const DoctorsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('41 doctors available'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).first, 'Cardiologist');
    await tester.pumpAndSettle();
    expect(find.text('41 doctors available'), findsNothing);
    expect(find.text('Cardiologist'), findsWidgets);
  });

  testWidgets('pharmacy add-to-cart shows stepper and cart bar',
      (tester) async {
    final ph = pharmacies.first;
    await tester.pumpWidget(
        _wrap(PharmacyDetailScreen(pharmacy: ph)));
    await tester.pumpAndSettle();
    final addButtons = find.widgetWithText(OutlinedButton, 'ADD');
    expect(addButtons.evaluate().isNotEmpty, isTrue);
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();
    // Cart bar appears
    expect(find.textContaining('View Cart'), findsOneWidget);
  });

  testWidgets('booking creates an appointment', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final d = doctors.first;
    await tester.pumpWidget(_wrap(BookingScreen(
      kind: 'doctor',
      refId: d.id,
      title: d.name,
      subtitle: d.specialty,
      place: d.hospital,
      fee: d.fee,
    )));
    await tester.pumpAndSettle();
    // Pick first available time slot
    final chips = find.byType(ChoiceChip);
    expect(chips.evaluate().isNotEmpty, isTrue);
    await tester.tap(chips.first);
    await tester.pumpAndSettle();
    final confirm = find.byType(FilledButton);
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('Appointments (1)'), findsOneWidget);
    expect(find.textContaining('Appointment booked successfully!'),
        findsOneWidget);
  });

  testWidgets('admin login sets admin role', (tester) async {
    final state = AppState();
    await tester.pumpWidget(AppStateScope(
        state: state,
        child: const MaterialApp(
            home: AdminLoginScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In as Admin'));
    await tester.pumpAndSettle();
    expect(state.isLoggedIn, isTrue);
    expect(state.role, 'admin');
  });

  testWidgets('root gate shows admin console for admin role',
      (tester) async {
    final state = AppState();
    state.markOnboardingSeen();
    state.login(name: 'Admin', email: 'admin@remedoo.app');
    state.switchRole('admin');
    await tester.pumpWidget(
        AppStateScope(state: state, child: const RemedooApp()));
    // RootGate waits for Supabase auth init (or its timeout) before routing.
    for (var i = 0;
        i < 40 && find.byType(AdminShell).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.byType(AdminShell), findsOneWidget);
  });


  testWidgets('logout via settings clears the session', (tester) async {
    final state = AppState();
    state.loginAsGuest();
    expect(state.isLoggedIn, isTrue);
    await tester.pumpWidget(AppStateScope(
        state: state, child: const MaterialApp(home: SettingsScreen())));
    await tester.pumpAndSettle();
    // Scroll the Log Out button into view and tap it.
    final logoutFinder = find.text('Log Out');
    await tester.scrollUntilVisible(logoutFinder, 200);
    await tester.tap(logoutFinder);
    await tester.pumpAndSettle();
    // Confirmation dialog appears; confirm.
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();
    expect(state.isLoggedIn, isFalse);
  });

  testWidgets('guest sees sign-in gate on appointments screen', (tester) async {
    final state = AppState();
    state.loginAsGuest();
    await tester.pumpWidget(AppStateScope(
        state: state, child: const MaterialApp(home: AppointmentsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('guest booking shows sign-in dialog and can exit to login',
      (tester) async {
    final state = AppState();
    state.loginAsGuest();
    await tester.pumpWidget(AppStateScope(
        state: state,
        child: const MaterialApp(
            home: BookingScreen(
          kind: 'doctor',
          refId: 'd1',
          title: 'Dr. Test',
          subtitle: 'Cardiologist',
          place: 'Test Clinic',
          fee: 500,
        ))));
    await tester.pumpAndSettle();
    // Tap the confirm booking button.
    final confirm = find.textContaining('Confirm Booking');
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    // Sign-in required dialog appears; no appointment is booked.
    expect(find.text('Sign in required'), findsOneWidget);
    expect(state.appointments, isEmpty);
    // Choosing Sign In exits guest mode.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(state.isLoggedIn, isFalse);
  });

}

