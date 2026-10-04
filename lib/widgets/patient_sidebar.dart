import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'widgets.dart';
import '../screens/appointments_screen.dart';
import '../screens/emergency_screen.dart';
import '../screens/family_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/login_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/settings_screen.dart';
class _NavDef {
  final String title;
  final IconData icon;
  final String route;

  /// Null page = already there (Home): tapping just closes the drawer.
  final Widget Function()? page;

  /// When true, guests see the item but tapping it asks them to sign in
  /// instead of opening the page.
  final bool requiresLogin;

  const _NavDef(this.title, this.icon, this.route, this.page,
      {this.requiresLogin = false});
}

/// The React sidebar's Navigate section, mapped to the Flutter screens.
List<_NavDef> _patientNav() => const [
      _NavDef('Home', Icons.home_outlined, 'home', null),
      _NavDef('Appointments', Icons.calendar_month_outlined,
          'appointments', AppointmentsScreen.new,
          requiresLogin: true),
      _NavDef('Family Members', Icons.people_outline, 'family',
          FamilyScreen.new,
          requiresLogin: true),
      _NavDef('Health Reminders', Icons.notifications_outlined,
          'reminders', RemindersScreen.new,
          requiresLogin: true),
      _NavDef('Emergency', Icons.pin_drop_outlined, 'emergency',
          EmergencyScreen.new),
      _NavDef('Profile', Icons.person_outline, 'profile',
          ProfileScreen.new,
          requiresLogin: true),
      _NavDef('Settings', Icons.settings_outlined, 'settings',
          SettingsScreen.new,
          requiresLogin: true),
    ];

/// Patient profile header: avatar + name at the top of the sidebar.
/// Tapping opens the Profile screen (or login for guests).
class RSidebarProfileHeader extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(Widget page) onPush;

  const RSidebarProfileHeader({
    super.key,
    required this.onClose,
    required this.onPush,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final signedIn = state.isSignedIn;
    final name = signedIn ? state.userName : 'Guest';
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        onClose();
        if (signedIn) {
          onPush(const ProfileScreen());
        } else {
          onPush(const LoginScreen());
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.15),
              scheme.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            RAvatarCircle(name: name, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    signedIn ? 'Welcome back,' : 'Welcome,',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!signedIn)
                    Text(
                      'Tap to sign in',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Complete patient sidebar: gradient Close button, patient profile header
/// (avatar + name), and the Navigate section.
/// [onClose] dismisses the drawer; [onPush] pushes a page (called after the
/// drawer is closed, matching the React close-then-navigate behavior).
class RPatientSidebar extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(Widget page) onPush;
  final String activeRoute;
  final bool showCloseButton;

  const RPatientSidebar({
    super.key,
    required this.onClose,
    required this.onPush,
    this.activeRoute = 'home',
    this.showCloseButton = true,
  });

  void _go(Widget Function() builder) {
    onClose();
    onPush(builder());
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? RemedooTheme.darkCard : RemedooTheme.sidebarLight,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            if (showCloseButton) ...[
              RSidebarCloseButton(onPressed: onClose),
              const SizedBox(height: 24),
            ],
            RSidebarProfileHeader(
              onClose: onClose,
              onPush: onPush,
            ),
            const SizedBox(height: 24),
            const RSidebarGroupLabel('🧭 NAVIGATE'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  for (final item in _patientNav())
                    RSidebarNavTile(
                      icon: item.icon,
                      label: item.title,
                      active: activeRoute == item.route,
                      onTap: () {
                        if (item.requiresLogin &&
                            !checkLogin(context,
                                'Please login to access ${item.title.toLowerCase()}')) {
                          return;
                        }
                        final builder = item.page;
                        if (builder == null) {
                          onClose();
                        } else {
                          _go(builder);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
