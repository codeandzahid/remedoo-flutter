import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Revenue: cards, chart, transactions table.
class AdminRevenueScreen extends StatelessWidget {
  const AdminRevenueScreen({super.key});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
  static const _vals = [42.0, 58.0, 51.0, 70.0, 66.0, 84.0];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final total =
        state.orders.fold<double>(0, (s, o) => s + o.total);
    final avg = state.orders.isEmpty
        ? 0.0
        : total / state.orders.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _card('Total Revenue', inr(total), Icons.trending_up,
                RemedooTheme.ratingGreen),
            const SizedBox(width: 10),
            _card('Avg. Order', inr(avg), Icons.receipt,
                RemedooTheme.primary),
            const SizedBox(width: 10),
            _card('Transactions', '${state.orders.length}',
                Icons.list_alt, RemedooTheme.purple),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Revenue Trend',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 180,
              child: CustomPaint(
                painter: _RevPainter(
                    _months, _vals, RemedooTheme.ratingGreen),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Transactions',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Order')),
                DataColumn(label: Text('Pharmacy')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
              ],
              rows: state.orders.map((MedOrder o) {
                return DataRow(cells: [
                  DataCell(Text(o.id)),
                  DataCell(Text(o.pharmacyName)),
                  DataCell(Text(inr(o.total))),
                  DataCell(StatusChip(status: o.status)),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final Color color;

  _RevPainter(this.labels, this.values, this.color);

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
