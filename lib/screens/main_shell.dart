import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'favorites_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'orders_screen.dart';
import 'pharmacies_screen.dart';
import 'support_tickets_screen.dart';

/// Adaptive shell: floating white bottom bar on phones (6 tabs:
/// Home / Doctors / Hospitals / Labs / Pharmacy / Orders), rail on tablets,
/// permanent side drawer on desktop/TV (adds Favorites after Orders).
/// Orange circular support FAB, bottom-right.
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
    FavoritesScreen(),
  ];

  /// The phone bottom bar now has 6 tabs: Home, Doctors, Hospitals, Labs,
  /// Pharmacy, Orders — matching the page order directly.
  static const _navToPage = [0, 1, 2, 3, 4, 5];

  static int _navIndexFor(int page) {
    final i = _navToPage.indexOf(page);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  DateTime? _lastBackPress;

  /// On web, browsers ignore programmatic tab-close: the second back press
  /// arms exit, and the next back press is let through to the browser.
  bool _allowExit = false;

  /// System back button: while browsing, back walks to the dashboard first
  /// (never exits from a non-home tab). On the dashboard, the first press
  /// shows "press again to exit"; a second press within 2s exits.
  void _onSystemBack(bool didPop, Object? result) {
    if (didPop) {
      _allowExit = false;
      return;
    }
    // Not on the home tab: back goes to the dashboard, not out of the app.
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      _lastBackPress = null;
      if (kIsWeb) {
        // Arm exit: the next back press goes through to the browser.
        setState(() => _allowExit = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back once more to leave'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        SystemNavigator.pop();
      }
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Reference-style tab switch: guests get the login toast + redirect when
  /// heading to a gated page (Orders). Must run before setState — the
  /// IndexedStack builds every page eagerly, so the gate cannot live in the
  /// page's own initState.
  void _switchTab(int pageIndex) {
    if (pageIndex == 5 || pageIndex == 6) {
      if (!checkLogin(context)) return;
    }
    setState(() => _index = pageIndex);
  }

  /// Drawer navigation with the reference-style guest gate: toast + redirect
  /// to login for Favorites, Orders, Appointments, Family, Reminders, Profile.

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
        const NavDestinationItem(
          icon: Icons.favorite_outline,
          selectedIcon: Icons.favorite,
          label: 'Favorites',
        ),
      ];

  Widget _supportFab(BuildContext context) {
    final state = AppStateScope.of(context);
    final unread = state.supportUnreadCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          backgroundColor: RemedooTheme.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          tooltip: 'Support',
          onPressed: () {
            if (!checkLogin(context, 'Please login to access support')) {
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SupportTicketsScreen()),
            );
          },
          child: const Icon(Icons.support_agent),
        ),
        if (unread > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: _onSystemBack,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
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
