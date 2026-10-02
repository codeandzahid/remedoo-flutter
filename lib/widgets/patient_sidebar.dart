import 'package:flutter/material.dart';

import '../theme.dart';
import 'widgets.dart';
import '../screens/appointments_screen.dart';
import '../screens/doctors_screen.dart';
import '../screens/emergency_screen.dart';
import '../screens/family_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/pharmacies_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reminders_screen.dart';
import '../screens/settings_screen.dart';

/// A quick-action tile definition: gradient tile with emoji + label that
/// pushes a page. Mirrors the React AppSidebar `quickActions` list.
class QuickActionDef {
  final String title;
  final String emoji;
  final List<Color> gradient;
  final Widget Function() page;

  const QuickActionDef({
    required this.title,
    required this.emoji,
    required this.gradient,
    required this.page,
  });
}

/// The React sidebar's 5 quick actions (gradient color per action).
List<QuickActionDef> patientQuickActions() => [
      QuickActionDef(
        title: 'Book Appointment',
        emoji: '📅',
        gradient: [
          RemedooTheme.primary,
          RemedooTheme.primary.withValues(alpha: 0.8),
        ],
        page: () => const DoctorsScreen(),
      ),
      QuickActionDef(
        title: 'Emergency SOS',
        emoji: '🚨',
        gradient: [
          RemedooTheme.emergency,
          RemedooTheme.emergency.withValues(alpha: 0.8),
        ],
        page: () => const EmergencyScreen(),
      ),
      QuickActionDef(
        title: 'Order Medicines',
        emoji: '💊',
        gradient: [
          RemedooTheme.success,
          RemedooTheme.success.withValues(alpha: 0.8),
        ],
        page: () => const PharmaciesScreen(),
      ),
      QuickActionDef(
        title: 'Favorites',
        emoji: '❤️',
        gradient: [
          RemedooTheme.warning,
          RemedooTheme.warning.withValues(alpha: 0.8),
        ],
        page: () => const FavoritesScreen(),
      ),
      QuickActionDef(
        title: 'My Orders',
        emoji: '🛍️',
        gradient: [
          RemedooTheme.primary,
          RemedooTheme.success.withValues(alpha: 0.8),
        ],
        page: () => const OrdersScreen(),
      ),
    ];

/// "⚡ QUICK ACTIONS" label + 2-column gradient tile grid, as in the React
/// sidebar. Used both in the phone drawer and the desktop permanent drawer.
class RQuickActionsGrid extends StatelessWidget {
  final void Function(Widget page) onPush;

  const RQuickActionsGrid({super.key, required this.onPush});

  @override
  Widget build(BuildContext context) {
    final actions = patientQuickActions();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RSidebarGroupLabel('⚡ QUICK ACTIONS'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Taller than wide: the emoji + two-line label must fit
              // without overflowing at phone drawer widths.
              childAspectRatio: 1.25,
            ),
            itemCount: actions.length,
            itemBuilder: (c, i) {
              final a = actions[i];
              return RSidebarQuickTile(
                emoji: a.emoji,
                label: a.title,
                gradient: a.gradient,
                onTap: () => onPush(a.page()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NavDef {
  final String title;
  final IconData icon;
  final String route;

  /// Null page = already there (Home): tapping just closes the drawer.
  final Widget Function()? page;

  const _NavDef(this.title, this.icon, this.route, this.page);
}

/// The React sidebar's Navigate section, mapped to the Flutter screens.
List<_NavDef> _patientNav() => const [
      _NavDef('Home', Icons.home_outlined, 'home', null),
      _NavDef('Appointments', Icons.calendar_month_outlined,
          'appointments', AppointmentsScreen.new),
      _NavDef('Family Members', Icons.people_outline, 'family',
          FamilyScreen.new),
      _NavDef('Health Reminders', Icons.notifications_outlined,
          'reminders', RemindersScreen.new),
      _NavDef('Emergency', Icons.pin_drop_outlined, 'emergency',
          EmergencyScreen.new),
      _NavDef(
          'Profile', Icons.person_outline, 'profile', ProfileScreen.new),
      _NavDef('Settings', Icons.settings_outlined, 'settings',
          SettingsScreen.new),
    ];

/// Complete patient sidebar: gradient Close button, Quick Actions gradient
/// tile grid, and the Navigate section — 1:1 with the React AppSidebar.
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
            RQuickActionsGrid(onPush: (page) {
              onClose();
              onPush(page);
            }),
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
