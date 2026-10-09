import 'package:flutter/material.dart';

import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin overview with real data: stats, order pipeline, recent activity.
class AdminDashboardScreen extends StatefulWidget {
  /// Called with the nav index when a management card is tapped.
  final void Function(int index)? onNavigate;

  const AdminDashboardScreen({super.key, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    await Future.wait([
      state.loadAllProfiles(),
      state.loadAdminTable('doctors'),
      state.loadAdminAppointments(),
      state.loadAdminOrders(),
      state.loadAdminProviderApplications(),
      state.loadEmergencyRequests(),
      state.loadSupportTickets(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const RLoading();
    }

    final revenue = state.adminOrders.fold<double>(
        0, (s, o) => s + ((o['total'] as num?)?.toDouble() ?? 0));
    final byStatus = <String, int>{};
    for (final o in state.adminOrders) {
      final st = '${o['status'] ?? 'placed'}';
      byStatus[st] = (byStatus[st] ?? 0) + 1;
    }
    final pendingApprovals = state.adminProviderApplications
        .where((a) => '${a['status']}' == 'pending')
        .length;
    final activeEmergencies = state.emergencyRequests
        .where((a) =>
            '${a['status']}' != 'resolved' &&
            '${a['status']}' != 'dispatched')
        .length;
    final pendingQueries = state.supportTickets
        .where((t) => '${t['status'] ?? 'open'}' == 'open')
        .length;

    final stats = [
      _stat(context, 'Total Users', '${state.allProfiles.length}',
          Icons.people, scheme.primary),
      _stat(context, 'Doctors',
          '${state.adminTable('doctors').length}', Icons.person_search,
          RemedooTheme.teal),
      _stat(context, 'Appointments',
          '${state.adminAppointments.length}', Icons.calendar_month,
          RemedooTheme.purple),
      _stat(context, 'Total Orders', '${state.adminOrders.length}',
          Icons.shopping_bag, RemedooTheme.warning),
      _stat(context, 'Pending Approvals', '$pendingApprovals',
          Icons.approval, scheme.primary),
      _stat(
          context,
          'Pending Queries',
          '$pendingQueries',
          Icons.mark_chat_unread_outlined,
          RemedooTheme.emergency,
          onTap: () => widget.onNavigate?.call(16)),
      _stat(context, 'Active Emergencies', '$activeEmergencies',
          Icons.sos, RemedooTheme.emergency),
      _stat(context, 'Revenue', inr(revenue), Icons.currency_rupee,
          RemedooTheme.success),
    ];

    final donutCard = RCard(
      child: byStatus.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No orders yet.',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13)),
            )
          : Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CustomPaint(
                    painter: _DonutPainter(byStatus),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: byStatus.entries.map((e) {
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _DonutPainter.colorFor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                              e.key.replaceAll('_', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )),
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );

    // Recent activity from real orders + appointments.
    final recent = [
      for (final o in state.adminOrders.take(4))
        _Activity(
          icon: Icons.shopping_bag,
          title: 'Order ${('${o['id'] ?? ''}').length > 8 ? ('${o['id']}').substring(0, 8) : o['id']}',
          body:
              '${inr((o['total'] as num?)?.toDouble() ?? 0)} · ${o['status'] ?? 'placed'}',
        ),
      for (final a in state.adminAppointments.take(4))
        _Activity(
          icon: Icons.calendar_month,
          title: 'Appointment ${a['service_type'] ?? ''}',
          body: '${a['appointment_date'] ?? ''} · ${a['status'] ?? ''}',
        ),
    ];

    // Management cards: every admin section with a plain-language description.
    // Indices match the _items() order in admin_shell.dart.
    final manageSections = [
      _ManageSection('Catalog', 'What users see in the app', [
        _ManageCard(1, 'Doctors', 'Add, edit, or remove doctors from the app.',
            Icons.person_search, RemedooTheme.teal),
        _ManageCard(2, 'Hospitals', 'Manage hospital listings and details.',
            Icons.local_hospital, Colors.red),
        _ManageCard(3, 'Labs', 'Manage diagnostic labs and services.',
            Icons.science, RemedooTheme.purple),
        _ManageCard(4, 'Lab Tests', 'Add or edit lab tests and prices.',
            Icons.biotech, RemedooTheme.purple),
        _ManageCard(5, 'Pharmacies', 'Manage pharmacy stores.',
            Icons.storefront, RemedooTheme.warning),
        _ManageCard(6, 'Medicines', 'Add or edit medicines in the catalog.',
            Icons.medication, RemedooTheme.warning),
        _ManageCard(7, 'Inventory', 'Track medicine stock levels.',
            Icons.inventory, scheme.primary),
      ]),
      _ManageSection('Providers', 'People who offer services', [
        _ManageCard(8, 'Applications',
            'Review new applications. Approve or reject them.',
            Icons.approval, scheme.primary),
        _ManageCard(9, 'Payments (UPI)', 'View provider UPI payment details.',
            Icons.qr_code, RemedooTheme.teal),
        _ManageCard(10, 'Reviews', 'See and manage user reviews.',
            Icons.star, RemedooTheme.warning),
      ]),
      _ManageSection('Orders & Care', 'Day-to-day operations', [
        _ManageCard(11, 'Orders', 'View medicine orders. Update status.',
            Icons.shopping_bag, RemedooTheme.warning),
        _ManageCard(12, 'Appointments', 'View and manage appointments.',
            Icons.calendar_month, RemedooTheme.purple),
        _ManageCard(13, 'Refunds', 'Process refund requests.',
            Icons.replay, Colors.red),
        _ManageCard(14, 'Emergencies', 'Handle emergency SOS requests.',
            Icons.sos, RemedooTheme.emergency),
        _ManageCard(15, 'Ambulance', 'Manage ambulance requests.',
            Icons.emergency, RemedooTheme.emergency),
        _ManageCard(16, 'Support Tickets', 'Reply to user support messages.',
            Icons.support_agent, scheme.primary),
      ]),
      _ManageSection('Content', 'What users see', [
        _ManageCard(17, 'Announcements', 'Send messages to all app users.',
            Icons.campaign, RemedooTheme.teal),
      ]),
      _ManageSection('Settings', 'Configure the app', [
        _ManageCard(18, 'App Settings', 'Fees, charges, and general settings.',
            Icons.settings, scheme.primary),
        _ManageCard(19, 'Branding', 'App themes, colors, and appearance.',
            Icons.palette, RemedooTheme.purple),
        _ManageCard(20, 'Commission', 'Set commission rates for providers.',
            Icons.percent, RemedooTheme.teal),
        _ManageCard(21, 'Subscriptions', 'Manage subscription plans.',
            Icons.card_membership, RemedooTheme.warning),
        _ManageCard(22, 'Corporate Plans', 'Manage corporate health plans.',
            Icons.business, scheme.primary),
        _ManageCard(
            23, 'Healthcare Packages', 'Create health checkup packages.',
            Icons.health_and_safety, RemedooTheme.emergency),
        _ManageCard(24, 'Service Areas', 'Define service coverage areas.',
            Icons.map, RemedooTheme.teal),
        _ManageCard(25, 'Featured', 'Choose featured doctors and hospitals.',
            Icons.star_border, RemedooTheme.warning),
      ]),
      _ManageSection('Insights', 'Reports and data', [
        _ManageCard(26, 'Revenue', 'Earnings and financial reports.',
            Icons.trending_up, RemedooTheme.success),
        _ManageCard(27, 'Analytics', 'App usage statistics and trends.',
            Icons.analytics, scheme.primary),
        _ManageCard(28, 'Users', 'View and manage user accounts.',
            Icons.people, RemedooTheme.teal),
      ]),
    ];

    return MaxWidthBox(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ResponsiveGrid(
            compactCols: 2,
            mediumCols: 3,
            expandedCols: 4,
            wideCols: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            itemCount: stats.length,
            itemBuilder: (_, i) =>
                StaggerItem(index: i % 6, child: stats[i]),
          ),
          const SizedBox(height: 24),
          // Management: every admin section explained in plain language.
          if (widget.onNavigate != null) ...[
            const RSectionHeader(
                title: 'Manage',
                subtitle: 'Tap a card to open that section'),
            const SizedBox(height: 12),
            for (final section in manageSections) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              Text(
                section.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ResponsiveGrid(
                compactCols: 1,
                mediumCols: 2,
                expandedCols: 3,
                wideCols: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.2,
                itemCount: section.cards.length,
                itemBuilder: (_, i) {
                  final card = section.cards[i];
                  return RCard(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => widget.onNavigate!(card.index),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: card.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(card.icon,
                                color: card.color, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  card.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  card.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
          StaggerItem(
              index: 0,
              child: _section('Orders by Status',
                  'Live order pipeline', donutCard)),
          const SizedBox(height: 24),
          const RSectionHeader(
              title: 'Recent Activity',
              subtitle: 'Latest platform events'),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const REmptyState(
                icon: Icons.timeline,
                title: 'No activity yet',
                subtitle: 'Orders and appointments will appear here.',
                compact: true)
          else
            ...recent.map((n) => StaggerItem(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _tile(context, n.icon, scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(n.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600)),
                                Text(n.body,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: scheme
                                            .onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _section(String title, String subtitle, Widget card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RSectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        card,
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value,
      IconData icon, Color color,
      {VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final card = RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _tile(context, icon, color),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }

  /// Pastel icon tile: light tint of [color] in light mode,
  /// translucent tint in dark mode.
  Widget _tile(BuildContext context, IconData icon, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: dark
            ? color.withValues(alpha: 0.18)
            : Color.lerp(color, Colors.white, 0.85),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _Activity {
  final IconData icon;
  final String title;
  final String body;

  _Activity({required this.icon, required this.title, required this.body});
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> data;

  _DonutPainter(this.data);

  static Color colorFor(String status) {
    switch (status) {
      case 'delivered':
        return RemedooTheme.success;
      case 'out_for_delivery':
        return RemedooTheme.primary;
      case 'packed':
        return RemedooTheme.warning;
      default:
        return RemedooTheme.purple;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 10,
        Paint()..color = Colors.grey.shade200,
      );
      return;
    }
    var start = -90.0 * 3.14159 / 180;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    for (final e in data.entries) {
      final sweep = 2 * 3.14159 * e.value / total;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = colorFor(e.key),
      );
      start += sweep;
    }
    canvas.drawCircle(
        center, radius * 0.55, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}

/// A group of management cards on the dashboard.
class _ManageSection {
  final String title;
  final String subtitle;
  final List<_ManageCard> cards;

  const _ManageSection(this.title, this.subtitle, this.cards);
}

/// One tappable card explaining an admin section in plain language.
class _ManageCard {
  final int index;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _ManageCard(
      this.index, this.title, this.description, this.icon, this.color);
}
