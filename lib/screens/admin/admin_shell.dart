import 'package:flutter/material.dart';

import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/nav_memory.dart';
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
import 'admin_account_deletion_screen.dart';
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
      // Users — every people directory in one section (owner order
      // 2026-10-22: arrange items section-wise, doctors/labs/etc.
      // inside Users).
      _NavItem('Users', 'Doctors', Icons.person_search,
          (_) => const AdminTableScreen(table: 'doctors', title: 'Doctors', singular: 'Doctor')),
      _NavItem('Users', 'Hospitals', Icons.local_hospital,
          (_) => const AdminTableScreen(table: 'hospitals', title: 'Hospitals', singular: 'Hospital')),
      _NavItem('Users', 'Labs', Icons.science,
          (_) => const AdminTableScreen(table: 'labs', title: 'Labs', singular: 'Lab')),
      _NavItem('Users', 'Pharmacies', Icons.storefront,
          (_) => const AdminTableScreen(table: 'pharmacies', title: 'Pharmacies', singular: 'Pharmacy')),
      _NavItem('Users', 'Users', Icons.people,
          (_) => const AdminUsersScreen()),
      // Catalog — things and sellable plans, not people. Corporate
      // Plans, Healthcare Packages and Subscriptions moved here
      // from Settings (sidebar rearrange, owner order 2026-10-23):
      // they are offerings, not app settings.
      _NavItem('Catalog', 'Lab Tests', Icons.biotech,
          (_) => const AdminTableScreen(table: 'lab_tests', title: 'Lab Tests', singular: 'Lab Test')),
      _NavItem('Catalog', 'Medicines', Icons.medication,
          (_) => const AdminTableScreen(table: 'medicines', title: 'Medicines', singular: 'Medicine')),
      _NavItem('Catalog', 'Inventory', Icons.inventory,
          (_) => const AdminInventoryScreen()),
      _NavItem('Catalog', 'Coupons', Icons.local_offer,
          (_) => const AdminTableScreen(table: 'coupons', title: 'Coupons', singular: 'Coupon')),
      _NavItem('Catalog', 'Corporate Plans', Icons.business,
          (_) => const CorporatePlansScreen()),
      _NavItem('Catalog', 'Healthcare Packages', Icons.health_and_safety,
          (_) => const HealthcarePackagesScreen()),
      _NavItem('Catalog', 'Subscriptions', Icons.card_membership,
          (_) => const SubscriptionsScreen()),
      // Providers — applications and reviews; Drivers added
      // 2026-10-23 (owner: 'add more if anything missing') — the
      // delivery_drivers table had no admin screen at all, so a
      // driver profile (needed before a driver can receive
      // deliveries) could never be created or checked here.
      _NavItem('Providers', 'Applications', Icons.approval,
          (_) => const AdminApprovalsScreen()),
      _NavItem('Providers', 'Reviews', Icons.star,
          (_) => const AdminReviewsScreen()),
      _NavItem('Providers', 'Drivers', Icons.delivery_dining,
          (_) => const AdminTableScreen(table: 'delivery_drivers', title: 'Drivers', singular: 'Driver')),
      // Payments — all money in one section (rearrange
      // 2026-10-23): Remedoo Pay plus the per-provider UPI
      // payments screen, which used to sit under Providers.
      _NavItem('Payments', 'Remedoo Pay', Icons.qr_code_2,
          (_) => const AdminRemedooPayScreen()),
      _NavItem('Payments', 'Payments (UPI)', Icons.qr_code,
          (_) => const AdminProviderPaymentsScreen()),
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
      // Support — its own section (owner order 2026-10-22): tickets,
      // chat (inside tickets) and the account-deletion queue. Staff
      // holding only 'support' land here and see nothing else.
      _NavItem('Support', 'Support Tickets', Icons.support_agent,
          (_) => const AdminSupportTicketsScreen()),
      _NavItem('Support', 'Account Deletion', Icons.schedule_outlined,
          (_) => const AdminAccountDeletionScreen()),
      // Support > Users (owner order 2026-10-23): support can add
      // users and manage them — active/inactive and change
      // details — without leaving the Support section. Same
      // screen as Users > Users, with the Add user button on.
      _NavItem('Support', 'Users', Icons.people_outline,
          (_) => const AdminUsersScreen(allowAddUser: true)),
      // Content — Announcements and Broadcasts side by side
      // (rearrange 2026-10-23: they were separated by four items
      // and easy to confuse).
      _NavItem('Content', 'Announcements', Icons.campaign,
          (_) => const AdminBroadcastScreen()),
      _NavItem('Content', 'Broadcasts', Icons.campaign_outlined,
          (_) => const BroadcastsScreen()),
      _NavItem('Content', 'FAQs', Icons.help_outline,
          (_) => const AdminTableScreen(table: 'faqs', title: 'FAQs', singular: 'FAQ')),
      _NavItem('Content', 'Legal Pages', Icons.gavel,
          (_) => const AdminTableScreen(table: 'legal_pages', title: 'Legal Pages', singular: 'Legal Page')),
      _NavItem('Content', 'Home Slider', Icons.view_carousel,
          (_) => const AdminTableScreen(table: 'slider_media', title: 'Home Slider', singular: 'Slide')),
      _NavItem('Content', 'Ads', Icons.ads_click,
          (_) => const AdminTableScreen(table: 'ads', title: 'Ads', singular: 'Ad')),
      // Insights — Export Data moved here from Settings
      // (rearrange 2026-10-23): it is reports and downloads.
      _NavItem('Insights', 'Revenue', Icons.trending_up,
          (_) => const AdminRevenueScreen()),
      _NavItem('Insights', 'Analytics', Icons.analytics,
          (_) => const AdminAnalyticsScreen()),
      _NavItem('Insights', 'Export Data', Icons.download,
          (_) => const AdminExportScreen()),
      // Settings — app configuration only.
      _NavItem('Settings', 'App Settings', Icons.settings,
          (_) => const AdminAppSettingsScreen()),
      _NavItem('Settings', 'Branding', Icons.palette,
          (_) => const BrandingScreen()),
      _NavItem('Settings', 'Commission', Icons.percent,
          (_) => const CommissionScreen()),
      _NavItem('Settings', 'Platform Settings', Icons.tune,
          (_) => const AdminTableScreen(table: 'platform_settings', title: 'Platform Settings', singular: 'Setting')),
      // Panel Style — switch the admin UI style (owner order
      // 2026-10-18: try every style one by one, live).
      _NavItem('Settings', 'Panel Style', Icons.style,
          (s) => AdminStyleScreen(state: s)),
      // Management — the Settings section split in two (owner
      // order 2026-10-23: too many options in Settings). Day-to-day
      // running of the platform: coverage areas, homepage picks
      // and the staff team. Team is super admin only.
      _NavItem('Management', 'Service Areas', Icons.map,
          (_) => const ServiceAreasScreen()),
      _NavItem('Management', 'Featured', Icons.star_border,
          (_) => const FeaturedScreen()),
      _NavItem('Management', 'Team', Icons.group,
          (_) => const AdminTeamScreen()),
    ];

/// Permission key per nav item, aligned with [_items] by index.
/// The super admin (role 'admin') sees everything. Staff accounts see
/// only the items whose key the super admin ticked for them in
/// Admin > Team ('team' itself is never visible to staff).
/// Absolute indexes (used by the dashboard's quick links):
/// 1 Doctors, 7 Medicines, 26 Announcements.
const _permKeys = [
  'dashboard',
  'doctors', 'hospitals', 'labs', 'pharmacies', 'users',
  'lab_tests', 'medicines', 'inventory', 'coupons',
  'corporate', 'packages', 'subscriptions',
  'applications', 'reviews', 'drivers',
  'remedoo_pay', 'provider_payments',
  'orders', 'appointments', 'refunds', 'emergencies', 'ambulance',
  'support', 'support', 'support',
  'announcements', 'broadcasts', 'faqs', 'legal_pages', 'slider_media',
  'ads',
  'revenue', 'analytics', 'export_data',
  'settings', 'branding', 'commission', 'platform_settings',
  'panel_style',
  'service_areas', 'featured', 'team',
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

  @override
  void initState() {
    super.initState();
    // Full-check fix 2026-10-22: the bell badge read
    // state.supportTickets, which only the Dashboard populated —
    // the badge was 0/stale until Dashboard had been built. Load
    // the tickets when the shell starts if nobody has yet.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = AppStateScope.of(context);
      if (state.supportTickets.isEmpty) {
        state.loadSupportTickets();
      }
      // Refresh restore (owner report 2026-10-23): return to the
      // section the admin was on before the page refreshed,
      // instead of always landing on the Dashboard.
      final saved = await NavMemory.read(NavMemory.adminTab);
      if (!mounted || saved == null) return;
      if (saved > 0 && saved < _visibleItems.length && saved != _index) {
        setState(() => _index = saved);
      }
    });
  }

  void _go(int i) {
    setState(() => _index = i);
    NavMemory.save(NavMemory.adminTab, i);
  }

  /// Dashboard cards navigate by ABSOLUTE item index; translate to the
  /// visible (permission-filtered) index. Hidden items do nothing.
  void _goAbs(int abs) {
    if (abs < 0 || abs >= _allItems.length) return;
    final vi = _visibleItems.indexOf(_allItems[abs]);
    if (vi >= 0) _go(vi);
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
                child: _remidyDrawerNav(state, items, current),
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
          _circleButton(Icons.settings_outlined, 'App Settings',
              () => _jumpTo(items, 'App Settings')),
          const SizedBox(width: 8),
          _bellButton(state, items),
          const SizedBox(width: 8),
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

  void _jumpTo(List<_NavItem> items, String label) {
    final i = items.indexWhere((it) => it.label == label);
    if (i >= 0) {
      _go(i);
    } else if (mounted) {
      // Full-check fix 2026-10-22: for staff without the section
      // permission the item is filtered out and this tap used to
      // silently do nothing.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You do not have access to $label.')));
    }
  }

  /// Cognify's bell: opens Support Tickets, with a pink count
  /// badge while queries are waiting.
  Widget _bellButton(AppState state, List<_NavItem> items) {
    // 'opened' was a legacy status fetchSupportTickets normalises
    // away (full-check fix 2026-10-22).
    final pending = state.supportTickets.where((t) {
      final s = '${t['status'] ?? 'open'}';
      return s == 'open';
    }).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _circleButton(Icons.notifications_none, 'Support Tickets',
            () => _jumpTo(items, 'Support Tickets')),
        if (pending > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFD1A54),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: Text(
                '$pending',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
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

  /// Remidy phone drawer: the new design instead of the old
  /// sidebar list — white panel, black logo header, and every
  /// option as a pill (active = black pill, like the top tabs).
  Widget _remidyDrawerNav(
      AppState state, List<_NavItem> items, _NavItem current) {
    final sections = _sectionsOf(items);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          child: Row(
            children: [
              _logoMark(small: true),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Remedoo',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF141414))),
                  Text(
                    state.isAdmin ? 'SUPER ADMIN' : 'STAFF ACCOUNT',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF8A8F98)),
                  ),
                ],
              ),
              const Spacer(),
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final section in sections) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 7),
                  child: Text(
                    section.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Color(0xFF8A8F98)),
                  ),
                ),
                for (final it
                    in items.where((e) => e.section == section))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        _go(items.indexOf(it));
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: it == current
                              ? const Color(0xFF141414)
                              : const Color(0xFFEEF0F2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(it.icon,
                                size: 17,
                                color: it == current
                                    ? Colors.white
                                    : const Color(0xFF141414)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(it.label,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: it == current
                                          ? Colors.white
                                          : const Color(0xFF141414))),
                            ),
                            if (it == current)
                              const Icon(Icons.check,
                                  size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _logout(state),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout,
                      size: 17, color: Color(0xFF141414)),
                  SizedBox(width: 8),
                  Text('Log out',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF141414))),
                ],
              ),
            ),
          ),
        ),
      ],
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
          if (idx >= 0) _go(idx);
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
                  onTap: () => _go(items.indexOf(it)),
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
    // In Remidy the brand block matches the pill bar: solid black.
    final remedoo = AdminScope.of(context) == AdminStyle.remedoo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: remedoo ? const Color(0xFF141414) : null,
          gradient: remedoo
              ? null
              : const LinearGradient(
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
