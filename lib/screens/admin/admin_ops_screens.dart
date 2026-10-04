import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

// Operations screens backed by Supabase:
// refunds, ambulance fleet, pharmacy inventory.

/// Pastel icon tile that adapts to light/dark.
Widget _tile(BuildContext context, IconData icon, Color color,
    {double size = 46}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: dark
          ? color.withValues(alpha: 0.18)
          : Color.lerp(color, Colors.white, 0.85),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 24),
  );
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  } catch (_) {
    return iso;
  }
}

/// Refund requests from Supabase with Approve / Reject / Complete.
class AdminRefundsScreen extends StatefulWidget {
  const AdminRefundsScreen({super.key});

  @override
  State<AdminRefundsScreen> createState() =>
      _AdminRefundsScreenState();
}

class _AdminRefundsScreenState
    extends State<AdminRefundsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadRefunds();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    if (state.refunds.isEmpty) {
      return const REmptyState(
        icon: Icons.replay,
        title: 'No refund requests',
        subtitle: 'Refund requests will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.refunds.length,
        itemBuilder: (_, i) =>
            _card(context, state, state.refunds[i]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final id = '${r['id']}';
    final status = '${r['status'] ?? 'requested'}';
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
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
                      'Refund ${id.length > 8 ? id.substring(0, 8) : id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                ),
                StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${inr(amount)} • ${r['reason'] ?? '—'}'),
            Text(
                '${r['order_id'] != null ? 'Order ${(r['order_id'] as String).substring(0, 8)} • ' : ''}${_fmtDate(r['created_at']?.toString())}',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            if (status == 'requested') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RButton(
                      label: 'Reject',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          _decide(context, state, id,
                              'rejected'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RButton(
                      label: 'Approve',
                      small: true,
                      onPressed: () =>
                          _decide(context, state, id,
                              'approved'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Mark Completed',
                fullWidth: true,
                small: true,
                onPressed: () =>
                    _decide(context, state, id,
                        'completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, AppState state,
      String id, String status) async {
    final ok = await state.updateRefund(id, status);
    if (context.mounted && !ok) {
      _snack(context, 'Update failed. Try again.');
    }
  }
}

/// Ambulance fleet from Supabase with status management.
class AdminAmbulanceScreen extends StatefulWidget {
  const AdminAmbulanceScreen({super.key});

  @override
  State<AdminAmbulanceScreen> createState() =>
      _AdminAmbulanceScreenState();
}

class _AdminAmbulanceScreenState
    extends State<AdminAmbulanceScreen> {
  bool _loading = true;

  static const _statuses = [
    'available',
    'on_trip',
    'maintenance',
    'offline',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadAmbulances();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    if (state.ambulances.isEmpty) {
      return const REmptyState(
        icon: Icons.emergency_outlined,
        title: 'No ambulances',
        subtitle:
            'Fleet vehicles will appear here once added.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.ambulances.length,
        itemBuilder: (_, i) =>
            _card(context, state, state.ambulances[i]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> a) {
    final id = '${a['id']}';
    final status = '${a['status'] ?? 'available'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListTile(
          leading: _tile(context, Icons.emergency,
              RemedooTheme.emergency),
          title: Text('${a['vehicle_number'] ?? '—'}',
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${a['driver_name'] ?? '—'} • ${a['driver_phone'] ?? '—'}'),
          trailing: DropdownButton<String>(
            value:
                _statuses.contains(status) ? status : null,
            underline: const SizedBox.shrink(),
            items: _statuses
                .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.replaceAll('_', ' '))))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              final ok = await state.updateAmbulance(
                  id, {'status': v});
              if (context.mounted && !ok) {
                _snack(
                    context, 'Update failed. Try again.');
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Pharmacy stock editor backed by the Supabase `medicines` table.
class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() =>
      _AdminInventoryScreenState();
}

class _AdminInventoryScreenState
    extends State<AdminInventoryScreen> {
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context)
        .loadAdminTable('medicines');
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    var rows = state.adminTable('medicines');
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows = rows
          .where((m) =>
              '${m['name'] ?? ''}'.toLowerCase().contains(q))
          .toList();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: RTextField(
            hint: 'Search medicines…',
            prefixIcon: const Icon(Icons.search),
            onChanged: (v) =>
                setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : rows.isEmpty
                  ? const REmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No medicines',
                      subtitle:
                          'Stock appears here once medicines are added.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        itemCount: rows.length,
                        itemBuilder: (_, i) => _row(
                            context, state, scheme, rows[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, AppState state,
      ColorScheme scheme, Map<String, dynamic> m) {
    final id = '${m['id']}';
    final stock =
        (m['stock_quantity'] as num?)?.toInt() ?? 0;
    final inStock = m['in_stock'] != false;
    final price = (m['price'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _tile(context, Icons.medication,
                RemedooTheme.teal,
                size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('${m['name'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${m['unit'] ?? 'strip'} • ${inr(price)}${inStock ? '' : ' • OUT OF STOCK'}',
                      style: TextStyle(
                          fontSize: 12,
                          color: inStock
                              ? scheme.onSurfaceVariant
                              : RemedooTheme.emergency)),
                ],
              ),
            ),
            QtyStepper(
              qty: stock,
              onMinus: () => _setStock(
                  context, state, id, stock - 1),
              onPlus: () => _setStock(
                  context, state, id, stock + 1),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStock(BuildContext context, AppState state,
      String id, int qty) async {
    if (qty < 0) return;
    final ok = await state.adminSaveRow('medicines', {
      'id': id,
      'stock_quantity': qty,
      'in_stock': qty > 0,
    });
    if (context.mounted && !ok) {
      _snack(context, 'Stock update failed. Try again.');
    }
  }
}
