import 'package:flutter/material.dart';

import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin overview: stat cards, revenue bar chart, orders donut, activity.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const _revenue = [42.0, 58.0, 51.0, 70.0, 66.0, 84.0];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final revenue =
        state.orders.fold<double>(0, (s, o) => s + o.total);
    final byStatus = <String, int>{};
    for (final o in state.orders) {
      byStatus[o.status] = (byStatus[o.status] ?? 0) + 1;
    }
    final pendingApprovals = state.providerApplications
        .where((a) => a.status == 'pending')
        .length;
    final activeEmergencies = state.sosAlerts
        .where((a) => a.status != 'dispatched')
        .length;

    final scheme = Theme.of(context).colorScheme;
    final stats = [
      _stat(context, 'Total Users', '${state.adminUsers.length}',
          Icons.people, scheme.primary),
      _stat(context, 'Doctors', '${state.activeDoctors.length}',
          Icons.person_search, RemedooTheme.teal),
      _stat(context, 'Appointments', '${state.appointments.length}',
          Icons.calendar_month, RemedooTheme.purple),
      _stat(context, 'Total Orders', '${state.orders.length}',
          Icons.shopping_bag, RemedooTheme.warning),
      _stat(context, 'Pending Approvals', '$pendingApprovals',
          Icons.approval, scheme.primary),
      _stat(context, 'Active Emergencies', '$activeEmergencies',
          Icons.sos, RemedooTheme.emergency),
      _stat(context, 'Revenue', inr(revenue), Icons.currency_rupee,
          RemedooTheme.success),
    ];

    final revenueCard = RCard(
      child: SizedBox(
        height: 200,
        child: CustomPaint(
          painter: _BarPainter(_months, _revenue, scheme.primary),
        ),
      ),
    );

    final donutCard = RCard(
      child: Row(
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
                          color:
                              _DonutPainter.colorFor(e.key),
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
          if (context.isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: StaggerItem(
                      index: 0,
                      child: _section('Monthly Revenue',
                          'Last 6 months of platform revenue',
                          revenueCard)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: StaggerItem(
                      index: 1,
                      child: _section('Orders by Status',
                          'Current order pipeline', donutCard)),
                ),
              ],
            )
          else ...[
            StaggerItem(
                index: 0,
                child: _section('Monthly Revenue',
                    'Last 6 months of platform revenue',
                    revenueCard)),
            const SizedBox(height: 24),
            StaggerItem(
                index: 1,
                child: _section('Orders by Status',
                    'Current order pipeline', donutCard)),
          ],
          const SizedBox(height: 24),
          const RSectionHeader(
              title: 'Recent Activity',
              subtitle: 'Latest platform events'),
          const SizedBox(height: 12),
          ...state.notifications.take(8).map((n) => StaggerItem(
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
                                  overflow:
                                      TextOverflow.ellipsis,
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
      IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
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

class _BarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color;

  _BarPainter(this.labels, this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final slot = size.width / values.length;
    final barW = slot * 0.5;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = (size.height - 40) * values[i] / maxV;
      final x = slot * i + (slot - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - 24 - h, barW, h),
          const Radius.circular(6),
        ),
        paint,
      );
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(
                fontSize: 11, color: Colors.grey)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(slot * i + (slot - tp.width) / 2,
              size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
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
    final total =
        data.values.fold<int>(0, (a, b) => a + b);
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
