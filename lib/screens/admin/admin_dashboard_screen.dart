import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _stat('Users', '${state.adminUsers.length}',
                Icons.people, RemedooTheme.primary),
            _stat('Doctors', '${state.activeDoctors.length}',
                Icons.person_search, RemedooTheme.teal),
            _stat('Orders', '${state.orders.length}',
                Icons.shopping_bag, RemedooTheme.purple),
            _stat('Revenue', inr(revenue), Icons.currency_rupee,
                RemedooTheme.ratingGreen),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Monthly Revenue',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _BarPainter(
                    _months, _revenue, RemedooTheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Orders by Status',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: byStatus.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _DonutPainter
                                    .colorFor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(e.key
                                    .replaceAll('_', ' '))),
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.w700)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Recent Activity',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...state.notifications.take(8).map((n) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(n.icon,
                    color: RemedooTheme.primary),
                title: Text(n.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
                subtitle: Text(n.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            )),
      ],
    );
  }

  Widget _stat(
      String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
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
        return RemedooTheme.ratingGreen;
      case 'out_for_delivery':
        return RemedooTheme.primary;
      case 'packed':
        return Colors.orange;
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
