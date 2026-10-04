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
import 'screens/admin/admin_shell.dart';

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
    // Boot Supabase (persisted session restore + auth-link handling),
    // then attach the auth listener. Never throws: offline falls back
    // to the login/guest flow.
    Future(() async {
      await AuthService.instance.init();
      await state.loadPersistedState();
      state.attachAuthListener();
      // No forced login screen: anyone without a session enters as a guest
      // and lands straight on the dashboard. The login screen only appears
      // when a gated action requires it.
      if (!state.isLoggedIn) state.loginAsGuest();
      if (mounted) setState(() => _authReady = true);
    });
  }

  @override
  void dispose() {
    try {
      AppStateScope.of(context).onPasswordRecovery = null;
    } catch (_) {}
    super.dispose();
  }

  void _goToPasswordReset() {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.maintenanceMode) return const MaintenanceScreen();
    if (!_splashDone || !_authReady) return const SplashView();
    if (!state.seenOnboarding) return const OnboardingScreen();
    if (state.role == 'admin') return const AdminShell();
    return const MainShell();
  }
}
