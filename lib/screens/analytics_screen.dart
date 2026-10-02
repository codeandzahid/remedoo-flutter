import 'package:flutter/material.dart';

import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// My Analytics: stat cards, monthly activity bar chart, top categories.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const _months = [
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct'
  ];
  static const _values = [3.0, 5.0, 4.0, 7.0, 6.0, 8.0];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final spent = state.orders.fold<double>(
        0, (s, o) => s + o.total);
    final categories = [
      ('Doctor Visits', state.appointments.length, Icons.person_search), // counts
      ('Medicines', state.orders.length, Icons.medication),
      ('Lab Tests', state.reports.length, Icons.science),
      ('Emergency', 0, Icons.sos),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return Scaffold(
      appBar: AppBar(title: const Text('My Analytics')),
      body: MaxWidthBox(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          Row(
            children: [
              _statCard('${state.appointments.length}',
                  'Appointments', Icons.calendar_month),
              const SizedBox(width: 10),
              _statCard('${state.orders.length}', 'Orders',
                  Icons.shopping_bag),
              const SizedBox(width: 10),
              _statCard(inr(spent), 'Total Spent',
                  Icons.currency_rupee),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Monthly Activity',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _BarChartPainter(
                      _months, _values, RemedooTheme.primary),
                  child: Container(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Top Categories',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...categories.asMap().entries.map((e) {
            final (label, count, icon) = e.value;
            return StaggerItem(
              index: e.key % 6,
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: RemedooTheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(icon, color: RemedooTheme.primary),
                  ),
                  title: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  trailing: Text('$count',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            );
          }),
        ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: RemedooTheme.primary),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color;

  _BarChartPainter(this.labels, this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final n = values.length;
    final slot = size.width / n;
    final barW = slot * 0.5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final grid = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final y = size.height - 24 - (size.height - 40) * g / 4;
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 0; i < n; i++) {
      final h = (size.height - 40) * values[i] / maxV;
      final x = slot * i + (slot - barW) / 2;
      final y = size.height - 24 - h;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h),
        const Radius.circular(6),
      );
      canvas.drawRRect(rrect, paint);
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: const TextStyle(
                fontSize: 11, color: Colors.grey)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(slot * i + (slot - tp.width) / 2, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}
