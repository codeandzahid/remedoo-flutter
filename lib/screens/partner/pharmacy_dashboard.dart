import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in pharmacies: orders to fulfill and inventory.
class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final state = AppStateScope.of(context);
    final pharmacies = state.adminTable('pharmacies');
    final uid = state.supaUserId;
    Map<String, dynamic>? profile;
    for (final p in pharmacies) {
      if ('${p['user_id']}' == uid) {
        profile = p;
        break;
      }
    }
    await state.loadAdminOrders();
    final all = state.adminOrders;
    List<Map<String, dynamic>> mine = [];
    if (profile != null) {
      final pid = '${profile['id']}';
      mine = all.where((o) => '${o['pharmacy_id']}' == pid).toList();
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _orders = mine;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final state = AppStateScope.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the partner app?',
      confirmLabel: 'Log Out',
    );
    if (ok && context.mounted) {
      state.switchRole('patient');
      state.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final pending = _orders
        .where((o) =>
            '${o['status']}' != 'delivered' &&
            '${o['status']}' != 'cancelled')
        .toList();

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
      body: ListView(
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
                        '${_profile?['name'] ?? 'Pharmacy'}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700),
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
                child: _statCard(context, 'Pending Orders',
                    '${pending.length}', Icons.pending_actions, RemedooTheme.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(context, 'Total Orders',
                    '${_orders.length}', Icons.shopping_bag, scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const RSectionHeader(
              title: 'Orders to Fulfill',
              subtitle: 'Prepare these for pickup/delivery'),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const REmptyState(
                icon: Icons.check_circle,
                title: 'All caught up!',
                subtitle: 'No pending orders.',
                compact: true)
          else
            ...pending.map((o) => _orderCard(context, o)),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> o) {
    final scheme = Theme.of(context).colorScheme;
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
                    'Order ${('${o['id'] ?? ''}').length > 8 ? ('${o['id']}').substring(0, 8) : o['id']}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RemedooTheme.warning
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${o['status'] ?? 'placed'}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: RemedooTheme.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Total: ${inr((o['total'] as num?)?.toDouble() ?? 0)}',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
