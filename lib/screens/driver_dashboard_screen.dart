import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Driver Dashboard — wired to the real backend (form-pages
/// audit Panelist 9 / M19: this screen used to be unreachable —
/// no driver role, no route — and ran on an in-memory list that
/// was never populated, with "earnings" fabricated as 10% of
/// delivery amounts). Now: Partner login accepts the driver
/// role, PartnerRootGate routes here, deliveries come from
/// delivery_orders joined with remedoo_orders, the online
/// toggle persists to delivery_drivers.status, and the money
/// figures are the real COD totals of delivered orders.
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _driver;
  List<Map<String, dynamic>> _deliveries = [];
  bool _loading = true;
  bool _noProfile = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  dynamic get _repo => AppStateScope.of(context).supabaseRepository;

  Future<void> _load() async {
    final driver = await _repo.fetchOwnDriverRecord();
    final deliveries = await _repo.fetchDriverDeliveries();
    if (!mounted) return;
    setState(() {
      _driver = driver;
      _deliveries = deliveries;
      _noProfile = driver == null;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the driver app?',
      confirmLabel: 'Log Out',
    );
    if (!ok) return;
    if (!mounted) return;
    final state = AppStateScope.of(context);
    state.switchRole('patient');
    state.logout();
  }

  bool get _online =>
      _driver != null && '${_driver!['status']}' != 'offline';

  Future<void> _setOnline(bool v) async {
    if (_driver == null) return;
    final ok = await _repo.setDriverStatus(
        '${_driver!['id']}', v ? 'available' : 'offline');
    if (ok) _load();
  }

  static const _nextStatus = {
    'pending': 'assigned',
    'assigned': 'picked_up',
    'picked_up': 'in_transit',
    'in_transit': 'delivered',
  };
  static const _nextLabel = {
    'pending': 'Accept delivery',
    'assigned': 'Mark picked up',
    'picked_up': 'Start delivery',
    'in_transit': 'Mark delivered',
  };

  Future<void> _advance(Map<String, dynamic> d) async {
    final next = _nextStatus['${d['status']}'];
    if (next == null) return;
    final ok = await _repo.updateDeliveryStatus('${d['id']}', next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Status updated: $next'
            : 'Could not update. Try again.'),
      ),
    );
    if (ok) _load();
  }

  double _orderTotal(Map<String, dynamic> d) {
    final order = d['order'];
    if (order is Map) {
      return (order['total'] as num?)?.toDouble() ?? 0;
    }
    return 0;
  }

  bool _isCod(Map<String, dynamic> d) {
    final order = d['order'];
    return order is Map && '${order['payment_method']}' == 'cod';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _deliveries
        .where((d) =>
            d['status'] != 'delivered' && d['status'] != 'cancelled')
        .toList();
    final done =
        _deliveries.where((d) => d['status'] == 'delivered').toList();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final doneToday = done
        .where((d) => '${d['delivered_at'] ?? ''}'.startsWith(todayStr))
        .toList();
    final codToday = doneToday
        .where(_isCod)
        .fold<double>(0, (s, d) => s + _orderTotal(d));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Deliveries'),
            Tab(text: 'Earnings'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading
          ? const RLoading()
          : _noProfile
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: REmptyState(
                    icon: Icons.delivery_dining_outlined,
                    title: 'Driver profile not set up',
                    subtitle:
                        'Your account has the driver role but no driver profile yet. Ask Remedoo to create your driver profile, then sign in again.',
                  ),
                )
              : MaxWidthBox(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _online
                              ? RemedooTheme.success
                                  .withValues(alpha: 0.12)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _online
                                  ? Icons.check_circle
                                  : Icons.pause_circle_outline,
                              color: _online
                                  ? RemedooTheme.success
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _online
                                        ? 'You are online'
                                        : 'You are offline',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16),
                                  ),
                                  Text(
                                    '${_driver?['name'] ?? ''}'
                                    '${'${_driver?['vehicle_number'] ?? ''}'.isNotEmpty ? ' • ${_driver?['vehicle_number']}' : ''}'
                                    ' • Status: ${_driver?['status'] ?? ''}',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _online,
                              onChanged: _setOnline,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _deliveryList(active, actionable: true),
                            _earningsTab(doneToday, codToday, done),
                            _deliveryList(done, actionable: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _deliveryList(List<Map<String, dynamic>> items,
      {required bool actionable}) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: REmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'No deliveries',
          subtitle: 'Assigned deliveries will appear here.',
          compact: true,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final d in items) _deliveryCard(d, actionable: actionable),
        ],
      ),
    );
  }

  Widget _deliveryCard(Map<String, dynamic> d,
      {required bool actionable}) {
    final scheme = Theme.of(context).colorScheme;
    final order = d['order'];
    final total = _orderTotal(d);
    final itemsCount = order is Map && order['items'] is List
        ? (order['items'] as List).length
        : 0;
    final orderId = '${d['order_id'] ?? ''}';
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
                    'Order #${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: RemedooTheme.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${d['status']}',
                      style: const TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pickup: ${d['pickup_address'] ?? 'Remedoo Pharmacy'}',
                style: const TextStyle(fontSize: 13)),
            Text('Drop: ${d['delivery_address'] ?? ''}',
                style: const TextStyle(fontSize: 13)),
            if (itemsCount > 0)
              Text('$itemsCount item${itemsCount == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            if (total > 0)
              Text(
                _isCod(d)
                    ? 'Collect ₹${total.toStringAsFixed(0)} cash on delivery'
                    : 'Paid online • ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            if (actionable && _nextLabel['${d['status']}'] != null) ...[
              const SizedBox(height: 10),
              RButton(
                label: _nextLabel['${d['status']}']!,
                small: true,
                fullWidth: true,
                onPressed: () => _advance(d),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _earningsTab(List<Map<String, dynamic>> doneToday,
      double codToday, List<Map<String, dynamic>> doneAll) {
    final codAll = doneAll
        .where(_isCod)
        .fold<double>(0, (s, d) => s + _orderTotal(d));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Today',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${doneToday.length} deliveries completed'),
              Text(
                  'Cash collected (COD): ₹${codToday.toStringAsFixed(0)}'),
              const Divider(height: 24),
              const Text('All time',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${doneAll.length} deliveries completed'),
              Text('Cash collected (COD): ₹${codAll.toStringAsFixed(0)}'),
              const SizedBox(height: 8),
              Text(
                'Figures come from your real delivered orders. '
                'Delivery pay is settled by Remedoo from these records.',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
