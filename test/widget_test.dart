import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/main.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:remedoo_app/theme.dart';
import 'package:remedoo_app/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // SharedPreferences has no platform channel in widget tests; mock it so
  // AppState's persisted flags (onboarding, theme) load instantly instead
  // of hitting the boot timeout.
  SharedPreferences.setMockInitialValues({});
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
    expect(find.textContaining('Good '), findsOneWidget);
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

  testWidgets('guest appointments screen shows sign-in gate', (tester) async {
    final state = AppState();
    state.loginAsGuest();
    await tester.pumpWidget(AppStateScope(
        state: state, child: const MaterialApp(home: AppointmentsScreen())));
    await tester.pumpAndSettle();
    // Passive gate (no auto-redirect): message + Sign In button.
    expect(find.text('Please login to access this feature'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();
    expect(state.isLoggedIn, isFalse);
  });

  testWidgets('guest booking shows login toast and blocks booking',
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
    final confirm = find.textContaining('Confirm Booking');
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump();
    // Reference-style toast appears; no appointment is booked.
    expect(find.text('Please login to book appointments'), findsOneWidget);
    expect(state.appointments, isEmpty);
    // After the redirect delay the guest lands on the login screen.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(state.isLoggedIn, isFalse);
    expect(state.appointments, isEmpty);
  });

  testWidgets('guest does not see book-appointment buttons', (tester) async {
    final state = AppState();
    state.loginAsGuest();
    await tester.pumpWidget(AppStateScope(
        state: state, child: const MaterialApp(home: DoctorsScreen())));
    await tester.pumpAndSettle();
    // No "Book Appointment" button is shown to guests at all.
    expect(find.widgetWithText(RButton, 'Book Appointment'), findsNothing);
    expect(state.appointments, isEmpty);
    expect(state.isGuest, isTrue);
  });

  testWidgets('guest tapping a doctor card is sent to login', (tester) async {
    final state = AppState();
    state.loginAsGuest();
    await tester.pumpWidget(AppStateScope(
        state: state, child: const MaterialApp(home: DoctorsScreen())));
    await tester.pumpAndSettle();
    // Tap the first doctor card (not the Book button).
    final card = find.text('Dr. Aarav Malhotra');
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pump();
    await tester.pump();
    expect(find.text('Please login to view details'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(state.isLoggedIn, isFalse);
  });

  testWidgets('switching theme pack updates the theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    expect(state.themePack.id, 'sky_pulse');
    expect(RemedooTheme.primary, ThemePack.skyPulse.primary);
    await state.setThemePack(ThemePack.oceanSand);
    expect(state.themePack.id, 'ocean_sand');
    expect(RemedooTheme.primary, ThemePack.oceanSand.primary);
    expect(RemedooTheme.background, ThemePack.oceanSand.background);
    // Switching back restores Sky Pulse.
    await state.setThemePack(ThemePack.skyPulse);
    expect(RemedooTheme.primary, ThemePack.skyPulse.primary);
  });

  testWidgets('all six theme packs are defined', (tester) async {
    expect(ThemePack.all.length, 6);
    expect(
        ThemePack.all.map((p) => p.id).toSet(),
        {'sky_pulse', 'ocean_sand', 'lavender_mist', 'blush_rose',
         'honey_glow', 'emerald_heal'});
    for (final pack in ThemePack.all) {
      expect(ThemePack.byId(pack.id), pack);
    }
    expect(ThemePack.byId('nope'), isNull);
  });

  testWidgets('each theme has its own design personality', (tester) async {
    // Beyond color: distinct shape language, shadows, button style,
    // and header artwork per theme.
    final radii = ThemePack.all.map((p) => p.cardRadius).toSet();
    expect(radii.length, greaterThan(1),
        reason: 'themes should not all share one card radius');
    final backdrops = ThemePack.all.map((p) => p.backdrop).toSet();
    expect(backdrops.length, 6,
        reason: 'each theme needs its own header artwork');
    // Sky Pulse is the puffy claymorphism primary theme.
    expect(ThemePack.skyPulse.pillButtons, isTrue);
    expect(ThemePack.skyPulse.cardRadius, 28);
    expect(ThemePack.skyPulse.backdrop, ThemeBackdrop.clouds);
    // Switching packs changes the live design tokens too.
    final state = AppState();
    await state.setThemePack(ThemePack.emeraldHeal);
    expect(RemedooTheme.cardRadius, ThemePack.emeraldHeal.cardRadius);
    expect(RemedooTheme.pillButtons, isFalse);
    expect(RemedooTheme.backdrop, ThemeBackdrop.leaves);
    await state.setThemePack(ThemePack.skyPulse);
    expect(RemedooTheme.cardRadius, 28);
  });

}

