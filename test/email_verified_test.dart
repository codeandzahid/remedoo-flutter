import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remedoo_app/app_navigator.dart';
import 'package:remedoo_app/main.dart';
import 'package:remedoo_app/screens/email_verified_screen.dart';
import 'package:remedoo_app/screens/login_screen.dart';
import 'package:remedoo_app/screens/signup_screen.dart';
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

  group('link landings through RootGate', () {
    // Boots the REAL app (RootGate) with a session already present,
    // the way a link landing leaves it: the session has arrived and
    // signup completeness is whatever [incomplete] says, resolved in
    // the same boot — RootGate puts an unfinished account on the
    // Step 2 gate and a finished one in the app. Supabase is not
    // initialized in tests, so attachAuthListener stops early there;
    // the landing itself is then driven through
    // AppState.handleAuthCallbackLanding, the exact method
    // attachAuthListener routes the URL exchange's result through.
    Future<AppState> pumpLandedApp(
      WidgetTester tester, {
      required bool incomplete,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final state = AppState()
        ..login(name: '', email: 'testf@example.com')
        ..markOnboardingSeen();
      if (incomplete) state.debugSetProfileComplete(false);
      await tester.pumpWidget(
          AppStateScope(state: state, child: const RemedooApp()));
      bool settled() => incomplete
          ? find.byType(SignupScreen).evaluate().isNotEmpty
          : find.text('Smart Care').evaluate().isNotEmpty;
      for (var i = 0; i < 40 && !settled(); i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
      expect(settled(), isTrue, reason: 'boot should settle');
      expect(find.byType(EmailVerifiedScreen), findsNothing);
      return state;
    }

    Future<void> land(
      WidgetTester tester,
      AppState state,
      AuthCallbackResult result,
    ) async {
      await state.handleAuthCallbackLanding(result);
      // Presentation is registered as a post-frame callback (the
      // same mechanism the recovery route uses; in the live app the
      // frames boot keeps producing run it immediately). Force that
      // frame here, then settle the route transition.
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets(
        'magic-link resume landing: a signIn-classified landing for '
        'an incomplete account still presents the Verified screen '
        'above the gate', (tester) async {
      // The Run B regression (live, 2026-10-21): the account's email
      // was confirmed by an earlier click, so this later "Sign in
      // automatically" landing classifies as signIn (the landing
      // itself confirmed nothing) — yet it is the resume moment for
      // an unfinished signup and must not skip the Verified screen.
      final state = await pumpLandedApp(tester, incomplete: true);
      expect(find.byType(SignupScreen), findsOneWidget);

      await land(
        tester,
        state,
        const AuthCallbackResult(
          AuthCallbackKind.signIn,
          sessionEstablished: true,
        ),
      );

      // The Verified screen is the top route, with the button right
      // at first paint (completeness was resolved before presenting,
      // so no "Continue to Login" flicker).
      expect(find.byType(EmailVerifiedScreen), findsOneWidget);
      expect(find.text('Finish Your Account'), findsOneWidget);
      expect(find.text('Continue to Login'), findsNothing);

      // Continue hands over to the completion gate underneath and
      // keeps the session for Step 2.
      await tester.tap(find.text('Finish Your Account'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerifiedScreen), findsNothing);
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(state.isSignedIn, isTrue);
    });

    testWidgets(
        'fresh confirmation landing presents the Verified screen '
        'above the gate', (tester) async {
      final state = await pumpLandedApp(tester, incomplete: true);

      await land(
        tester,
        state,
        const AuthCallbackResult(
          AuthCallbackKind.emailConfirmation,
          sessionEstablished: true,
        ),
      );

      expect(find.byType(EmailVerifiedScreen), findsOneWidget);
      expect(find.text('Finish Your Account'), findsOneWidget);
      expect(find.text('Continue to Login'), findsNothing);

      await tester.tap(find.text('Finish Your Account'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailVerifiedScreen), findsNothing);
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(state.isSignedIn, isTrue);
    });

    testWidgets(
        'established-account magic link: a signIn landing for a '
        'complete account shows no Verified screen', (tester) async {
      final state = await pumpLandedApp(tester, incomplete: false);
      expect(find.text('Smart Care'), findsOneWidget);

      await land(
        tester,
        state,
        const AuthCallbackResult(
          AuthCallbackKind.signIn,
          sessionEstablished: true,
        ),
      );

      expect(find.byType(EmailVerifiedScreen), findsNothing);
      expect(find.text('Smart Care'), findsOneWidget);
      expect(state.isSignedIn, isTrue);
    });

    testWidgets('recovery and empty landings never present the '
        'Verified screen', (tester) async {
      final state = await pumpLandedApp(tester, incomplete: true);

      await land(tester, state, AuthCallbackResult.none);
      expect(find.byType(EmailVerifiedScreen), findsNothing);

      await land(
        tester,
        state,
        const AuthCallbackResult(
          AuthCallbackKind.recovery,
          sessionEstablished: true,
        ),
      );
      expect(find.byType(EmailVerifiedScreen), findsNothing);
      expect(find.byType(SignupScreen), findsOneWidget);
    });
  });
}
