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
            if (r['appointment_id'] != null)
              Text(
                  'Appointment ${(r['appointment_id'] as String).length > 8 ? (r['appointment_id'] as String).substring(0, 8) : r['appointment_id']}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant)),
            if (r['user_id'] != null)
              Text('Patient ${r['user_id']}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant)),
            if ('${r['admin_notes'] ?? ''}'.isNotEmpty)
              Text('Admin note: ${r['admin_notes']}',
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
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
                              'rejected',
                              askNote: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RButton(
                      label: 'Approve',
                      small: true,
                      onPressed: () =>
                          _decide(context, state, id,
                              'processing'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'processing') ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Mark Completed',
                fullWidth: true,
                small: true,
                onPressed: () =>
                    _decide(context, state, id,
                        'completed',
                        askNote: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, AppState state,
      String id, String status,
      {bool askNote = false}) async {
    String? note;
    if (askNote) {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(status == 'rejected'
              ? 'Reject refund'
              : 'Complete refund'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Admin note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null || !context.mounted) return;
    }
    final ok = await state.updateRefund(id, status,
        adminNotes: (note ?? '').isEmpty ? null : note);
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


  /// Add / edit a fleet vehicle (audit Admin gap 7: the fleet
  /// could not be created or edited at all — vehicle number and
  /// driver details were display-only).
  Future<void> _editAmbulance(BuildContext context, AppState state,
      [Map<String, dynamic>? existing]) async {
    final e = existing ?? {};
    final vehicle =
        TextEditingController(text: '${e['vehicle_number'] ?? ''}');
    final driver =
        TextEditingController(text: '${e['driver_name'] ?? ''}');
    final phone =
        TextEditingController(text: '${e['driver_phone'] ?? ''}');
    final equipment = TextEditingController(
        text: '${e['equipment_details'] ?? ''}');
    var type = '${e['vehicle_type'] ?? 'BLS'}';
    var status = '${e['status'] ?? 'available'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null
              ? 'Add ambulance'
              : 'Edit ambulance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: vehicle,
                    decoration: const InputDecoration(
                        labelText: 'Vehicle number *')),
                TextField(
                    controller: driver,
                    decoration: const InputDecoration(
                        labelText: 'Driver name')),
                TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Driver phone')),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration:
                      const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'BLS',
                        child: Text('BLS — Basic Life Support')),
                    DropdownMenuItem(
                        value: 'ALS',
                        child: Text('ALS — Advanced Life Support')),
                    DropdownMenuItem(value: 'ICU', child: Text('ICU')),
                    DropdownMenuItem(
                        value: 'PTA',
                        child: Text('PTA — Patient Transport')),
                  ],
                  onChanged: (v) => setD(() => type = v ?? 'BLS'),
                ),
                DropdownButtonFormField<String>(
                  initialValue:
                      _statuses.contains(status) ? status : 'available',
                  decoration:
                      const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in _statuses)
                      DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' '))),
                  ],
                  onChanged: (v) =>
                      setD(() => status = v ?? 'available'),
                ),
                TextField(
                    controller: equipment,
                    decoration: const InputDecoration(
                        labelText: 'Equipment details')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (vehicle.text.trim().isEmpty) {
      _snack(context, 'Vehicle number is required.');
      return;
    }
    final ok = await state.adminSaveRow('ambulances', {
      if (existing != null) 'id': '${existing['id']}',
      'vehicle_number': vehicle.text.trim(),
      'driver_name': driver.text.trim(),
      'driver_phone': phone.text.trim(),
      'vehicle_type': type,
      'status': status,
      'equipment_details': equipment.text.trim(),
    });
    if (!context.mounted) return;
    _snack(context,
        ok ? 'Ambulance saved.' : 'Save failed. Try again.');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    if (state.ambulances.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const REmptyState(
            icon: Icons.emergency_outlined,
            title: 'No ambulances',
            subtitle:
                'Fleet vehicles will appear here once added.',
          ),
          RButton(
            label: 'Add ambulance',
            icon: Icons.add,
            onPressed: () => _editAmbulance(context, state),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.ambulances.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RButton(
                label: 'Add ambulance',
                icon: Icons.add,
                variant: RButtonVariant.outline,
                onPressed: () => _editAmbulance(context, state),
              ),
            );
          }
          return _card(context, state, state.ambulances[i - 1]);
        },
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit vehicle',
                onPressed: () =>
                    _editAmbulance(context, state, a),
              ),
              DropdownButton<String>(
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
            ],
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
            Column(
              children: [
                QtyStepper(
                  qty: stock,
                  onMinus: () => _setStock(
                      context, state, id, stock - 1),
                  onPlus: () => _setStock(
                      context, state, id, stock + 1),
                ),
                TextButton(
                  onPressed: () =>
                      _editStock(context, state, m, stock),
                  child: const Text('Set exact',
                      style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Exact numeric stock entry (audit Admin gap 27: stock could
  /// only be stepped ±1, so a bulk correction meant hundreds of
  /// taps).
  Future<void> _editStock(BuildContext context, AppState state,
      Map<String, dynamic> m, int current) async {
    final ctrl =
        TextEditingController(text: current.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock for ${m['name'] ?? 'medicine'}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Quantity in stock',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value < 0) return;
    await _setStock(context, state, '${m['id']}', value);
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
