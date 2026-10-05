import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_shell.dart';

/// Admin-only entry point: `flutter build apk --target lib/main_admin.dart`
/// (or `--flavor admin`). Boots straight into the admin login — no patient
/// screens.
void main() {
  runApp(
    AppStateScope(
      state: AppState(),
      child: const RemedooAdminApp(),
    ),
  );
}

class RemedooAdminApp extends StatelessWidget {
  const RemedooAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return MaterialApp(
      title: 'Remedoo Admin',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: RemedooTheme.light(),
      darkTheme: RemedooTheme.dark(),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AdminRootGate(),
    );
  }
}

/// Shows the admin shell when signed in with the admin role,
/// otherwise the admin login screen. Rebuilds on auth/role changes.
class AdminRootGate extends StatefulWidget {
  const AdminRootGate({super.key});

  @override
  State<AdminRootGate> createState() => _AdminRootGateState();
}

class _AdminRootGateState extends State<AdminRootGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final state = AppStateScope.of(context);
    // Initialize Supabase first — the login screen needs the client.
    await AuthService.instance.init();
    await state.loadPersistedState();
    await state.checkAdminRole();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.isSignedIn && state.isAdmin) {
      return const AdminShell();
    }
    return const AdminLoginScreen(isRoot: true);
  }
}
