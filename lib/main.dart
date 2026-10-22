import 'package:flutter/material.dart';
import 'app_navigator.dart';

import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_shell.dart';
import 'screens/maintenance_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/email_verified_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/account_deletion_pending_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/partner/doctor_dashboard.dart';
import 'screens/partner/hospital_dashboard.dart';
import 'screens/partner/lab_dashboard.dart';
import 'screens/partner/pharmacy_dashboard.dart';

/// Global navigator key: lets the auth listener route to the new-password
/// screen when a password-recovery link is opened, from anywhere.


void main() {
  runApp(
    AppStateScope(
      state: AppState(),
      child: const RemedooApp(),
    ),
  );
}

class RemedooApp extends StatelessWidget {
  const RemedooApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return MaterialApp(
      title: 'Remedoo - Patient Health App',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: RemedooTheme.light(),
      darkTheme: RemedooTheme.dark(),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const RootGate(),
    );
  }
}

/// Splash -> onboarding -> login -> main shell (or maintenance).
///
/// Waits for Supabase auth init (session restore) before routing, so a
/// persisted session lands straight in the app with no login flash.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _splashDone = false;
  bool _authReady = false;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    final state = AppStateScope.of(context);
    state.onPasswordRecovery = _goToPasswordReset;
    state.onEmailConfirmation = _goToEmailVerified;
    // Boot Supabase (persisted session restore + auth-link handling),
    // then attach the auth listener. Never throws: offline falls back
    // to the login/guest flow.
    Future(() async {
      await AuthService.instance.init();
      await state.loadPersistedState();
      await state.attachAuthListener();
      // No forced login screen: anyone without a session enters as a guest
      // and lands straight on the dashboard. The login screen only appears
      // when a gated action requires it.
      if (!state.isLoggedIn) {
        state.loginAsGuest();
      } else if (AuthService.instance.currentSession?.user != null) {
        // Returning session: restore the backend role (admin /
        // provider / patient) so RootGate routes to the right shell
        // instead of dropping providers into the patient view.
        await state.resolveBackendRole();
        // And check whether this account ever finished signup: a
        // confirmation-link landing creates the session before Step 2
        // (name + password) was ever shown.
        await state.resolveProfileCompleteness();
      }
      if (mounted) setState(() => _authReady = true);
    });
  }

  @override
  void dispose() {
    try {
      AppStateScope.of(context).onPasswordRecovery = null;
      AppStateScope.of(context).onEmailConfirmation = null;
    } catch (_) {}
    super.dispose();
  }

  void _goToPasswordReset() {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  }

  void _goToEmailVerified() {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const EmailVerifiedScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.maintenanceMode) return const MaintenanceScreen();
    if (!_splashDone || !_authReady) return const SplashView();
    if (!state.seenOnboarding) return const OnboardingScreen();
    // Deletion gate (owner order 2026-10-22): an account scheduled
    // for deletion opens nothing of the app — only the deletion page
    // with its erase time and the support reactivation request.
    if (state.deletionPending) {
      return const AccountDeletionPendingScreen();
    }
    if (state.role == 'admin' || state.role == 'staff') {
      return const AdminShell();
    }
    // Provider accounts land in their own dashboard, not the
    // patient app (same routing as the partner app).
    switch (state.role) {
      case 'doctor':
        return const DoctorDashboard();
      case 'pharmacy':
        return const PharmacyDashboard();
      case 'lab':
        return const LabDashboard();
      case 'hospital':
        return const HospitalDashboard();
    }
    // Signup-completion gate: a signed-in patient account that never
    // finished Step 2 (no name on the profile — e.g. it confirmed via
    // the email link, which creates the session directly) completes
    // it here before reaching the dashboard. Password recovery is not
    // affected: its screen is pushed above this gate by
    // _goToPasswordReset, exactly as before.
    if (state.isSignedIn && !state.profileComplete) {
      return const SignupScreen(resumeIncompleteSignup: true);
    }
    return const MainShell();
  }
}
