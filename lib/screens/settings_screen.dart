import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'profile_screen.dart';
import 'appointments_screen.dart';
import 'orders_screen.dart';
import 'medical_history_screen.dart';
import 'favorites_screen.dart';
import 'refund_tracking_screen.dart';
import 'roles/doctor_portal_screen.dart';
import 'roles/driver_portal_screen.dart';
import 'roles/pharmacy_portal_screen.dart';
import 'roles/lab_portal_screen.dart';
import 'roles/hospital_portal_screen.dart';

/// Settings: profile, history links, preferences, about, logout.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: MaxWidthBox(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: InitialsAvatar(
                    name: state.displayName, radius: 24),
                title: Text(state.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
                subtitle: Text(state.userEmail ?? 'Guest',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(
                    Icons.arrow_forward_ios, size: 18),
                onTap: () =>
                    pushPage(context, const ProfileScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _row(context, Icons.calendar_month,
                'My Appointments',
                () => _go(context, const AppointmentsScreen())),
            _row(context, Icons.shopping_bag, 'My Orders',
                () => _go(context, const OrdersScreen())),
            _row(context, Icons.history, 'Medical History',
                () => _go(context, const MedicalHistoryScreen())),
            _row(context, Icons.favorite, 'My Favorites',
                () => _go(context, const FavoritesScreen())),
            _row(context, Icons.replay, 'Refund Status',
                () => _go(context, const RefundTrackingScreen())),
            _row(context, Icons.swap_horiz, 'Switch role (demo)',
                () => _roleDialog(context, state)),
            const SizedBox(height: 12),
            const Text('Preferences',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: state.darkMode,
                    onChanged: state.setDarkMode,
                    title: const Text('Dark Mode'),
                    secondary: const Icon(
                        Icons.dark_mode_outlined,
                        color: RemedooTheme.primary),
                  ),
                  SwitchListTile(
                    value: state.notificationsEnabled,
                    onChanged: state.setNotificationsEnabled,
                    title: const Text('Notifications'),
                    secondary: const Icon(
                        Icons.notifications_outlined,
                        color: RemedooTheme.primary),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language,
                        color: RemedooTheme.primary),
                    title: const Text('Language'),
                    trailing: DropdownButton<String>(
                      value: state.language,
                      underline: const SizedBox.shrink(),
                      items: const ['English', 'Hindi', 'Urdu']
                          .map((l) => DropdownMenuItem(
                              value: l, child: Text(l)))
                          .toList(),
                      onChanged: (v) =>
                          state.setLanguage(v ?? 'English'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _row(
                context,
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                () => _infoDialog(
                    context,
                    'Privacy Policy',
                    'Your health data is encrypted and never shared without your consent. (demo policy text)')),
            _row(
                context,
                Icons.info_outline,
                'About',
                () => _infoDialog(
                    context,
                    'About Remedoo',
                    'Remedoo v1.0.0\nYour Health, Our Priority.\n\nBook doctors, hospitals, labs and medicines in one app.')),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: RemedooTheme.emergency),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Log out?',
                  message:
                      'You will be signed out of Remedoo.',
                  confirmLabel: 'Log Out',
                );
                if (ok) state.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('Remedoo v1.0.0',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget page) {
    pushPage(context, page);
  }

  Widget _row(BuildContext context, IconData icon, String label,
      VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: RemedooTheme.primary),
        title: Text(label,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  void _infoDialog(
      BuildContext context, String title, String body) {
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _roleDialog(BuildContext context, AppState state) {
    final roles = {
      'patient': 'Patient',
      'doctor': 'Doctor Portal',
      'driver': 'Driver Portal',
      'pharmacy': 'Pharmacy Portal',
      'lab': 'Lab Portal',
      'hospital': 'Hospital Portal',
    };
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: const Text('Switch role (demo)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.entries.map((e) {
            return ListTile(
              title: Text(e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: state.role == e.key
                  ? const Icon(Icons.check,
                      color: RemedooTheme.primary)
                  : null,
              onTap: () {
                Navigator.pop(context);
                state.switchRole(e.key);
                _openPortal(context, e.key);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openPortal(BuildContext context, String role) {
    Widget? page;
    switch (role) {
      case 'doctor':
        page = const DoctorPortalScreen();
      case 'driver':
        page = const DriverPortalScreen();
      case 'pharmacy':
        page = const PharmacyPortalScreen();
      case 'lab':
        page = const LabPortalScreen();
      case 'hospital':
        page = const HospitalPortalScreen();
    }
    if (page != null) {
      pushPage(context, page);
    }
  }
}
