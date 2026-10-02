import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Lab portal: test catalog CRUD, bookings, report upload (demo).
class LabPortalScreen extends StatefulWidget {
  const LabPortalScreen({super.key});

  @override
  State<LabPortalScreen> createState() => _LabPortalScreenState();
}

class _LabPortalScreenState extends State<LabPortalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Lab _me = labs[0];

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_me.name),
        bottom: TabBar(
          controller: _tabs,
          labelColor: RemedooTheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: RemedooTheme.primary,
          tabs: const [
            Tab(text: 'Test Catalog'),
            Tab(text: 'Bookings'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_catalog(), _bookings(), _reports()],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _testDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Test'),
            )
          : null,
    );
  }

  Widget _catalog() {
    final list = labTests.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final t = list[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(t.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(t.category),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(inr(t.price),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: RemedooTheme.primary)),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _testDialog(t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: RemedooTheme.emergency),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Delete test?',
                      message: 'Remove "${t.name}" from the catalog?',
                      confirmLabel: 'Delete',
                    );
                    if (ok && mounted) {
                      labTests.remove(t);
                      AppStateScope.of(context).refresh();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _testDialog(LabTest? existing) {
    final name = TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(
        text: existing != null ? existing.price.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add Test' : 'Edit Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration:
                    const InputDecoration(labelText: 'Test name')),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Price (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(price.text) ?? 0;
              if (existing == null) {
                labTests.add(LabTest(
                  id: 't${DateTime.now().millisecondsSinceEpoch}',
                  name: name.text.trim(),
                  price: p,
                ));
              } else {
                final idx = labTests.indexOf(existing);
                labTests[idx] = LabTest(
                  id: existing.id,
                  name: name.text.trim(),
                  price: p,
                  turnaround: existing.turnaround,
                  category: existing.category,
                );
              }
              AppStateScope.of(context).refresh();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _bookings() {
    final state = AppStateScope.of(context);
    final list =
        state.appointments.where((a) => a.kind == 'lab').toList();
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.science,
        title: 'No bookings',
        subtitle: 'Patient test bookings will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final a = list[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(a.doctorName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${a.dateLabel} • ${a.timeLabel}\n${a.tests.length} tests'),
            isThreeLine: true,
            trailing: StatusChip(status: a.status),
          ),
        );
      },
    );
  }

  Widget _reports() {
    final state = AppStateScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload report',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  'Attach a completed report PDF for a booking. (demo)',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    state.addNotification(
                      title: 'Report uploaded',
                      message:
                          'Your lab report is ready to view.',
                      category: 'system',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Report uploaded! (demo)')),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload PDF'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
