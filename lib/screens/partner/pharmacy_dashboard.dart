import 'package:flutter/material.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in pharmacies.
/// Shows orders to fulfill with plain-language actions:
/// confirm the order, mark it ready, send it out, mark it delivered.
class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];

  SupabaseRepository get _repo =>
      AppStateScope.of(context).supabaseRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.fetchOwnProviderRecord('pharmacies');
      final orders = await _repo.fetchPharmacyOrders();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your data. Pull down to try again.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the partner app?',
      confirmLabel: 'Log Out',
    );
    if (!ok) return;
    if (!mounted) return;
    final state = AppStateScope.of(context);
    state.switchRole('patient');
    state.logout();
  }

  Future<void> _setStatus(Map<String, dynamic> o, String status) async {
    final ok = await _repo.updateOrderStatus('${o['id']}', status);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _orders.indexWhere((x) => '${x['id']}' == '${o['id']}');
        if (i >= 0) _orders[i] = {..._orders[i], 'status': status};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order marked as ${_label(status)}.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  /// Plain-language label for each order status.
  String _label(String status) {
    switch (status) {
      case 'placed':
        return 'New order';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'confirmed':
      case 'preparing':
        return RemedooTheme.teal;
      case 'out_for_delivery':
        return scheme.primary;
      case 'delivered':
        return RemedooTheme.success;
      case 'cancelled':
        return scheme.error;
      default:
        return RemedooTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        REmptyState(
                          icon: Icons.cloud_off,
                          title: 'Something went wrong',
                          subtitle: _error!,
                        ),
                      ],
                    )
                  : _buildBody(context),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _orders
        .where((o) =>
            '${o['status']}' != 'delivered' &&
            '${o['status']}' != 'cancelled')
        .toList();
    final done = _orders
        .where((o) =>
            '${o['status']}' == 'delivered' ||
            '${o['status']}' == 'cancelled')
        .toList();
    final newCount =
        _orders.where((o) => '${o['status']}' == 'placed').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: RemedooTheme.warning
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.storefront,
                    color: RemedooTheme.warning, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_profile?['name'] ?? 'Pharmacy'}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${_profile?['location'] ?? ''}',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'New orders',
                '$newCount',
                'Need your confirmation',
                Icons.fiber_new,
                RemedooTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                'In progress',
                '${active.length}',
                'Being prepared or delivered',
                Icons.pending_actions,
                scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                'Completed',
                '${done.length}',
                'Delivered or cancelled',
                Icons.check_circle,
                RemedooTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
          title: 'Orders to Fulfill',
          subtitle:
              'Confirm new orders, then move them step by step to delivered',
        ),
        const SizedBox(height: 12),
        if (active.isEmpty)
          const REmptyState(
            icon: Icons.check_circle,
            title: 'All caught up!',
            subtitle: 'New medicine orders from customers will appear here.',
            compact: true,
          )
        else
          ...active.map((o) => _orderCard(context, o)),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 24),
          const RSectionHeader(
            title: 'Recent History',
            subtitle: 'Finished orders',
          ),
          const SizedBox(height: 12),
          ...done.take(10).map((o) => _orderCard(context, o)),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      String hint, IconData icon, Color color) {
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> o) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${o['status'] ?? 'placed'}';
    final color = _statusColor(context, status);
    final items = (o['order_items'] as List?) ?? [];
    final shortId = '${o['id'] ?? ''}';
    final displayId =
        shortId.length > 8 ? shortId.substring(0, 8).toUpperCase() : shortId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$displayId',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _label(status).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (items.isNotEmpty)
              ...items.take(4).map((it) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• ${it['medicines']?['name'] ?? 'Medicine'} × ${it['quantity'] ?? 1}',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant),
                    ),
                  )),
            if (items.length > 4)
              Text('+ ${items.length - 4} more items',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Total: ${inr((o['total'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Text(
                  '${o['payment_method'] ?? 'cod'}'.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if ('${o['delivery_address'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Deliver to: ${o['delivery_address']}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant),
                ),
              ),
            // Step-by-step action buttons
            if (status == 'placed') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RButton(
                      label: 'Confirm order',
                      small: true,
                      onPressed: () =>
                          _setStatus(o, 'confirmed'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RButton(
                      label: 'Cancel',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          _setStatus(o, 'cancelled'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'confirmed' ||
                status == 'preparing') ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Mark ready — out for delivery',
                small: true,
                onPressed: () =>
                    _setStatus(o, 'out_for_delivery'),
              ),
            ] else if (status == 'out_for_delivery') ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Mark as delivered',
                small: true,
                onPressed: () =>
                    _setStatus(o, 'delivered'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
