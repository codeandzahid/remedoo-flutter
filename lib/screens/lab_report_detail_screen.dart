import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Report detail: gradient header, test info, lab, schedule, results table,
/// download — matches LabReportDetail.tsx.
class LabReportDetailScreen extends StatelessWidget {
  final LabReport report;

  const LabReportDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: [
                _HeaderBack(
                    onTap: () => Navigator.maybePop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Lab Report Details',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      Text('#${r.id.toUpperCase()}',
                          style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: 0.7),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: DetailSplit(
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _testInfoCard(context, r),
                    const SizedBox(height: 12),
                    _labCard(context, r),
                    const SizedBox(height: 12),
                    _scheduleCard(context, r),
                    const SizedBox(height: 12),
                    const Text('Test Results',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    RCard(
                      padding: EdgeInsets.zero,
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
                                    borderRadius:
                                        BorderRadius.circular(8),
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
                    RCard(
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
                          const SizedBox(height: 4),
                          Text('Patient: ${r.patientName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RButton(
                      label: 'Download Report',
                      icon: Icons.download_outlined,
                      fullWidth: true,
                      onPressed: () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Downloading report… (demo)')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testInfoCard(BuildContext context, LabReport r) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.science_outlined,
                color: scheme.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.tests.isNotEmpty
                            ? r.tests
                                .map((t) => t['name'] ?? '')
                                .join(', ')
                            : 'Lab Report',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(status: r.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${r.tests.length} tests',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labCard(BuildContext context, LabReport r) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Laboratory',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Text(r.labName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Lab location on file',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, LabReport r) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Date',
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                        Text(
                            '${r.date.day}/${r.date.month}/${r.date.year}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('Patient',
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant)),
                        Text(r.patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBack extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderBack({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.arrow_back,
              size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
