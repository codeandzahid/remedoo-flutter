import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import 'widgets.dart';

/// Lab test catalogue + packages manager (form-pages audit
/// Panelist 2 / M11: lab_tests and lab_test_packages had full
/// lab-manage RLS but the lab panel never read or wrote them —
/// a lab could not add, price or edit a single test, and the
/// patient catalogue had to fall back to mock data).
class LabCatalogueManager extends StatefulWidget {
  final SupabaseRepository repo;

  const LabCatalogueManager({super.key, required this.repo});

  @override
  State<LabCatalogueManager> createState() =>
      _LabCatalogueManagerState();
}

class _LabCatalogueManagerState extends State<LabCatalogueManager> {
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tests = await widget.repo.fetchOwnLabTests();
    final packages = await widget.repo.fetchOwnLabPackages();
    if (!mounted) return;
    setState(() {
      _tests = tests;
      _packages = packages;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editTest([Map<String, dynamic>? existing]) async {
    final e = existing ?? {};
    final name = TextEditingController(text: '${e['name'] ?? ''}');
    final category =
        TextEditingController(text: '${e['category'] ?? 'General'}');
    final price = TextEditingController(text: '${e['price'] ?? ''}');
    final discount = TextEditingController(
        text: '${e['discount_percent'] ?? ''}');
    final sampleType =
        TextEditingController(text: '${e['sample_type'] ?? 'Blood'}');
    final turnaround = TextEditingController(
        text: '${e['turnaround_time'] ?? '24 hours'}');
    final homeFee = TextEditingController(
        text: '${e['home_collection_fee'] ?? ''}');
    final description =
        TextEditingController(text: '${e['description'] ?? ''}');
    var fasting = e['requires_fasting'] == true;
    var home = e['home_collection'] != false;
    var popular = e['is_popular'] == true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Add test' : 'Edit test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Test name *')),
                TextField(
                    controller: category,
                    decoration:
                        const InputDecoration(labelText: 'Category')),
                TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Price (₹) *')),
                TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Discount %')),
                TextField(
                    controller: sampleType,
                    decoration: const InputDecoration(
                        labelText: 'Sample type')),
                TextField(
                    controller: turnaround,
                    decoration: const InputDecoration(
                        labelText: 'Turnaround time')),
                TextField(
                    controller: homeFee,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Home collection fee (₹)')),
                TextField(
                    controller: description,
                    decoration: const InputDecoration(
                        labelText: 'Description')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Requires fasting'),
                  value: fasting,
                  onChanged: (v) => setD(() => fasting = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Home collection available'),
                  value: home,
                  onChanged: (v) => setD(() => home = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Popular test'),
                  value: popular,
                  onChanged: (v) => setD(() => popular = v),
                ),
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
    if (name.text.trim().isEmpty ||
        double.tryParse(price.text.trim()) == null) {
      _snack('A test needs a name and a price.');
      return;
    }
    final ok = await widget.repo.upsertOwnLabTest({
      if (existing != null) 'id': '${existing['id']}',
      'name': name.text.trim(),
      'category': category.text.trim().isEmpty
          ? 'General'
          : category.text.trim(),
      'price': double.parse(price.text.trim()),
      'discount_percent': double.tryParse(discount.text.trim()) ?? 0,
      'sample_type': sampleType.text.trim(),
      'turnaround_time': turnaround.text.trim(),
      'home_collection_fee':
          double.tryParse(homeFee.text.trim()) ?? 0,
      'description': description.text.trim(),
      'requires_fasting': fasting,
      'home_collection': home,
      'is_popular': popular,
    });
    _snack(ok ? 'Test saved.' : 'Could not save. Try again.');
    if (ok) _load();
  }

  Future<void> _editPackage([Map<String, dynamic>? existing]) async {
    final e = existing ?? {};
    final name = TextEditingController(text: '${e['name'] ?? ''}');
    final price = TextEditingController(
        text: '${e['package_price'] ?? ''}');
    final discount = TextEditingController(
        text: '${e['discount_percent'] ?? ''}');
    final description =
        TextEditingController(text: '${e['description'] ?? ''}');
    var active = e['is_active'] != false;
    final chosen = <String>{
      if (e['tests'] is List)
        for (final t in (e['tests'] as List))
          if (t is Map) '${t['test_id'] ?? ''}',
    }..remove('');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title:
              Text(existing == null ? 'Add package' : 'Edit package'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(
                        labelText: 'Package name *')),
                TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Package price (₹) *')),
                TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Discount %')),
                TextField(
                    controller: description,
                    decoration: const InputDecoration(
                        labelText: 'Description')),
                const SizedBox(height: 8),
                const Text('Tests included',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                for (final t in _tests)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${t['name']}'),
                    value: chosen.contains('${t['id']}'),
                    onChanged: (v) => setD(() {
                      if (v == true) {
                        chosen.add('${t['id']}');
                      } else {
                        chosen.remove('${t['id']}');
                      }
                    }),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active (patients can book it)'),
                  value: active,
                  onChanged: (v) => setD(() => active = v),
                ),
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
    if (name.text.trim().isEmpty ||
        double.tryParse(price.text.trim()) == null) {
      _snack('A package needs a name and a price.');
      return;
    }
    final ok = await widget.repo.upsertOwnLabPackage({
      if (existing != null) 'id': '${existing['id']}',
      'name': name.text.trim(),
      'description': description.text.trim(),
      'tests': [
        for (final t in _tests)
          if (chosen.contains('${t['id']}'))
            {'test_id': '${t['id']}', 'test_name': '${t['name']}'},
      ],
      'package_price': double.parse(price.text.trim()),
      'discount_percent': double.tryParse(discount.text.trim()) ?? 0,
      'is_active': active,
    });
    _snack(ok ? 'Package saved.' : 'Could not save. Try again.');
    if (ok) _load();
  }

  Future<void> _confirmDelete(String label, Future<bool> Function() run) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
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
    final ok = await run();
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
            title: 'Tests & Packages',
            subtitle: 'Your catalogue — patients book from this list',
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_tests.isEmpty)
              Text('No tests yet. Add your first test below.',
                  style: TextStyle(color: scheme.onSurfaceVariant))
            else
              for (final t in _tests)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${t['name']}'),
                  subtitle: Text(
                      '${t['category'] ?? 'General'} • ₹${t['price']} '
                      '• ${t['turnaround_time'] ?? ''}'
                      '${t['home_collection'] == true ? ' • Home' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editTest(t),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _confirmDelete('test',
                            () => widget.repo.deleteOwnLabTest('${t['id']}')),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            RButton(
              label: 'Add test',
              icon: Icons.add,
              small: true,
              variant: RButtonVariant.outline,
              onPressed: () => _editTest(),
            ),
            const Divider(height: 26),
            const Text('Packages',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (_packages.isEmpty)
              Text('No packages yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant))
            else
              for (final p in _packages)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${p['name']}'),
                  subtitle: Text(
                      '₹${p['package_price']} • '
                      '${p['tests'] is List ? (p['tests'] as List).length : 0} tests'
                      '${p['is_active'] == false ? ' • Inactive' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editPackage(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _confirmDelete('package',
                            () => widget.repo
                                .deleteOwnLabPackage('${p['id']}')),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
            RButton(
              label: 'Add package',
              icon: Icons.add,
              small: true,
              variant: RButtonVariant.outline,
              onPressed: () => _editPackage(),
            ),
          ],
        ],
      ),
    );
  }
}
