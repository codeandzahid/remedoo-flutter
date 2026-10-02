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
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: statuses.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = statuses[i];
              return Center(
                child: RFilterChip(
                  label: s.replaceAll('_', ' '),
                  selected: s == _filter,
                  onTap: () => setState(() => _filter = s),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const REmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No orders',
                  subtitle: 'Orders will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      16, 4, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _card(state, list[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(AppState state, MedOrder o) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
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
            const SizedBox(height: 6),
            Text(
                '${o.pharmacyName} • ${o.items.length} items • ${inr(o.total)}'),
            Text(o.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
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
