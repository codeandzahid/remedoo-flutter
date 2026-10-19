import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'favorites_screen.dart';
import 'hospitals_screen.dart';
import 'labs_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'pharmacies_screen.dart';
import 'profile_screen.dart';
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

    // Tablets and desktop/TV: the Remidy interface — a white pill
    // top bar (logo, nav pills, support, avatar) and NO sidebar.
    return Scaffold(
      body: Column(
        children: [
          _pillTopBar(context, state),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: IndexedStack(
                key: ValueKey<int>(_index),
                index: _index,
                children: _pages,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _supportFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// White pill navigation bar for the main website (tablet/desktop):
  /// primary logo tile + 'Remedoo', the seven sections as pills
  /// (active = filled primary pill), support button and avatar.
  Widget _pillTopBar(BuildContext context, AppState state) {
    final dests = _destinations(state);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: RemedooTheme.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Center(
                  child: Text('R',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 9),
              const Text('Remedoo',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < dests.length; i++)
                        _navPill(context, dests[i], i),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Support',
                icon: Badge(
                  isLabelVisible: state.supportUnreadCount > 0,
                  label: Text('${state.supportUnreadCount}'),
                  child: Icon(Icons.support_agent,
                      color: scheme.onSurface),
                ),
                onPressed: () {
                  if (!checkLogin(
                      context, 'Please login to access support')) {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SupportTicketsScreen()),
                  );
                },
              ),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: () {
                  if (state.isSignedIn) {
                    pushPage(context, const ProfileScreen());
                  } else {
                    pushPage(context, const LoginScreen());
                  }
                },
                child: RAvatarCircle(
                  name: state.isSignedIn ? state.userName : 'Guest',
                  size: 38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navPill(BuildContext context, NavDestinationItem d, int i) {
    final active = i == _index;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _switchTab(i),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color:
                active ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? (d.selectedIcon ?? d.icon) : d.icon,
                size: 17,
                color: active ? Colors.white : scheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                d.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : scheme.onSurface,
                ),
              ),
              if (d.badgeLabel != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFD1A54),
                    borderRadius:
                        BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    d.badgeLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
