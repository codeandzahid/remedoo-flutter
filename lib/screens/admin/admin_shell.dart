import 'package:flutter/material.dart';

import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';
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
import 'admin_utr_verification_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_app_settings_screen.dart';
import 'admin_users_screen.dart';

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
      _NavItem('Orders & Care', 'Verify UPI Payments', Icons.verified,
          (_) => const AdminUtrVerificationScreen()),
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

  void _go(int i) {
    setState(() => _index = i);
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
    final items = _items(state, _go);
    final current = items[_index];
    final page = IndexedStack(
      index: _index,
      children: [for (final it in items) it.builder(state)],
    );

    if (context.isDesktop) {
      return Scaffold(
        appBar: _topBar(current.label, state),
        body: Row(
          children: [
            _sideNav(state, items),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: page),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: _topBar(current.label, state),
      drawer: Drawer(
        backgroundColor: _sidebarBg(),
        child: SafeArea(
          child: _navColumn(state, items, inDrawer: true),
        ),
      ),
      body: page,
    );
  }

  PreferredSizeWidget _topBar(String title, AppState state) {
    return AppBar(
      title: Text(title),
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
  Widget _sideNav(AppState state, List<_NavItem> items) {
    return Container(
      width: 288,
      color: _sidebarBg(),
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

  Color _sidebarBg() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? RemedooTheme.darkCard : RemedooTheme.sidebarLight;
  }

  /// Gradient brand banner (rounded-2xl orange gradient, white text) —
  /// the admin counterpart of the React sidebar's gradient Close button.
  Widget _brandHeader() {
    final p = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [p, p.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
      color: _sidebarBg(),
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
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'SUPER ADMIN',
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
