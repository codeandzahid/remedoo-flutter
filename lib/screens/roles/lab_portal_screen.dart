import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models.dart';
import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
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
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: Theme.of(context).colorScheme.primary,
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
              backgroundColor:
                  Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              onPressed: () => _testDialog(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Test'),
            )
          : null,
    );
  }

  Widget _catalog() {
    final scheme = Theme.of(context).colorScheme;
    final list = labTests.toList();
    return MaxWidthBox(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final t = list[i];
          return StaggerItem(
            index: i % 6,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.science,
                        color: scheme.primary),
                  ),
                  title: Text(t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(t.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(inr(t.price),
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary)),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 20,
                            color: scheme.onSurfaceVariant),
                        tooltip: 'Edit',
                        onPressed: () => _testDialog(t),
                      ),
                      IconButton(
                        icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: RemedooTheme.emergency),
                        tooltip: 'Delete',
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Delete test?',
                            message:
                                'Remove "${t.name}" from the catalog?',
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
              ),
            ),
          );
        },
      ),
    );
  }

  void _testDialog(LabTest? existing) {
    final name =
        TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(
        text: existing != null
            ? existing.price.toStringAsFixed(0)
            : '');
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: Text(existing == null ? 'Add Test' : 'Edit Test',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RTextField(
                label: 'Test name',
                controller: name),
            const SizedBox(height: 12),
            RTextField(
              label: 'Price (₹)',
              controller: price,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Save',
            small: true,
            onPressed: () {
              final p = double.tryParse(price.text) ?? 0;
              if (existing == null) {
                labTests.add(LabTest(
                  id:
                      't${DateTime.now().millisecondsSinceEpoch}',
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
          ),
        ],
      ),
    );
  }

  Widget _bookings() {
    final state = AppStateScope.of(context);
    final list = state.appointments
        .where((a) => a.kind == 'lab')
        .toList();
    if (list.isEmpty) {
      return const REmptyState(
        icon: Icons.science_outlined,
        title: 'No bookings',
        subtitle: 'Patient test bookings will appear here.',
      );
    }
    return MaxWidthBox(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final a = list[i];
          return StaggerItem(
            index: i % 6,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: InitialsAvatar(
                      name: a.doctorName, radius: 22),
                  title: Text(a.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${a.dateLabel} • ${a.timeLabel}\n${a.tests.length} tests',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  trailing: StatusChip(status: a.status),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _reports() {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MaxWidthBox(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: scheme.primary
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.upload_file,
                          color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Upload report',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Attach a completed report PDF for a booking. (demo)',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                RButton(
                  label: 'Upload PDF',
                  icon: Icons.upload_file,
                  variant: RButtonVariant.outline,
                  onPressed: () {
                    state.addNotification(
                      title: 'Report uploaded',
                      message:
                          'Your lab report is ready to view.',
                      category: 'system',
                    );
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Report uploaded! (demo)')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
