import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

/// Shown when a signup email-confirmation link ("Verify
/// automatically" / "Confirm email address") lands back in the app
/// and a session results: the email IS verified, and the user should
/// be told so before anything else happens (RootGate pushes this
/// above its normal routing, the same way the recovery return pushes
/// ResetPasswordScreen).
///
/// Continue routing follows the owner's order — after verifying, the
/// user signs in properly:
///  - a COMPLETE account (it has a password) → the link-created
///    session is ended and the patient login (Welcome Back) screen
///    is shown;
///  - an INCOMPLETE account (the OTP-signup route, Step 2 never ran,
///    so no password exists yet) → login would be impossible and the
///    user stranded, so Continue hands over to RootGate, which is
///    already showing the Step 2 completion screen underneath; the
///    button reads "Finish Your Account" in that case.
class EmailVerifiedScreen extends StatelessWidget {
  const EmailVerifiedScreen({super.key});

  void _continue(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.profileComplete) {
      // Incomplete account: keep the session (Step 2 completes the
      // SAME account through it) and simply reveal RootGate's
      // completion gate under this pushed screen.
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    // Complete account: end the link-created session, then put the
    // login screen on top of the guest home RootGate settles into.
    // logout() itself pops pushed routes back to RootGate, so the
    // login push must go through the root navigator afterwards.
    state.logout();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final finishAccount = !state.profileComplete;
    return Scaffold(
      body: MaxWidthBox(
        maxWidth: 480,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header with rounded bottom (same shape as the other
            // auth-flow screens).
            Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 60),
              decoration: BoxDecoration(
                gradient: RemedooTheme.headerGradient,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Email Verified',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Verification complete',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Card overlapping the header.
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: RemedooTheme.success
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: RemedooTheme.success,
                            size: 52,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Email verified ✅',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your email address has been verified '
                        'successfully.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      RButton(
                        label: finishAccount
                            ? 'Finish Your Account'
                            : 'Continue to Login',
                        fullWidth: true,
                        onPressed: () => _continue(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
