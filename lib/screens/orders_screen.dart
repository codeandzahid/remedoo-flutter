import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'order_tracking_screen.dart';
import 'remedoo_pharmacy_screen.dart';

/// My Orders with Active / Past tabs.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // Skeleton shimmer on first load; data itself is local.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: RemedooTheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: RemedooTheme.primary,
          tabs: const [Tab(text: 'Active'), Tab(text: 'Past')],
        ),
      ),
      body: MaxWidthBox(
        child: TabBarView(
          controller: _tabs,
          children: [
            _list(state.activeOrders),
            _list(state.pastOrders),
          ],
        ),
      ),
    );
  }

  Widget _list(List<MedOrder> list) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonCard(),
        ),
      );
    }
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No orders yet',
        subtitle: 'Order medicines and track them here.',
        actionLabel: 'Browse Pharmacy',
        onAction: () =>
            pushPage(context, const RemedooPharmacyScreen()),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) AppStateScope.of(context).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) =>
            StaggerItem(index: i % 6, child: _card(list[i])),
      ),
    );
  }

  Widget _card(MedOrder o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => pushPage(context, OrderTrackingScreen(order: o)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: RemedooTheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shopping_bag,
                        color: RemedooTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ${o.id}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        Text(o.pharmacyName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  StatusChip(status: o.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${o.lines.length} items • ${o.lines.map((l) => l.medicine.name).take(2).join(', ')}${o.lines.length > 2 ? '…' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(inr(o.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: RemedooTheme.primary)),
                  const Spacer(),
                  const Text('Track →',
                      style: TextStyle(
                          color: RemedooTheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
