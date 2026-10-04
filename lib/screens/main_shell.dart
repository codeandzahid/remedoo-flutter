import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../responsive/animations.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/patient_sidebar.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'orders_screen.dart';
import 'pharmacies_screen.dart';
import 'favorites_screen.dart';
import 'appointments_screen.dart';
import 'family_screen.dart';
import 'reminders_screen.dart';
import 'profile_screen.dart';

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

  /// Reference-style tab switch: guests get the login toast + redirect when
  /// heading to a gated page (Orders). Must run before setState — the
  /// IndexedStack builds every page eagerly, so the gate cannot live in the
  /// page's own initState.
  void _switchTab(int pageIndex) {
    if (pageIndex == 5) {
      if (!checkLogin(context)) return;
    }
    setState(() => _index = pageIndex);
  }

  /// Drawer navigation with the reference-style guest gate: toast + redirect
  /// to login for Favorites, Orders, Appointments, Family, Reminders, Profile.
  void _pushDrawer(BuildContext context, Widget page) {
    if (page is FavoritesScreen ||
        page is OrdersScreen ||
        page is AppointmentsScreen ||
        page is FamilyScreen ||
        page is RemindersScreen ||
        page is ProfileScreen) {
      if (!checkLogin(context)) return;
    }
    pushPage(context, page);
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
      onPressed: () {
        if (!checkLogin(context, 'Please login to access support')) return;
        showHelpDialog(context);
      },
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
        bottomNavigationBar: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: state.drawerOpen
              ? const SizedBox.shrink(key: ValueKey('nav-hidden'))
              : RBottomNav(
                  key: const ValueKey('nav-visible'),
                  currentIndex: _navIndexFor(_index),
                  onTap: (i) => _switchTab(_navToPage[i]),
                ),
        ),
        floatingActionButton: _supportFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    // Tablets (rail) and desktop/TV (permanent side drawer, styled like the
    // React sidebar: quick-actions grid on top, React-style nav rows).
    return ResponsiveScaffold(
      selectedIndex: _index,
      onDestinationSelected: (i) => _switchTab(i),
      sections: [NavSection('', _destinations(state))],
      pages: _pages,
      drawerHeader: _drawerHeader(context),
      drawerLeading: RQuickActionsGrid(
        onPush: (page) => _pushDrawer(context, page),
      ),
      floatingActionButton: _supportFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _drawerHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, RemedooTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: RemedooLogo(size: 32),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Remedoo',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              Text('Care, on demand',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}
