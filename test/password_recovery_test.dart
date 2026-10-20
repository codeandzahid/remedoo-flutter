import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remedoo_app/screens/reset_password_screen.dart';
import 'package:remedoo_app/services/auth_service.dart';
import 'package:remedoo_app/state/app_state.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  group('AuthService.isAuthCallbackUri', () {
    test('PKCE code return is an auth callback', () {
      expect(
        AuthService.isAuthCallbackUri(
            Uri.parse('https://remedoo-app.pages.dev/?code=abc123')),
        isTrue,
      );
    });

    test('implicit recovery fragment is an auth callback', () {
      expect(
        AuthService.isAuthCallbackUri(Uri.parse(
            'https://remedoo-app.pages.dev/#access_token=x&refresh_token=y&type=recovery')),
        isTrue,
      );
    });

    test('auth error return is an auth callback', () {
      expect(
        AuthService.isAuthCallbackUri(Uri.parse(
            'https://remedoo-app.pages.dev/?error=access_denied&error_description=expired')),
        isTrue,
      );
    });

    test('plain app URL is not an auth callback', () {
      expect(
        AuthService.isAuthCallbackUri(
            Uri.parse('https://remedoo-app.pages.dev/')),
        isFalse,
      );
    });

    test('unrelated query parameters are not an auth callback', () {
      expect(
        AuthService.isAuthCallbackUri(
            Uri.parse('https://remedoo-app.pages.dev/?utm_source=email')),
        isFalse,
      );
    });
  });

  group('ResetPasswordScreen validation', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        AppStateScope(
          state: AppState(),
          child: const MaterialApp(home: ResetPasswordScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('rejects a password shorter than 8 characters',
        (tester) async {
      await pumpScreen(tester);
      expect(find.text('Update Password'), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), 'short');
      await tester.enterText(fields.at(1), 'short');
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters.'),
          findsOneWidget);
    });

    testWidgets('rejects mismatched passwords', (tester) async {
      await pumpScreen(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'longenough1');
      await tester.enterText(fields.at(1), 'different99');
      await tester.tap(find.text('Update Password'));
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });
}
