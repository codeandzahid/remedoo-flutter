import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'orders_screen.dart';
import 'pharmacies_screen.dart';

/// Adaptive shell: floating white bottom bar on phones (the React 5-tab set:
/// Home / Hospitals / Labs / Pharmacy / Orders), rail on tablets, permanent
/// side drawer on desktop/TV. Orange circular support FAB, bottom-right.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  static const _pages = [
    DashboardScreen(),
    DoctorsScreen(),
    HospitalsScreen(),
    LabsScreen(),
    PharmaciesScreen(),
    OrdersScreen(),
  ];

  /// The phone bottom bar mirrors the React BottomNav's 5 tabs, so the
  /// Doctors page (index 1) has no tab — it stays reachable from the
  /// dashboard service grid and drawer.
  static const _navToPage = [0, 2, 3, 4, 5];

  static int _navIndexFor(int page) {
    final i = _navToPage.indexOf(page);
    return i < 0 ? 0 : i;
  }

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

  Widget _supportFab(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: RemedooTheme.primary,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      tooltip: 'Support',
      onPressed: () => showHelpDialog(context),
      child: const Icon(Icons.support_agent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    // Phones: floating white rounded bottom bar (React look) + orange
    // circular support FAB. Same AnimatedSwitcher/IndexedStack tab logic as
    // ResponsiveScaffold, so the drawer fix and routes are untouched.
    if (context.isCompact) {
      return Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: IndexedStack(
            key: ValueKey<int>(_index),
            index: _index,
            children: _pages,
          ),
        ),
        bottomNavigationBar: RBottomNav(
          currentIndex: _navIndexFor(_index),
          onTap: (i) => setState(() => _index = _navToPage[i]),
        ),
        floatingActionButton: _supportFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    // Tablets (rail) and desktop/TV (permanent side drawer).
    return ResponsiveScaffold(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      sections: [NavSection('', _destinations(state))],
      pages: _pages,
      drawerHeader: _drawerHeader(context),
      floatingActionButton: _supportFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _drawerHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          RemedooLogo(size: 40),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Remedoo',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
              Text('Care, on demand',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: RemedooTheme.primary)),
            ],
          ),
        ],
      ),
    );
  }
}
