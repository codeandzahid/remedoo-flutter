import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/main.dart';
import 'package:remedoo_app/services/auth_service.dart';
import 'package:remedoo_app/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the signup dead-end found by Live Test 3
/// (2026-10-20, Patient C — southkhanday+testc@gmail.com):
///  S1 Step 1's OTP send is signInWithOtp + verifyOtp(type: email) —
///     the correct pair; whether a code or a link arrives is decided
///     by the project's Magic Link email template ({{ .Token }}),
///     which is dashboard configuration, not app code.
///  S2 the duplicate-email guard hard-blocked half-created accounts
///     (user created by the first OTP send, Step 2 never reached, no
///     password set) with "already used" — no way forward at all.
///  S3 confirming via the email link landed the new user on the
///     dashboard with no name and no password: Step 2 never ran.
void main() {
  SharedPreferences.setMockInitialValues({});
  AuthService.disableAutoRefresh = true;

  group('S2: email_signup_state RPC value -> guard decision', () {
    test('finished accounts map to complete (blocked)', () {
      expect(AuthService.emailSignupStateFromValue('complete'),
          EmailSignupState.complete);
      expect(AuthService.emailSignupStateFromValue(' COMPLETE '),
          EmailSignupState.complete);
    });

    test('half-created accounts map to incomplete (resumable)', () {
      expect(AuthService.emailSignupStateFromValue('incomplete'),
          EmailSignupState.incomplete);
    });

    test('unknown values fail open to a fresh signup', () {
      expect(AuthService.emailSignupStateFromValue('new'),
          EmailSignupState.newAccount);
      expect(AuthService.emailSignupStateFromValue(null),
          EmailSignupState.newAccount);
      expect(AuthService.emailSignupStateFromValue(true),
          EmailSignupState.newAccount);
      expect(AuthService.emailSignupStateFromValue(''),
          EmailSignupState.newAccount);
    });
  });

  group('S3: signup completion signal (profileCompleteFor)', () {
    test('a name on the profile row completes the account', () {
      expect(AppState.profileCompleteFor(profileName: 'Test C'),
          isTrue);
    });

    test('a signup-time metadata name completes the account', () {
      expect(
        AppState.profileCompleteFor(
          profileName: '',
          userMetadata: const {'display_name': 'Test C'},
        ),
        isTrue,
      );
      expect(
        AppState.profileCompleteFor(
          profileName: '  ',
          userMetadata: const {'full_name': 'Test C'},
        ),
        isTrue,
      );
    });

    test('no name anywhere means signup was never finished', () {
      expect(AppState.profileCompleteFor(profileName: ''), isFalse);
      expect(
        AppState.profileCompleteFor(
          profileName: '',
          userMetadata: const {'display_name': ' '},
        ),
        isFalse,
      );
      expect(
        AppState.profileCompleteFor(profileName: '', userMetadata: null),
        isFalse,
      );
    });
  });

  group('S3: RootGate completion gate', () {
    Future<void> bootToShell(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
          AppStateScope(state: state, child: const RemedooApp()));
      // RootGate waits for splash + Supabase init before routing.
      for (var i = 0;
          i < 40 &&
              find.text('Finish your account').evaluate().isEmpty &&
              find.text('Smart Care').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
        'an unfinished account lands on Step 2, not the dashboard',
        (tester) async {
      final state = AppState()
        ..login(name: 'Test C', email: 'testc@example.com')
        ..markOnboardingSeen()
        ..debugSetProfileComplete(false);
      await bootToShell(tester, state);
      expect(find.text('Finish your account'), findsOneWidget);
      // Step 1 is pre-verified from the session; Step 2 is what shows.
      expect(find.text('testc@example.com'), findsOneWidget);
      expect(find.text('Create your profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      // Not the patient dashboard.
      expect(find.text('Smart Care'), findsNothing);
    });

    testWidgets('a finished account lands on the dashboard',
        (tester) async {
      final state = AppState()
        ..login(name: 'Test C', email: 'testc@example.com')
        ..markOnboardingSeen()
        ..debugSetProfileComplete(true);
      await bootToShell(tester, state);
      expect(find.text('Finish your account'), findsNothing);
      expect(find.text('Smart Care'), findsOneWidget);
    });
  });
}
