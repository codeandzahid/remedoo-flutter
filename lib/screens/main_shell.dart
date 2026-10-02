import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'emergency_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'orders_screen.dart';
import 'pharmacies_screen.dart';

/// Adaptive shell: bottom bar on phones, rail on tablets, drawer on desktop.
/// Tabs: Home, Doctors, Hospitals, Labs, Pharmacy, Orders.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  List<NavDestinationItem> _destinations(AppState state) => [
        const NavDestinationItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Home',
        ),
        const NavDestinationItem(
          icon: Icons.person_search_outlined,
          selectedIcon: Icons.person_search,
          label: 'Doctors',
        ),
        const NavDestinationItem(
          icon: Icons.local_hospital_outlined,
          selectedIcon: Icons.local_hospital,
          label: 'Hospitals',
        ),
        const NavDestinationItem(
          icon: Icons.science_outlined,
          selectedIcon: Icons.science,
          label: 'Labs',
        ),
        NavDestinationItem(
          icon: Icons.medication_outlined,
          selectedIcon: Icons.medication,
          label: 'Pharmacy',
          badgeLabel: state.cartCount > 0 ? '${state.cartCount}' : null,
        ),
        const NavDestinationItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Orders',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return ResponsiveScaffold(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      sections: [NavSection('', _destinations(state))],
      pages: const [
        DashboardScreen(),
        DoctorsScreen(),
        HospitalsScreen(),
        LabsScreen(),
        PharmaciesScreen(),
        OrdersScreen(),
      ],
      drawerHeader: _drawerHeader(context),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: RemedooTheme.emergency,
        foregroundColor: Colors.white,
        onPressed: () => pushPage(context, const EmergencyScreen()),
        icon: const Icon(Icons.sos),
        label: const Text('SOS',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _drawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      alignment: Alignment.centerLeft,
      child: const Row(
        children: [
          RemedooLogo(size: 40),
          SizedBox(width: 12),
          Text('Remedoo',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: RemedooTheme.ink)),
        ],
      ),
    );
  }
}
