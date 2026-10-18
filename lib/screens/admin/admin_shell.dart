import 'package:flutter/material.dart';

import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/admin_style.dart';
import '../../widgets/widgets.dart';
import 'admin_style_screen.dart';
import 'admin_crud_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_approvals_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_appointments_screen.dart';
import 'admin_emergencies_screen.dart';
import 'admin_support_tickets_screen.dart';
import 'admin_reviews_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_revenue_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_config_screens.dart';
import 'admin_ops_screens.dart';
import 'admin_payments_screen.dart';
import 'admin_remedoo_pay_screen.dart';
import 'admin_app_settings_screen.dart';
import 'admin_users_screen.dart';
import 'admin_team_screen.dart';
import 'admin_export_screen.dart';

class _NavItem {
  final String section;
  final String label;
  final IconData icon;
  final Widget Function(AppState) builder;

  const _NavItem(this.section, this.label, this.icon, this.builder);
}

List<_NavItem> _items(AppState s, void Function(int) onNavigate) => [
      // Overview
      _NavItem('Overview', 'Dashboard', Icons.dashboard,
          (_) => AdminDashboardScreen(onNavigate: onNavigate)),
      // Catalog — every listing users see, all backed by Supabase
      _NavItem('Catalog', 'Doctors', Icons.person_search,
          (_) => const AdminTableScreen(table: 'doctors', title: 'Doctors', singular: 'Doctor')),
      _NavItem('Catalog', 'Hospitals', Icons.local_hospital,
          (_) => const AdminTableScreen(table: 'hospitals', title: 'Hospitals', singular: 'Hospital')),
      _NavItem('Catalog', 'Labs', Icons.science,
          (_) => const AdminTableScreen(table: 'labs', title: 'Labs', singular: 'Lab')),
      _NavItem('Catalog', 'Lab Tests', Icons.biotech,
          (_) => const AdminTableScreen(table: 'lab_tests', title: 'Lab Tests', singular: 'Lab Test')),
      _NavItem('Catalog', 'Pharmacies', Icons.storefront,
          (_) => const AdminTableScreen(table: 'pharmacies', title: 'Pharmacies', singular: 'Pharmacy')),
      _NavItem('Catalog', 'Medicines', Icons.medication,
          (_) => const AdminTableScreen(table: 'medicines', title: 'Medicines', singular: 'Medicine')),
      _NavItem('Catalog', 'Inventory', Icons.inventory,
          (_) => const AdminInventoryScreen()),
      // Providers
      _NavItem('Providers', 'Applications', Icons.approval,
          (_) => const AdminApprovalsScreen()),
      _NavItem('Providers', 'Payments (UPI)', Icons.qr_code,
          (_) => const AdminProviderPaymentsScreen()),
      _NavItem('Providers', 'Reviews', Icons.star,
          (_) => const AdminReviewsScreen()),
      // Orders & Care
      _NavItem('Orders & Care', 'Orders', Icons.shopping_bag,
          (_) => const AdminOrdersScreen()),
      _NavItem('Orders & Care', 'Appointments', Icons.calendar_month,
          (_) => const AdminAppointmentsScreen()),
      _NavItem('Orders & Care', 'Refunds', Icons.replay,
          (_) => const AdminRefundsScreen()),
      _NavItem('Orders & Care', 'Emergencies', Icons.sos,
          (_) => const AdminEmergenciesScreen()),
      _NavItem('Orders & Care', 'Ambulance', Icons.emergency,
          (_) => const AdminAmbulanceScreen()),
      _NavItem('Orders & Care', 'Support Tickets', Icons.support_agent,
          (_) => const AdminSupportTicketsScreen()),
      // Content — announcements appear in the app for users
      _NavItem('Content', 'Announcements', Icons.campaign,
          (_) => const AdminBroadcastScreen()),
      // Settings — all persisted to the app_config backend
      _NavItem('Settings', 'App Settings', Icons.settings,
          (_) => const AdminAppSettingsScreen()),
      _NavItem('Settings', 'Branding', Icons.palette,
          (_) => const BrandingScreen()),
      _NavItem('Settings', 'Commission', Icons.percent,
          (_) => const CommissionScreen()),
      _NavItem('Settings', 'Subscriptions', Icons.card_membership,
          (_) => const SubscriptionsScreen()),
      _NavItem('Settings', 'Corporate Plans', Icons.business,
          (_) => const CorporatePlansScreen()),
      _NavItem('Settings', 'Healthcare Packages', Icons.health_and_safety,
          (_) => const HealthcarePackagesScreen()),
      _NavItem('Settings', 'Service Areas', Icons.map,
          (_) => const ServiceAreasScreen()),
      _NavItem('Settings', 'Featured', Icons.star_border,
          (_) => const FeaturedScreen()),
      // Insights
      _NavItem('Insights', 'Revenue', Icons.trending_up,
          (_) => const AdminRevenueScreen()),
      _NavItem('Insights', 'Analytics', Icons.analytics,
          (_) => const AdminAnalyticsScreen()),
      _NavItem('Insights', 'Users', Icons.people,
          (_) => const AdminUsersScreen()),
      // Payments — Remedoo Pay management (own section, appended last
      // so existing section indexes used by the dashboard stay stable)
      _NavItem('Payments', 'Remedoo Pay', Icons.qr_code_2,
          (_) => const AdminRemedooPayScreen()),
      // Team — staff (employee admin) management, super admin only.
      _NavItem('Settings', 'Team', Icons.group,
          (_) => const AdminTeamScreen()),
      // Export Data — download project data (CSV / full backup JSON).
      _NavItem('Settings', 'Export Data', Icons.download,
          (_) => const AdminExportScreen()),
      // Panel Style — switch the admin UI style (owner order
      // 2026-10-18: try every style one by one, live).
      _NavItem('Settings', 'Panel Style', Icons.style,
          (s) => AdminStyleScreen(state: s)),
    ];

/// Permission key per nav item, aligned with [_items] by index.
/// The super admin (role 'admin') sees everything. Staff accounts see
/// only the items whose key the super admin ticked for them in
/// Admin > Team ('team' itself is never visible to staff).
const _permKeys = [
  'dashboard', 'doctors', 'hospitals', 'labs', 'lab_tests', 'pharmacies',
  'medicines', 'inventory', 'applications', 'provider_payments',
  'reviews', 'orders', 'appointments', 'refunds', 'emergencies',
  'ambulance', 'support', 'announcements', 'settings', 'branding',
  'commission', 'subscriptions', 'corporate', 'packages',
  'service_areas', 'featured', 'revenue', 'analytics', 'users',
  'remedoo_pay', 'team', 'export_data', 'panel_style',
];

/// Admin console shell: light sidebar nav (desktop) / drawer (phone, tablet),
/// top app bar with the current page title.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  List<_NavItem> _allItems = const [];
  List<_NavItem> _visibleItems = const [];

  void _go(int i) {
    setState(() => _index = i);
  }

  /// Dashboard cards navigate by ABSOLUTE item index; translate to the
  /// visible (permission-filtered) index. Hidden items do nothing.
  void _goAbs(int abs) {
    if (abs < 0 || abs >= _allItems.length) return;
    final vi = _visibleItems.indexOf(_allItems[abs]);
    if (vi >= 0) setState(() => _index = vi);
  }

  Future<void> _logout(AppState state) async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the admin console?',
      confirmLabel: 'Log Out',
    );
    if (ok && context.mounted) {
      // RootGate switches back to the login screen automatically.
      state.switchRole('patient');
      state.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final all = _items(state, _goAbs);
    final items = state.isAdmin
        ? all
        : all
            .where((it) {
              final key = _permKeys[all.indexOf(it)];
              if (key == 'team') return false;
              return state.staffSections.contains(key);
            })
            .toList();
    _allItems = all;
    _visibleItems = items;
    if (items.isEmpty) {
      return _styleWrap(
        state.adminStyle,
        Scaffold(
          appBar: _topBar('Admin Console', state, state.adminStyle),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No sections are assigned to your account yet.\n'
                'Ask the super admin to give you access in Admin > Team.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    final safeIndex = _index.clamp(0, items.length - 1);
    final current = items[safeIndex];
    final page = IndexedStack(
      index: safeIndex,
      children: [for (final it in items) it.builder(state)],
    );
    final style = state.adminStyle;
    final floating = style.floating;

    if (style.topNav) {
      return _styleWrap(
        style,
        _topNavScaffold(state, items, current, page),
      );
    }

    if (context.isDesktop) {
      return _styleWrap(
        style,
        Scaffold(
          appBar: _topBar(current.label, state, style),
          body: floating
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sideNav(state, items, style),
                      const SizedBox(width: 16),
                      Expanded(child: _workspace(page, style)),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sideNav(state, items, style),
                    Expanded(child: page),
                  ],
                ),
        ),
      );
    }
    return _styleWrap(
      style,
      Scaffold(
        appBar: _topBar(current.label, state, style),
        drawer: Drawer(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration:
                  adminDecoration(context, style, radius: 26, depth: 2),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _navColumn(state, items, inDrawer: true),
                ),
              ),
            ),
          ),
        ),
        body: floating
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                child: _workspace(page, style),
              )
            : page,
      ),
    );
  }

  /// The workspace slab for floating styles: the page floats as
  /// one surface in front of the environment (depth 1), clipped
  /// to its corners.
  Widget _workspace(Widget page, AdminStyle style) {
    return Container(
      decoration: adminDecoration(context, style, radius: 28, depth: 1),
      clipBehavior: Clip.antiAlias,
      child: page,
    );
  }

  // ── Remidy (topNav) chrome — the Cognify layout the owner
  // picked: NO sidebar; a white pill bar with a black logo tile,
  // group tab pills (active = black), and a second pill row with
  // the active group's pages. Mobile keeps a white drawer.

  List<String> _sectionsOf(List<_NavItem> items) {
    final out = <String>[];
    for (final it in items) {
      if (!out.contains(it.section)) out.add(it.section);
    }
    return out;
  }

  String _groupLabel(List<_NavItem> items, String section) {
    final g = items.where((e) => e.section == section).toList();
    if (g.length == 1) return g.first.label;
    return section == 'Overview' ? 'Dashboard' : section;
  }

  Widget _topNavScaffold(
    AppState state,
    List<_NavItem> items,
    _NavItem current,
    Widget page,
  ) {
    final desktop = context.isDesktop;
    final sections = _sectionsOf(items);
    final groupItems =
        items.where((it) => it.section == current.section).toList();
    return Scaffold(
      drawer: desktop
          ? null
          : Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(
                child: _navColumn(state, items, inDrawer: true),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: desktop
                  ? _navPillDesktop(state, items, sections, current)
                  : _navPillMobile(state, current),
            ),
            if (desktop && groupItems.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _itemsPill(items, groupItems, current),
              ),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }

  Widget _logoMark({bool small = false}) {
    final s = small ? 34.0 : 38.0;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const Text(
        'R',
        style: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFEEF0F2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF141414)),
        ),
      ),
    );
  }

  Widget _navPillDesktop(
    AppState state,
    List<_NavItem> items,
    List<String> sections,
    _NavItem current,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          adminDecoration(context, AdminStyle.remedoo, radius: 28, depth: 2),
      child: Row(
        children: [
          _logoMark(),
          const SizedBox(width: 10),
          const Text(
            'Remedoo',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF141414),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in sections) _groupPill(items, s, current),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _circleButton(Icons.logout, 'Log out', () => _logout(state)),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFF141414),
            child: Icon(Icons.person, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _navPillMobile(AppState state, _NavItem current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration:
          adminDecoration(context, AdminStyle.remedoo, radius: 24, depth: 2),
      child: Row(
        children: [
          _logoMark(small: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              current.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF141414),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Builder(
            builder: (ctx) => _circleButton(
              Icons.menu,
              'Menu',
              () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const SizedBox(width: 8),
          _circleButton(Icons.logout, 'Log out', () => _logout(state)),
        ],
      ),
    );
  }

  Widget _groupPill(
      List<_NavItem> items, String section, _NavItem current) {
    final active = section == current.section;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          final idx = items.indexWhere((it) => it.section == section);
          if (idx >= 0) setState(() => _index = idx);
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF141414)
                : const Color(0xFFEEF0F2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _groupLabel(items, section),
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF141414),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemsPill(
    List<_NavItem> items,
    List<_NavItem> groupItems,
    _NavItem current,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration:
          adminDecoration(context, AdminStyle.remedoo, radius: 24, depth: 1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in groupItems)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () =>
                      setState(() => _index = items.indexOf(it)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: it == current
                          ? const Color(0xFF141414)
                          : const Color(0xFFEEF0F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          it.icon,
                          size: 15,
                          color: it == current
                              ? Colors.white
                              : const Color(0xFF141414),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          it.label,
                          style: TextStyle(
                            color: it == current
                                ? Colors.white
                                : const Color(0xFF141414),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Style wrapper: the style's backdrop behind a transparent
  /// scaffold, an AdminScope so shared widgets render the style's
  /// surfaces, and the style's component theme.
  Widget _styleWrap(AdminStyle style, Widget scaffold) {
    return AdminScope(
      style: style,
      child: Theme(
        data: adminTheme(context, style),
        child: Stack(
          children: [
            Positioned.fill(child: AdminBackdrop(style)),
            scaffold,
          ],
        ),
      ),
    );
  }
  PreferredSizeWidget _topBar(
      String title, AppState state, AdminStyle style) {
    return AppBar(
      toolbarHeight: style.floating ? 76 : null,
      title: Text(title),
      flexibleSpace: style.floating
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Container(
                decoration:
                    adminDecoration(context, style, radius: 20, depth: 2),
              ),
            )
          : Container(decoration: adminBarDecoration(context, style)),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: () => _logout(state),
        ),
      ],
    );
  }

  /// Permanent light sidebar for desktop: gradient brand header, sectioned
  /// nav in the React sidebar's visual language, sign-out footer.
  Widget _sideNav(AppState state, List<_NavItem> items, AdminStyle style) {
    return Container(
      width: 288,
      decoration: style.floating
          ? adminDecoration(context, style, radius: 28, depth: 2)
          : adminSidebarDecoration(context, style),
      child: Column(
        children: [
          _brandHeader(),
          Expanded(
            child: _navList(state, items),
          ),
          _sideFooter(state),
        ],
      ),
    );
  }

  /// Gradient brand banner (rounded-2xl orange gradient, white text) —
  /// the admin counterpart of the React sidebar's gradient Close button.
  Widget _brandHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFDB2777),
              Color(0xFF7C3AED),
              Color(0xFF2563EB),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Remedoo',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                Text('Admin Console',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navList(AppState state, List<_NavItem> items) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      children: _sectionedNav(items),
    );
  }

  Widget _navColumn(AppState state, List<_NavItem> items,
      {bool inDrawer = false}) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          if (inDrawer) ...[
            const SizedBox(height: 20),
            RSidebarCloseButton(
                onPressed: () => Navigator.of(context).pop()),
            const SizedBox(height: 16),
          ],
          _brandHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              children: _sectionedNav(items, onTap: () {
                if (inDrawer) Navigator.of(context).pop();
              }),
            ),
          ),
          _sideFooter(state),
        ],
      ),
    );
  }

  List<Widget> _sectionedNav(List<_NavItem> items,
      {VoidCallback? onTap}) {
    final out = <Widget>[];
    String? lastSection;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.section != lastSection) {
        lastSection = it.section;
        out.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
          child: RSidebarGroupLabel(it.section.toUpperCase()),
        ));
      }
      out.add(RSidebarNavTile(
        icon: it.icon,
        label: it.label,
        active: i == _index,
        onTap: () {
          _go(i);
          onTap?.call();
        },
      ));
    }
    return out;
  }

  Widget _sideFooter(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              state.isAdmin ? 'SUPER ADMIN' : 'STAFF ACCOUNT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _logout(state),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        size: 20, color: RemedooTheme.destructive),
                    SizedBox(width: 12),
                    Text('Sign Out',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: RemedooTheme.destructive)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
