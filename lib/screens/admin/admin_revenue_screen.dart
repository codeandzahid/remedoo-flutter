import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Revenue from real Supabase orders: totals, averages, transactions.
class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await AppStateScope.of(context).loadAdminOrders();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final orders = state.adminOrders;
    final total = orders.fold<double>(
        0, (s, o) => s + ((o['total'] as num?)?.toDouble() ?? 0));
    final avg = orders.isEmpty ? 0.0 : total / orders.length;

    // Orders grouped by status for the pipeline summary.
    final byStatus = <String, int>{};
    for (final o in orders) {
      final st = '${o['status'] ?? 'placed'}';
      byStatus[st] = (byStatus[st] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _card(context, 'Total Revenue', inr(total),
                Icons.trending_up, RemedooTheme.success),
            const SizedBox(width: 10),
            _card(context, 'Avg. Order', inr(avg), Icons.receipt,
                scheme.primary),
            const SizedBox(width: 10),
            _card(context, 'Transactions', '${orders.length}',
                Icons.list_alt, RemedooTheme.purple),
          ],
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Order Pipeline',
            subtitle: 'Live counts by status'),
        const SizedBox(height: 12),
        RCard(
          child: byStatus.isEmpty
              ? Text('No orders yet.',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 13))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: byStatus.entries
                      .map((e) => Chip(
                            label: Text(
                                '${e.key.replaceAll('_', ' ')} · ${e.value}'),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
            title: 'Transactions', subtitle: 'All medicine orders'),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          const REmptyState(
              icon: Icons.receipt_long,
              title: 'No transactions yet',
              subtitle: 'Orders will appear here.',
              compact: true)
        else
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
                  DataColumn(label: Text('AMOUNT')),
                  DataColumn(label: Text('PAYMENT')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: orders.take(100).map((o) {
                  final id = '${o['id'] ?? ''}';
                  return DataRow(cells: [
                    DataCell(Text(
                        id.length > 8 ? id.substring(0, 8) : id,
                        style: const TextStyle(fontFamily: 'monospace'))),
                    DataCell(Text(
                        inr((o['total'] as num?)?.toDouble() ?? 0))),
                    DataCell(
                        Text('${o['payment_method'] ?? 'cod'}')),
                    DataCell(
                        StatusChip(status: '${o['status'] ?? 'placed'}')),
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
                    fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
