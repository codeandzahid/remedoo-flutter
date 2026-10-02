import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/maintenance_screen.dart';
import 'screens/admin/admin_shell.dart';

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
      theme: RemedooTheme.light(state.brandPrimary),
      darkTheme: RemedooTheme.dark(state.brandPrimary),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const RootGate(),
    );
  }
}

/// Splash -> onboarding -> login -> main shell (or maintenance).
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.maintenanceMode) return const MaintenanceScreen();
    if (!_splashDone) return const SplashView();
    if (!state.seenOnboarding) return const OnboardingScreen();
    if (!state.isLoggedIn) return const LoginScreen();
    if (state.role == 'admin') return const AdminShell();
    return const MainShell();
  }
}
