import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Report detail: patient, lab, results table, Download (demo).
/// Adaptive: two-column (report + actions side panel) on tablets and larger.
class LabReportDetailScreen extends StatelessWidget {
  final LabReport report;

  const LabReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DetailSplit(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      InfoRow(
                          icon: Icons.person_outline,
                          label: 'Patient',
                          value: r.patientName),
                      InfoRow(
                          icon: Icons.science,
                          label: 'Lab',
                          value: r.labName),
                      InfoRow(
                          icon: Icons.calendar_month,
                          label: 'Date',
                          value:
                              '${r.date.day}/${r.date.month}/${r.date.year}'),
                      InfoRow(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: r.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Test Results',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Test')),
                      DataColumn(label: Text('Result')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Reference')),
                      DataColumn(label: Text('Flag')),
                    ],
                    rows: r.tests.map((t) {
                      final flagged = t['flag'] != 'Normal';
                      return DataRow(cells: [
                        DataCell(Text(t['name']!)),
                        DataCell(Text(t['result']!,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: flagged
                                    ? RemedooTheme.emergency
                                    : null))),
                        DataCell(Text(t['unit']!)),
                        DataCell(Text(t['range']!)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (flagged
                                      ? RemedooTheme.emergency
                                      : RemedooTheme.ratingGreen)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t['flag']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: flagged
                                    ? RemedooTheme.emergency
                                    : RemedooTheme.ratingGreen,
                              ),
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          side: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Summary',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      StatusChip(status: r.status),
                      const SizedBox(height: 8),
                      Text('${r.tests.length} tests',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Downloading report… (demo)')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
