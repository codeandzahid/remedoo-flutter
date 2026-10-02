import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin orders: filterable list with status-change actions.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final statuses = [
      'All',
      ...AppState.orderStatuses,
    ];
    var list = state.orders.toList();
    if (_filter != 'All') {
      list = list.where((o) => o.status == _filter).toList();
    }
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: statuses.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = statuses[i];
              final sel = s == _filter;
              return Center(
                child: ChoiceChip(
                  label: Text(s.replaceAll('_', ' ')),
                  selected: sel,
                  onSelected: (_) =>
                      setState(() => _filter = s),
                  selectedColor: RemedooTheme.primary,
                  labelStyle: TextStyle(
                      color: sel ? Colors.white : null),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No orders',
                  subtitle: 'Orders will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _card(state, list[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(AppState state, MedOrder o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order ${o.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                ),
                StatusChip(status: o.status),
              ],
            ),
            Text(
                '${o.pharmacyName} • ${o.items.length} items • ${inr(o.total)}'),
            Text(o.address,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: o.status,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
              ),
              items: AppState.orderStatuses
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.replaceAll('_', ' '))))
                  .toList(),
              onChanged: (v) {
                if (v != null) state.setOrderStatus(o.id, v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
