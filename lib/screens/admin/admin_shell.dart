import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
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

class _NavItem {
  final String section;
  final String label;
  final IconData icon;
  final Widget Function(AppState) builder;

  const _NavItem(this.section, this.label, this.icon, this.builder);
}

List<_NavItem> _items(AppState s) => [
      _NavItem('Overview', 'Dashboard', Icons.dashboard,
          (_) => const AdminDashboardScreen()),
      // Management
      _NavItem('Management', 'Doctors', Icons.person_search,
          (st) => AdminCrudScreen(spec: st.doctorSpec())),
      _NavItem('Management', 'Hospitals', Icons.local_hospital,
          (st) => AdminCrudScreen(spec: st.hospitalSpec())),
      _NavItem('Management', 'Labs', Icons.science,
          (st) => AdminCrudScreen(spec: st.labSpec())),
      _NavItem('Management', 'Pharmacies', Icons.storefront,
          (st) => AdminCrudScreen(spec: st.pharmacySpec())),
      _NavItem('Management', 'Medicines', Icons.medication,
          (st) => AdminCrudScreen(spec: st.medicineSpec())),
      _NavItem(
          'Management',
          'Users',
          Icons.people,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec('Users', 'User', const [
                FieldSpec(key: 'name', label: 'Name', required: true),
                FieldSpec(key: 'email', label: 'Email'),
                FieldSpec(key: 'phone', label: 'Phone'),
              ], st.adminUsers))),
      _NavItem('Management', 'Approvals', Icons.approval,
          (_) => const AdminApprovalsScreen()),
      _NavItem('Management', 'Reviews', Icons.star,
          (_) => const AdminReviewsScreen()),
      // Content
      _NavItem(
          'Content',
          'Promo Banners',
          Icons.campaign,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec(
                      'Promo Banners', 'Banner', const [
                FieldSpec(key: 'title', label: 'Title', required: true),
                FieldSpec(key: 'subtitle', label: 'Subtitle'),
              ], st.promoBanners))),
      _NavItem(
          'Content',
          'Health Tips',
          Icons.lightbulb,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec('Health Tips', 'Tip', const [
                FieldSpec(key: 'title', label: 'Title', required: true),
                FieldSpec(key: 'text', label: 'Text'),
              ], healthTips))),
      _NavItem(
          'Content',
          'FAQs',
          Icons.help,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec('FAQs', 'FAQ', const [
                FieldSpec(
                    key: 'question',
                    label: 'Question',
                    required: true),
                FieldSpec(key: 'answer', label: 'Answer'),
              ], st.faqs))),
      _NavItem(
          'Content',
          'Slider Items',
          Icons.view_carousel,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec(
                      'Slider Items', 'Slider', const [
                FieldSpec(key: 'title', label: 'Title', required: true),
                FieldSpec(key: 'subtitle', label: 'Subtitle'),
              ], st.sliderItems))),
      _NavItem(
          'Content',
          'Info Cards',
          Icons.info,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec('Info Cards', 'Card', const [
                FieldSpec(key: 'title', label: 'Title', required: true),
                FieldSpec(key: 'text', label: 'Text'),
              ], st.infoCards))),
      _NavItem(
          'Content',
          'Quick Access',
          Icons.bolt,
          (st) => AdminCrudScreen(
                  spec: st.mapSpec('Quick Access', 'Item', const [
                FieldSpec(key: 'title', label: 'Title', required: true),
                FieldSpec(key: 'icon', label: 'Icon name'),
              ], st.quickAccess))),
      // Operations
      _NavItem('Operations', 'Orders', Icons.shopping_bag,
          (_) => const AdminOrdersScreen()),
      _NavItem('Operations', 'Appointments', Icons.calendar_month,
          (_) => const AdminAppointmentsScreen()),
      _NavItem('Operations', 'Emergencies', Icons.sos,
          (_) => const AdminEmergenciesScreen()),
      _NavItem('Operations', 'Support Tickets', Icons.support_agent,
          (_) => const AdminSupportTicketsScreen()),
      _NavItem('Operations', 'Broadcast', Icons.send,
          (_) => const AdminBroadcastScreen()),
      _NavItem('Operations', 'Payouts', Icons.payments,
          (_) => const AdminPayoutsScreen()),
      _NavItem('Operations', 'Refunds', Icons.replay,
          (_) => const AdminRefundsScreen()),
      _NavItem('Operations', 'Ambulance', Icons.emergency,
          (_) => const AdminAmbulanceScreen()),
      _NavItem('Operations', 'Delivery Drivers', Icons.delivery_dining,
          (_) => const AdminDeliveryDriversScreen()),
      _NavItem('Operations', 'Inventory', Icons.inventory,
          (_) => const AdminInventoryScreen()),
      _NavItem('Operations', 'Sessions', Icons.devices,
          (_) => const AdminSessionsScreen()),
      // Configuration
      _NavItem('Configuration', 'OTP Settings', Icons.sms,
          (_) => const OtpSettingsScreen()),
      _NavItem('Configuration', 'Commission', Icons.percent,
          (_) => const CommissionScreen()),
      _NavItem('Configuration', 'Subscriptions', Icons.card_membership,
          (_) => const SubscriptionsScreen()),
      _NavItem('Configuration', 'Corporate Plans', Icons.business,
          (_) => const CorporatePlansScreen()),
      _NavItem('Configuration', 'Healthcare Packages',
          Icons.health_and_safety, (_) => const HealthcarePackagesScreen()),
      _NavItem('Configuration', 'API Keys', Icons.key,
          (_) => const ApiKeysScreen()),
      _NavItem('Configuration', 'Branding', Icons.palette,
          (_) => const BrandingScreen()),
      _NavItem('Configuration', 'Service Areas', Icons.map,
          (_) => const ServiceAreasScreen()),
      _NavItem('Configuration', 'Quick Actions', Icons.flash_on,
          (_) => const QuickActionsScreen()),
      _NavItem('Configuration', 'Category Actions', Icons.category,
          (_) => const CategoryActionsScreen()),
      _NavItem('Configuration', 'Featured', Icons.star_border,
          (_) => const FeaturedScreen()),
      // Insights
      _NavItem('Insights', 'Revenue', Icons.trending_up,
          (_) => const AdminRevenueScreen()),
      _NavItem('Insights', 'Analytics', Icons.analytics,
          (_) => const AdminAnalyticsScreen()),
      _NavItem('Insights', 'Login Logs', Icons.list_alt,
          (_) => const AdminLogsScreen()),
      _NavItem('Insights', 'Suspicious Activity', Icons.warning,
          (_) => const AdminSuspiciousActivityScreen()),
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
    final items = _items(state);
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

  /// Permanent light sidebar for desktop: logo header, sectioned nav,
  /// sign-out footer. The active item gets an orange-tinted pill.
  Widget _sideNav(AppState state, List<_NavItem> items) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 288,
      color: scheme.surface,
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

  Widget _brandHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: RemedooTheme.softShadow,
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remedoo',
                  style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 17)),
              Text('Admin Console',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navList(AppState state, List<_NavItem> items) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: _sectionedNav(items),
    );
  }

  Widget _navColumn(AppState state, List<_NavItem> items,
      {bool inDrawer = false}) {
    return Column(
      children: [
        _brandHeader(),
        Expanded(
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: _sectionedNav(items, onTap: () {
              if (inDrawer) Navigator.of(context).pop();
            }),
          ),
        ),
        _sideFooter(state),
      ],
    );
  }

  List<Widget> _sectionedNav(List<_NavItem> items,
      {VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final out = <Widget>[];
    String? lastSection;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.section != lastSection) {
        lastSection = it.section;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            it.section.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ));
      }
      final active = i == _index;
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: active
              ? scheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _go(i);
              onTap?.call();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(it.icon,
                      size: 20,
                      color: active
                          ? scheme.primary
                          : scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      it.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: active
                            ? scheme.primary
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (active)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
