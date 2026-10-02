import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Driver Dashboard: online toggle + assigned deliveries flow.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState
    extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final active = state.deliveries
        .where((d) => d.status != 'delivered')
        .toList();
    final done = state.deliveries
        .where((d) => d.status == 'delivered')
        .toList();
    final earnings =
        done.fold<double>(0, (s, d) => s + d.amount * 0.1);
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Dashboard')),
      body: MaxWidthBox(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: state.driverOnline
                    ? const LinearGradient(colors: [
                        RemedooTheme.ratingGreen,
                        Color(0xFF35C172)
                      ])
                    : LinearGradient(colors: [
                        Colors.grey.shade400,
                        Colors.grey.shade500
                      ]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.driverOnline
                              ? 'You are Online'
                              : 'You are Offline',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        ),
                        Text(
                          state.driverOnline
                              ? 'Accept deliveries to earn'
                              : 'Go online to get deliveries',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.driverOnline,
                    onChanged: state.setDriverOnline,
                    activeThumbColor: Colors.white,
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: RemedooTheme.primary,
              unselectedLabelColor: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
              indicatorColor: RemedooTheme.primary,
              tabs: const [
                Tab(text: 'Deliveries'),
                Tab(text: 'Earnings'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _deliveries(active, state),
                  _earnings(earnings, done.length),
                  _deliveries(done, state, history: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deliveries(List<DriverDelivery> list, AppState state,
      {bool history = false}) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.delivery_dining,
        title: 'No deliveries',
        subtitle: 'Assigned deliveries will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => StaggerItem(
        index: i % 6,
        child: _card(list[i], state, history),
      ),
    );
  }

  Widget _card(
      DriverDelivery d, AppState state, bool history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order ${d.orderId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                StatusChip(status: d.status),
              ],
            ),
            const SizedBox(height: 6),
            InfoRow(
                icon: Icons.storefront,
                label: 'Pickup',
                value: d.pharmacyName),
            InfoRow(
                icon: Icons.location_on,
                label: 'Drop',
                value: d.address),
            InfoRow(
                icon: Icons.currency_rupee,
                label: 'COD',
                value: inr(d.amount)),
            if (!history) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    state.advanceDelivery(d.id);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                          content: Text(
                              'Status updated: ${d.status}')),
                    );
                  },
                  child: Text(_nextLabel(d.status)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _nextLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Accept';
      case 'accepted':
        return 'Mark Picked Up';
      case 'picked_up':
        return 'Mark Delivered';
      default:
        return 'Update';
    }
  }

  Widget _earnings(double earnings, int count) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StaggerItem(
          index: 0,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Today's earnings",
                      style: TextStyle(color: Colors.grey)),
                  Text(inr(earnings),
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: RemedooTheme.ratingGreen)),
                  const SizedBox(height: 8),
                  Text('$count deliveries completed'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
