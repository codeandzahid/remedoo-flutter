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
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _card(context, 'Total Revenue', inr(total),
                Icons.trending_up, RemedooTheme.success),
            const SizedBox(width: 10),
            _card(context, 'Avg. Order', inr(avg),
                Icons.receipt, scheme.primary),
            const SizedBox(width: 10),
            _card(context, 'Transactions',
                '${state.orders.length}', Icons.list_alt,
                RemedooTheme.purple),
          ],
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Revenue Trend',
            subtitle: 'Last 6 months (demo data)'),
        const SizedBox(height: 12),
        RCard(
          child: SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _RevPainter(
                  _months, _vals, RemedooTheme.success),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Transactions',
            subtitle: 'All medicine orders'),
        const SizedBox(height: 12),
        RCard(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.4,
                color: scheme.onSurfaceVariant,
              ),
              columns: const [
                DataColumn(label: Text('ORDER')),
                DataColumn(label: Text('PHARMACY')),
                DataColumn(label: Text('AMOUNT')),
                DataColumn(label: Text('STATUS')),
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

  Widget _card(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: RCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: dark
                    ? color.withValues(alpha: 0.18)
                    : Color.lerp(color, Colors.white, 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant)),
          ],
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
