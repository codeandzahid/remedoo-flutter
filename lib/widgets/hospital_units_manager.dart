import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import 'widgets.dart';
import 'form_kit.dart';

/// Hospital structure manager (form-pages audit Panelist 4:
/// departments, operation_theaters and hospital_equipment had
/// hospital-manage RLS and zero panel references — as did the
/// hospital_ambulance_config row that prices the hospital's own
/// ambulance service).
class HospitalUnitsManager extends StatefulWidget {
  final SupabaseRepository repo;

  const HospitalUnitsManager({super.key, required this.repo});

  @override
  State<HospitalUnitsManager> createState() =>
      _HospitalUnitsManagerState();
}

class _HospitalUnitsManagerState extends State<HospitalUnitsManager> {
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _ots = [];
  List<Map<String, dynamic>> _equipment = [];
  Map<String, dynamic>? _ambulance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.repo.fetchOwnHospitalUnits('departments');
    final o =
        await widget.repo.fetchOwnHospitalUnits('operation_theaters');
    final e =
        await widget.repo.fetchOwnHospitalUnits('hospital_equipment');
    final a = await widget.repo.fetchAmbulanceConfig();
    if (!mounted) return;
    setState(() {
      _departments = d;
      _ots = o;
      _equipment = e;
      _ambulance = a;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editUnit(
    String table,
    String singular, {
    Map<String, dynamic>? existing,
    required List<String> textFields,
    Map<String, List<String>> dropdowns = const {},
  }) async {
    final e = existing ?? {};
    final ctrls = {
      for (final f in textFields)
        f: TextEditingController(text: '${e[f] ?? ''}'),
    };
    final drops = {
      for (final entry in dropdowns.entries)
        entry.key: '${e[entry.key] ?? entry.value.first}',
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
              '${existing == null ? 'Add' : 'Edit'} $singular'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in textFields)
                  RKitField(
                    controller: ctrls[f],
                    label: _labelFor(f),
                  ),
                for (final entry in dropdowns.entries)
                  RKitDropdown<String>(
                    label: _labelFor(entry.key),
                    value: drops[entry.key],
                    items: [
                      for (final v in entry.value)
                        DropdownMenuItem(value: v, child: Text(v)),
                    ],
                    onChanged: (v) =>
                        setD(() => drops[entry.key] = v ?? drops[entry.key]!),
                  ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: RFormBrand.blue,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if ((ctrls['name']?.text.trim().isEmpty ?? false)) {
      _snack('A name is required.');
      return;
    }
    final ok = await widget.repo.upsertHospitalUnit(table, {
      if (existing != null) 'id': '${existing['id']}',
      for (final f in textFields) f: ctrls[f]!.text.trim(),
      ...drops,
    });
    _snack(ok ? 'Saved.' : 'Could not save. Try again.');
    if (ok) _load();
  }

  static String _labelFor(String field) {
    switch (field) {
      case 'name':
        return 'Name *';
      case 'description':
        return 'Description';
      case 'status':
        return 'Status';
      case 'notes':
        return 'Notes';
      case 'maintenance_notes':
        return 'Maintenance notes';
      default:
        return field;
    }
  }

  Future<void> _deleteUnit(
      String table, Map<String, dynamic> row) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${row['name']}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await widget.repo.deleteHospitalUnit(table, '${row['id']}');
    _snack(ok ? 'Deleted.' : 'Could not delete. Try again.');
    if (ok) _load();
  }

  Widget _unitSection(
    String title,
    String table,
    String singular,
    List<Map<String, dynamic>> rows, {
    required List<String> textFields,
    Map<String, List<String>> dropdowns = const {},
    required String Function(Map<String, dynamic>) subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Text('None added yet.',
              style: TextStyle(color: scheme.onSurfaceVariant))
        else
          for (final r in rows)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${r['name']}'),
              subtitle: Text(subtitle(r)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editUnit(table, singular,
                        existing: r,
                        textFields: textFields,
                        dropdowns: dropdowns),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _deleteUnit(table, r),
                  ),
                ],
              ),
            ),
        RButton(
          label: 'Add $singular',
          icon: Icons.add,
          small: true,
          variant: RButtonVariant.outline,
          onPressed: () => _editUnit(table, singular,
              textFields: textFields, dropdowns: dropdowns),
        ),
      ],
    );
  }

  Future<void> _editAmbulance() async {
    final a = _ambulance ?? {};
    final base = TextEditingController(text: '${a['base_fare'] ?? ''}');
    final perKm =
        TextEditingController(text: '${a['per_km_charge'] ?? ''}');
    final emergency = TextEditingController(
        text: '${a['emergency_surcharge'] ?? ''}');
    final night =
        TextEditingController(text: '${a['night_surcharge'] ?? ''}');
    final minimum =
        TextEditingController(text: '${a['minimum_charge'] ?? ''}');
    var enabled = a['service_enabled'] == true;
    var type = '${a['service_type'] ?? 'free'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ambulance service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RFormSwitchTile(
                  title: 'Ambulance service enabled',
                  value: enabled,
                  onChanged: (v) => setD(() => enabled = v),
                ),
                RKitDropdown<String>(
                  label: 'Service type',
                  value: type,
                  items: const [
                    DropdownMenuItem(
                        value: 'free', child: Text('Free')),
                    DropdownMenuItem(
                        value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(
                        value: 'conditional',
                        child: Text('Conditional')),
                  ],
                  onChanged: (v) => setD(() => type = v ?? 'free'),
                ),
                for (final (label, ctrl) in [
                  ('Base fare (₹)', base),
                  ('Per-km charge (₹)', perKm),
                  ('Emergency surcharge (₹)', emergency),
                  ('Night surcharge (₹)', night),
                  ('Minimum charge (₹)', minimum),
                ])
                  RKitField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    label: label,
                  ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: RFormBrand.blue,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    double n(TextEditingController c) =>
        double.tryParse(c.text.trim()) ?? 0;
    final ok = await widget.repo.saveAmbulanceConfig({
      'service_enabled': enabled,
      'service_type': type,
      'base_fare': n(base),
      'per_km_charge': n(perKm),
      'emergency_surcharge': n(emergency),
      'night_surcharge': n(night),
      'minimum_charge': n(minimum),
    });
    _snack(ok ? 'Ambulance settings saved.' : 'Could not save.');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RSectionHeader(
            title: 'Departments, Theatres & Equipment',
            subtitle: 'Your hospital structure, kept up to date by you',
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _unitSection(
              'Departments',
              'departments',
              'department',
              _departments,
              textFields: const ['name', 'description'],
              subtitle: (r) => '${r['description'] ?? ''}',
            ),
            const Divider(height: 26),
            _unitSection(
              'Operation theatres',
              'operation_theatres',
              'theatre',
              _ots,
              textFields: const ['name', 'notes'],
              dropdowns: const {
                'status': ['available', 'in_use', 'maintenance', 'closed'],
              },
              subtitle: (r) => '${r['status'] ?? 'available'}',
            ),
            const Divider(height: 26),
            _unitSection(
              'Equipment',
              'hospital_equipment',
              'equipment',
              _equipment,
              textFields: const ['name', 'maintenance_notes'],
              dropdowns: const {
                'status': ['operational', 'maintenance', 'out_of_order'],
              },
              subtitle: (r) => '${r['status'] ?? 'operational'}',
            ),
            const Divider(height: 26),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emergency_outlined, size: 22),
              title: const Text('Ambulance service',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_ambulance == null
                  ? 'Not configured'
                  : _ambulance!['service_enabled'] == true
                      ? 'Enabled • ${_ambulance!['service_type']} • Base ₹${_ambulance!['base_fare']} + ₹${_ambulance!['per_km_charge']}/km'
                      : 'Disabled'),
              trailing: RButton(
                label: 'Configure',
                small: true,
                variant: RButtonVariant.outline,
                onPressed: _editAmbulance,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
