import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import 'widgets.dart';
import 'form_kit.dart';

/// Pharmacy medicines + stock manager (form-pages audit
/// Panelist 3: the medicines table had no panel form at all —
/// a pharmacy could not list a medicine, set its price, or mark
/// it out of stock). Writes go through the "Pharmacies can
/// manage own medicines" RLS policy (migration
/// pharmacy_medicines_policy.sql); until the owner applies it,
/// saves fail closed with a clear message.
class PharmacyMedicinesManager extends StatefulWidget {
  final SupabaseRepository repo;

  const PharmacyMedicinesManager({super.key, required this.repo});

  @override
  State<PharmacyMedicinesManager> createState() =>
      _PharmacyMedicinesManagerState();
}

class _PharmacyMedicinesManagerState
    extends State<PharmacyMedicinesManager> {
  List<Map<String, dynamic>> _medicines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.repo.fetchOwnMedicines();
    if (!mounted) return;
    setState(() {
      _medicines = rows;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final e = existing ?? {};
    final name = TextEditingController(text: '${e['name'] ?? ''}');
    final generic =
        TextEditingController(text: '${e['generic_name'] ?? ''}');
    // Structured values are dropdowns, not free text (audit
    // M28: the panelist surface had no structured inputs at
    // all). Existing off-list values are kept as an option so
    // editing never silently rewrites them.
    var category = '${e['category'] ?? 'General'}';
    const medCategories = [
      'General', 'Tablet', 'Syrup', 'Injection', 'Cream',
      'Drops', 'Inhaler', 'Supplement', 'First Aid', 'Other',
    ];
    if (!medCategories.contains(category)) {
      medCategories.add(category);
    }
    final price = TextEditingController(text: '${e['price'] ?? ''}');
    final discount = TextEditingController(
        text: '${e['discount_percent'] ?? ''}');
    var unit = '${e['unit'] ?? 'strip'}';
    const medUnits = [
      'strip', 'bottle', 'tablet', 'syrup', 'tube', 'pack', 'piece',
    ];
    if (!medUnits.contains(unit)) medUnits.add(unit);
    final stock = TextEditingController(
        text: '${e['stock_quantity'] ?? '0'}');
    final manufacturer =
        TextEditingController(text: '${e['manufacturer'] ?? ''}');
    final batch =
        TextEditingController(text: '${e['batch_number'] ?? ''}');
    final description =
        TextEditingController(text: '${e['description'] ?? ''}');
    var rx = e['requires_prescription'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(
              existing == null ? 'Add medicine' : 'Edit medicine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(controller: name, label: 'Medicine name *'),
                RKitField(controller: generic, label: 'Generic / salt name'),
                RKitDropdown<String>(
                  label: 'Category',
                  value: category,
                  items: [
                    for (final c in medCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => category = v ?? 'General',
                ),
                RKitField(controller: price, keyboardType: TextInputType.number, label: 'Price (₹) *'),
                RKitField(controller: discount, keyboardType: TextInputType.number, label: 'Discount %'),
                RKitDropdown<String>(
                  label: 'Unit',
                  value: unit,
                  items: [
                    for (final u in medUnits)
                      DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => unit = v ?? 'strip',
                ),
                RKitField(controller: stock, keyboardType: TextInputType.number, label: 'Stock quantity'),
                RKitField(controller: manufacturer, label: 'Manufacturer'),
                RKitField(controller: batch, label: 'Batch number'),
                RKitField(controller: description, label: 'Description'),
                RFormSwitchTile(title: 'Prescription required', value: rx, onChanged: (v) => setD(() => rx = v)),
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
    if (name.text.trim().isEmpty ||
        double.tryParse(price.text.trim()) == null) {
      _snack('A medicine needs a name and a price.');
      return;
    }
    final qty = int.tryParse(stock.text.trim()) ?? 0;
    final ok = await widget.repo.upsertOwnMedicine({
      if (existing != null) 'id': '${existing['id']}',
      'name': name.text.trim(),
      'generic_name': generic.text.trim(),
      'category': category,
      'price': double.parse(price.text.trim()),
      'discount_percent': double.tryParse(discount.text.trim()) ?? 0,
      'unit': unit,
      'stock_quantity': qty,
      'in_stock': qty > 0,
      'manufacturer': manufacturer.text.trim(),
      'batch_number': batch.text.trim(),
      'description': description.text.trim(),
      'requires_prescription': rx,
    });
    _snack(ok
        ? 'Medicine saved.'
        : 'Could not save. If this keeps failing, the medicines '
            'policy migration may not be applied yet.');
    if (ok) _load();
  }

  Future<void> _setStock(Map<String, dynamic> m, int delta) async {
    final current = (m['stock_quantity'] as num?)?.toInt() ?? 0;
    final next = (current + delta).clamp(0, 100000);
    final ok =
        await widget.repo.updateMedicineStock('${m['id']}', next);
    if (ok) _load();
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${m['name']}?'),
        content: const Text(
            'Patients will no longer see this medicine in your store.'),
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
    final ok = await widget.repo.deleteOwnMedicine('${m['id']}');
    _snack(ok ? 'Deleted.' : 'Could not delete. Try again.');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RSectionHeader(
            title: 'Medicines & Stock',
            subtitle: 'Your store catalogue — patients order from this list',
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_medicines.isEmpty)
              Text('No medicines yet. Add your first medicine below.',
                  style: TextStyle(color: scheme.onSurfaceVariant))
            else
              for (final m in _medicines)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${m['name']}'),
                  subtitle: Text(
                    '₹${m['price']}'
                    '${'${m['unit'] ?? ''}'.isNotEmpty ? ' / ${m['unit']}' : ''}'
                    ' • Stock: ${(m['stock_quantity'] as num?)?.toInt() ?? 0}'
                    '${m['in_stock'] == true ? '' : ' • OUT OF STOCK'}'
                    '${m['requires_prescription'] == true ? ' • Rx' : ''}',
                    style: TextStyle(
                      color: m['in_stock'] == true
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20),
                        tooltip: 'One less in stock',
                        onPressed: () => _setStock(m, -1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 20),
                        tooltip: 'One more in stock',
                        onPressed: () => _setStock(m, 1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _edit(m),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _delete(m),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            RButton(
              label: 'Add medicine',
              icon: Icons.add,
              small: true,
              variant: RButtonVariant.outline,
              onPressed: () => _edit(),
            ),
          ],
        ],
      ),
    );
  }
}
