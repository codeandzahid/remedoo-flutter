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

/// Admin console shell: drawer on phones, rail on tablets,
/// permanent sectioned drawer on desktop.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = _items(state);

    // Group items into sections, preserving order.
    final sections = <NavSection>[];
    String? lastSection;
    List<NavDestinationItem> current = [];
    for (final it in items) {
      if (it.section != lastSection) {
        if (current.isNotEmpty) {
          sections.add(NavSection(lastSection ?? '', current));
        }
        lastSection = it.section;
        current = [];
      }
      current.add(NavDestinationItem(icon: it.icon, label: it.label));
    }
    if (current.isNotEmpty) {
      sections.add(NavSection(lastSection ?? '', current));
    }

    final currentItem = items[_index];
    return ResponsiveScaffold(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      sections: sections,
      pages: [for (final it in items) it.builder(state)],
      drawerHeader: _drawerHeader(),
      appBar: AppBar(
        title: Text(currentItem.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
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
            },
          ),
        ],
      ),
    );
  }

  Widget _drawerHeader() {
    return Container(
      decoration:
          const BoxDecoration(gradient: RemedooTheme.headerGradient),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RemedooLogo(size: 44),
          SizedBox(height: 8),
          Text('Admin Console',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text('admin@remedoo.app',
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
