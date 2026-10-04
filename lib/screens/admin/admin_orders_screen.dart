import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

/// Admin orders: real Supabase orders with status management.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() =>
      _AdminOrdersScreenState();
}

class _AdminOrdersScreenState
    extends State<AdminOrdersScreen> {
  String _filter = 'All';
  bool _loading = true;

  static const _statuses = [
    'placed',
    'confirmed',
    'packed',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadAdminOrders();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final filters = ['All', ..._statuses];
    var list = state.adminOrders.toList();
    if (_filter != 'All') {
      list = list
          .where((o) => '${o['status']}' == _filter)
          .toList();
    }
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = filters[i];
              return Center(
                child: RFilterChip(
                  label: s.replaceAll('_', ' '),
                  selected: s == _filter,
                  onTap: () =>
                      setState(() => _filter = s),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: list.isEmpty
                      ? const REmptyState(
                          icon:
                              Icons.shopping_bag_outlined,
                          title: 'No orders',
                          subtitle:
                              'Orders will appear here.',
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(
                                  16, 4, 16, 16),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _card(
                              context, state, list[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> o) {
    final scheme = Theme.of(context).colorScheme;
    final id = '${o['id']}';
    final total =
        (o['total'] as num?)?.toDouble() ?? 0;
    final items = o['order_items'];
    final itemCount = items is List ? items.length : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      'Order ${id.length > 8 ? id.substring(0, 8) : id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                ),
                StatusChip(status: '${o['status'] ?? ''}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                '$itemCount item${itemCount == 1 ? '' : 's'} • ${inr(total)}'),
            Text(
                '${o['delivery_address'] ?? '—'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            Text(_fmtDate(o['created_at']?.toString()),
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        _statuses.contains('${o['status']}')
                            ? '${o['status']}'
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                                s.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      final ok =
                          await state.updateAdminOrder(
                              id, {'status': v});
                      if (context.mounted && !ok) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Update failed. Try again.')),
                        );
                      }
                    },
                  ),
                ),
                if (itemCount > 0) ...[
                  const SizedBox(width: 10),
                  RButton(
                    label: 'Items',
                    small: true,
                    variant: RButtonVariant.outline,
                    onPressed: () =>
                        _showItems(context, items as List),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showItems(BuildContext context, List items) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Order items',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i] as Map;
              return ListTile(
                dense: true,
                title: Text('${it['medicine_name'] ?? it['name'] ?? 'Item'}'),
                trailing: Text('×${it['quantity'] ?? 1}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
