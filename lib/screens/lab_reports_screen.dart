import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'lab_report_detail_screen.dart';

/// My Lab Reports: orange gradient header with in-header search + status
/// pills, report cards with status icon tiles — matches LabReports.tsx.
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

  bool get _completed {
    final c = _chip.toLowerCase();
    return c == 'completed';
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
    if (_chip == 'In Progress') {
      list = list
          .where((r) => r.status.toLowerCase() != 'completed')
          .toList();
    } else if (_chip == 'Completed') {
      list = list
          .where((r) => r.status.toLowerCase() == 'completed')
          .toList();
    }
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderBack(
                        onTap: () => Navigator.maybePop(context)),
                    const SizedBox(width: 12),
                    const Text('My Lab Reports',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search tests or labs…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color:
                            Colors.white.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor:
                        Colors.white.withValues(alpha: 0.18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['All', 'In Progress', 'Completed']
                      .map((c) => Padding(
                            padding:
                                const EdgeInsets.only(right: 8),
                            child: _headerPill(c),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              child: list.isEmpty
                  ? REmptyState(
                      icon: Icons.science_outlined,
                      title: _completed
                          ? 'No completed reports'
                          : 'No lab reports found',
                      subtitle:
                          'Your test reports will appear here once ready.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await Future.delayed(
                            const Duration(milliseconds: 500));
                        if (mounted) setState(() {});
                      },
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => StaggerItem(
                          index: i % 6,
                          child: _card(list[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerPill(String label) {
    final sel = _chip == label;
    return Material(
      color: sel
          ? Colors.white
          : Colors.white.withValues(alpha: 0.18),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: () => setState(() => _chip = label),
        customBorder: const StadiumBorder(),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: sel ? RemedooTheme.primary : Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(LabReport r) {
    final completed = r.status.toLowerCase() == 'completed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RCard(
        onTap: () => pushPage(context, LabReportDetailScreen(report: r)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (completed
                        ? RemedooTheme.success
                        : RemedooTheme.warning)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                completed
                    ? Icons.check_circle_outline
                    : Icons.science_outlined,
                color: completed
                    ? RemedooTheme.success
                    : RemedooTheme.warning,
                size: 22,
              ),
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
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.tests.isNotEmpty
                                  ? r.tests
                                      .map((t) => t['name'] ?? '')
                                      .join(', ')
                                  : 'Lab Report',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(r.labName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(status: r.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                          '${r.date.day}/${r.date.month}/${r.date.year}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Icon(Icons.science_outlined,
                          size: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${r.tests.length} tests',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                  if (completed) ...[
                    const SizedBox(height: 10),
                    RButton(
                      label: 'Download Report',
                      icon: Icons.download_outlined,
                      small: true,
                      variant: RButtonVariant.outline,
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
                ],
              ),
            ),
          ],
        ),
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
