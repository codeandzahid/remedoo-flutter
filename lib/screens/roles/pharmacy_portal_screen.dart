import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models.dart';
import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Pharmacy portal: inventory editor + incoming orders.
class PharmacyPortalScreen extends StatefulWidget {
  const PharmacyPortalScreen({super.key});

  @override
  State<PharmacyPortalScreen> createState() =>
      _PharmacyPortalScreenState();
}

class _PharmacyPortalScreenState
    extends State<PharmacyPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Pharmacy _me = pharmacies[0];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_me.name),
        bottom: TabBar(
          controller: _tabs,
          labelColor: RemedooTheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: RemedooTheme.primary,
          tabs: const [
            Tab(text: 'Inventory'),
            Tab(text: 'Incoming Orders')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_inventory(), _orders()],
      ),
    );
  }

  Widget _inventory() {
    final state = AppStateScope.of(context);
    final list = medicinesForPharmacy(_me.id)
        .where((m) => m.active)
        .toList();
    return MaxWidthBox(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final m = list[i];
          final stock = state.stockOf(m.id);
          return StaggerItem(
            index: i % 6,
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    Text('${m.pack} • ${m.brand}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Stock: '),
                        Flexible(
                          child: QtyStepper(
                            qty: stock,
                            onMinus: () => state.setStock(
                                m.id, stock - 1),
                            onPlus: () => state.setStock(
                                m.id, stock + 1),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            initialValue: state
                                .priceOf(m)
                                .toStringAsFixed(0),
                            keyboardType:
                                TextInputType.number,
                            decoration:
                                const InputDecoration(
                              prefixText: '₹',
                              isDense: true,
                            ),
                            onFieldSubmitted: (v) {
                              final p =
                                  double.tryParse(v);
                              if (p != null) {
                                state.setPrice(m.id, p);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _orders() {
    final state = AppStateScope.of(context);
    final list = state.orders
        .where((o) => o.pharmacyName == _me.name)
        .toList();
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No incoming orders',
        subtitle:
            'New orders from patients will appear here.',
      );
    }
    return MaxWidthBox(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final o = list[i];
          return StaggerItem(
            index: i % 6,
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Order ${o.id}',
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w800)),
                        ),
                        StatusChip(status: o.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${o.items.length} items • ${inr(o.total)}'),
                    Text(o.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey)),
                    if (o.status != 'delivered') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              state.advanceOrderStatus(
                                  o.id),
                          child:
                              Text(_nextLabel(o.status)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _nextLabel(String status) {
    switch (status) {
      case 'placed':
        return 'Mark Packed';
      case 'packed':
        return 'Mark Out for Delivery';
      case 'out_for_delivery':
        return 'Mark Delivered';
      default:
        return 'Advance';
    }
  }
}
