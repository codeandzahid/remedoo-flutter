import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'lab_report_detail_screen.dart';

/// My Lab Reports with search + status chips.
class LabReportsScreen extends StatefulWidget {
  const LabReportsScreen({super.key});

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  final _search = TextEditingController();
  String _chip = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    var list = state.reports.toList();
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((r) =>
              r.labName.toLowerCase().contains(q) ||
              r.tests.any((t) => (t['name'] ?? '').toLowerCase().contains(q)))
          .toList();
    }
    if (_chip != 'All') {
      list = list
          .where((r) => r.status.toLowerCase() == _chip.toLowerCase())
          .toList();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Lab Reports')),
      body: MaxWidthBox(
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search reports…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: ['All', 'In Progress', 'Completed'].map((c) {
                final sel = c == _chip;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: sel,
                    onSelected: (_) => setState(() => _chip = c),
                    selectedColor: RemedooTheme.primary,
                    labelStyle: TextStyle(
                        color: sel
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.science,
                    title: 'No lab reports yet',
                    subtitle:
                        'Your test reports will appear here once ready.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => StaggerItem(
                      index: i % 6,
                      child: _card(list[i]),
                    ),
                  ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _card(LabReport r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: RemedooTheme.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.science, color: RemedooTheme.teal),
        ),
        title: Text(r.labName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${r.tests.length} tests • ${r.date.day}/${r.date.month}/${r.date.year}'),
        trailing: StatusChip(status: r.status),
        onTap: () => pushPage(context, LabReportDetailScreen(report: r)),
      ),
    );
  }
}
