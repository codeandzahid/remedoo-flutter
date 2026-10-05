import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'screens/partner/partner_login_screen.dart';
import 'screens/partner/doctor_dashboard.dart';
import 'screens/partner/pharmacy_dashboard.dart';
import 'screens/partner/lab_dashboard.dart';
import 'screens/partner/hospital_dashboard.dart';

/// Remedoo Partner entry point: `flutter build apk --target lib/main_partner.dart`
/// (or `--flavor partner`). Boots straight into the provider login —
// the dashboard shown depends on the provider's role.
void main() {
  runApp(
    AppStateScope(
      state: AppState(),
      child: const RemedooPartnerApp(),
    ),
  );
}

class RemedooPartnerApp extends StatelessWidget {
  const RemedooPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return MaterialApp(
      title: 'Remedoo Partner',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: RemedooTheme.light(),
      darkTheme: RemedooTheme.dark(),
      themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const PartnerRootGate(),
    );
  }
}

/// Shows the right dashboard for the signed-in provider's role,
/// otherwise the provider login screen.
class PartnerRootGate extends StatefulWidget {
  const PartnerRootGate({super.key});

  @override
  State<PartnerRootGate> createState() => _PartnerRootGateState();
}

class _PartnerRootGateState extends State<PartnerRootGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final state = AppStateScope.of(context);
    await AuthService.instance.init();
    await state.loadPersistedState();
    state.attachAuthListener();
    await state.checkProviderRole();
    if (state.providerRole != null) {
      state.switchRole(state.providerRole!);
    }
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
    if (state.isSignedIn) {
      switch (state.providerRole ?? state.role) {
        case 'doctor':
          return const DoctorDashboard();
        case 'pharmacy':
          return const PharmacyDashboard();
        case 'lab':
          return const LabDashboard();
        case 'hospital':
          return const HospitalDashboard();
      }
    }
    return const PartnerLoginScreen();
  }
}
