import 'package:flutter/material.dart';

import '../state/app_state.dart';
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
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
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
            const RSidebarGroupLabel('NAVIGATE'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  for (final item in _patientNav())
                    _pillTile(
                      context,
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

  /// Remidy drawer row: a full-width pill — active page filled with
  /// the primary colour, the rest light grey.
  Widget _pillTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? Colors.white : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (active)
                const Icon(Icons.check, size: 15, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
