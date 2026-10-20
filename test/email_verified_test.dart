import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remedoo_app/app_navigator.dart';
import 'package:remedoo_app/main.dart';
import 'package:remedoo_app/screens/email_verified_screen.dart';
import 'package:remedoo_app/screens/login_screen.dart';
import 'package:remedoo_app/services/auth_service.dart';
import 'package:remedoo_app/state/app_state.dart';

/// Tests for the Email Verified screen (owner order, 2026-10-20):
/// a signup email-confirmation link landing shows "Email Verified"
/// before anything else; Continue sends a completed account to the
/// login screen (its link-created session ended), while an account
/// that never finished signup (OTP route — no password exists) goes
/// to the Step 2 completion screen instead, since login would be
/// impossible for it. Password recovery is untouched: its landings
/// classify as recovery and keep using ResetPasswordScreen.
void main() {
  SharedPreferences.setMockInitialValues({});
  AuthService.disableAutoRefresh = true;

  group('AuthService.callbackKindFor: landing classification', () {
    final now = DateTime.utc(2026, 10, 20, 12, 0);
    String ago(Duration d) => now.subtract(d).toIso8601String();

    test('no session means no landing', () {
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: false,
          redirectType: 'signup',
          emailConfirmedAt: ago(const Duration(seconds: 5)),
          now: now,
        ),
        AuthCallbackKind.none,
      );
    });

    test('recovery returns classify as recovery (PKCE + implicit)',
        () {
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: 'passwordRecovery',
          emailConfirmedAt: ago(const Duration(days: 30)),
          now: now,
        ),
        AuthCallbackKind.recovery,
      );
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: 'recovery',
          emailConfirmedAt: null,
          now: now,
        ),
        AuthCallbackKind.recovery,
      );
    });

    test('an implicit signup return is a confirmation landing', () {
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: 'signup',
          emailConfirmedAt: null,
          now: now,
        ),
        AuthCallbackKind.emailConfirmation,
      );
    });

    test('a PKCE return whose email was just confirmed is a '
        'confirmation landing', () {
      // The confirmation email's link: gotrue stamps
      // email_confirmed_at when the link is tapped, seconds before
      // redirecting into the app — the exchange itself is untyped.
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: null,
          emailConfirmedAt: ago(const Duration(seconds: 30)),
          now: now,
        ),
        AuthCallbackKind.emailConfirmation,
      );
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: null,
          emailConfirmedAt: ago(const Duration(minutes: 14)),
          now: now,
        ),
        AuthCallbackKind.emailConfirmation,
      );
    });

    test('a magic-link return for an old account is a plain sign-in',
        () {
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: 'magiclink',
          emailConfirmedAt: ago(const Duration(days: 2)),
          now: now,
        ),
        AuthCallbackKind.signIn,
      );
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: null,
          emailConfirmedAt: ago(const Duration(days: 90)),
          now: now,
        ),
        AuthCallbackKind.signIn,
      );
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: null,
          emailConfirmedAt: null,
          now: now,
        ),
        AuthCallbackKind.signIn,
      );
    });

    test('a link return that itself confirmed the email counts as '
        'confirmation even when typed as a magic link', () {
      expect(
        AuthService.callbackKindFor(
          sessionEstablished: true,
          redirectType: 'magiclink',
          emailConfirmedAt: ago(const Duration(minutes: 1)),
          now: now,
        ),
        AuthCallbackKind.emailConfirmation,
      );
    });
  });

  group('EmailVerifiedScreen', () {
    Future<void> pushVerified(WidgetTester tester, AppState state) async {
      await tester.pumpWidget(
        AppStateScope(
          state: state,
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            home: const Scaffold(body: Text('UNDERNEATH')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      appNavigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const EmailVerifiedScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerifiedScreen), findsOneWidget);
    }

    testWidgets('shows the verified message', (tester) async {
      final state = AppState()
        ..login(name: 'Test A', email: 'testa@example.com');
      await pushVerified(tester, state);
      expect(find.text('Email Verified'), findsOneWidget);
      expect(find.text('Email verified ✅'), findsOneWidget);
      expect(
        find.text(
            'Your email address has been verified successfully.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'completed account: Continue ends the session and shows '
        'the login screen', (tester) async {
      final state = AppState()
        ..login(name: 'Test A', email: 'testa@example.com');
      await pushVerified(tester, state);
      expect(find.text('Continue to Login'), findsOneWidget);

      await tester.tap(find.text('Continue to Login'));
      await tester.pumpAndSettle();

      // Session ended, Verified screen gone, login (Welcome Back) up.
      expect(state.isSignedIn, isFalse);
      expect(find.byType(EmailVerifiedScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets(
        'incomplete account: Continue keeps the session and hands '
        'over to the completion gate underneath', (tester) async {
      final state = AppState()
        ..login(name: 'Test C', email: 'testc@example.com')
        ..debugSetProfileComplete(false);
      await pushVerified(tester, state);
      expect(find.text('Finish Your Account'), findsOneWidget);
      expect(find.text('Continue to Login'), findsNothing);

      await tester.tap(find.text('Finish Your Account'));
      await tester.pumpAndSettle();

      // Screen popped (RootGate's Step 2 gate is what shows in the
      // real app), session deliberately kept for Step 2 to complete
      // the same account, and NO forced login.
      expect(find.byType(EmailVerifiedScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('UNDERNEATH'), findsOneWidget);
      expect(state.isSignedIn, isTrue);
    });
  });

  group('plain boot never shows the Verified screen', () {
    testWidgets('a restored session lands in the app as before',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final state = AppState()
        ..login(name: 'Test A', email: 'testa@example.com')
        ..markOnboardingSeen();
      await tester.pumpWidget(
          AppStateScope(state: state, child: const RemedooApp()));
      for (var i = 0;
          i < 40 && find.text('Smart Care').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
      expect(find.text('Smart Care'), findsOneWidget);
      expect(find.text('Email Verified'), findsNothing);
      expect(find.byType(EmailVerifiedScreen), findsNothing);
    });
  });
}
