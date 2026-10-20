import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/file_download.dart';
import '../widgets/widgets.dart';
import 'lab_report_detail_screen.dart';
import '../app_navigator.dart';

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
    if (!state.isSignedIn) {
      return const GuestGate();
    }
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
                        onTap: () => goBack(context)),
                    const SizedBox(width: 12),
                    const Text('My Lab Reports',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Material(
                      color: Colors.white,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        onTap: () => _uploadReport(state),
                        customBorder: const StadiumBorder(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_file,
                                  size: 16,
                                  color: RemedooTheme.primary),
                              const SizedBox(width: 5),
                              Text('Upload',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: RemedooTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                          'Your test reports will appear here once ready. You can also upload a report from any lab.',
                      actionLabel: 'Upload a Report',
                      onAction: () => _uploadReport(state),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        // Reload the on-device datasets from
                        // storage for real — this previously just
                        // waited 500ms and repainted the same list
                        // (audit fix 2026-10-19).
                        await state.loadPersistedState();
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

  /// Upload own report (2026-10-19): pick a PDF/image from any lab or
  /// doctor, name it, store the file, and list it with the reports.
  Future<void> _uploadReport(AppState state) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty || !mounted) return;
    final file = files.single;
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {}
    if (!mounted) return;
    final nameCtrl = TextEditingController(
        text: file.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), ''));
    final sourceCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Report name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: sourceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Lab / doctor (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Upload')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading report...')));
    final url = await state.supabaseRepository
        .uploadPrescriptionData(bytes, file.path, file.name);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Upload failed. Check your connection and try again.')));
      return;
    }
    state.addUploadedReport(LabReport(
      id: 'U${DateTime.now().millisecondsSinceEpoch}',
      patientName: state.userName,
      labName: sourceCtrl.text.trim().isEmpty
          ? 'My Upload'
          : sourceCtrl.text.trim(),
      date: DateTime.now(),
      status: 'Completed',
      tests: [
        {
          'name': nameCtrl.text.trim().isEmpty
              ? 'Uploaded Report'
              : nameCtrl.text.trim(),
          'result': 'Uploaded file',
          'unit': '-',
          'range': '-',
          'flag': 'Normal',
        }
      ],
      fileUrl: url,
      fileName:
          nameCtrl.text.trim().isEmpty ? file.name : nameCtrl.text.trim(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report uploaded.')));
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

  /// Builds a real text report from the report's data and downloads it.
  void _downloadReport(BuildContext context, LabReport r) {
    final buf = StringBuffer()
      ..writeln('REMEDOO LAB REPORT')
      ..writeln('==================')
      ..writeln('Report ID : ${r.id}')
      ..writeln('Patient   : ${r.patientName}')
      ..writeln('Lab       : ${r.labName}')
      ..writeln(
          'Date      : ${r.date.day}/${r.date.month}/${r.date.year}')
      ..writeln('Status    : ${r.status}')
      ..writeln('')
      ..writeln('TESTS')
      ..writeln('-----');
    for (final t in r.tests) {
      final name = t['name'] ?? 'Test';
      final result = t['result'] ?? '';
      final range = t['range'] ?? '';
      buf.writeln(
          '- $name${result.isNotEmpty ? ': $result' : ''}${range.isNotEmpty ? ' (Ref: $range)' : ''}');
    }
    buf
      ..writeln('')
      ..writeln('Generated by Remedoo');
    downloadTextFile('lab-report-${r.id}.txt', buf.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report downloaded.')),
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
                              r.isUploaded
                                  ? (r.fileName ?? 'Uploaded Report')
                                  : r.tests.isNotEmpty
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
                    Row(
                      children: [
                        RButton(
                          label: 'Download Report',
                          icon: Icons.download_outlined,
                          small: true,
                          variant: RButtonVariant.outline,
                          onPressed: () =>
                              _downloadReport(context, r),
                        ),
                        const Spacer(),
                        // Uploaded reports can be removed from
                        // the device list (audit fix 2026-10-19 —
                        // there was no delete at all before).
                        if (r.isUploaded)
                          TextButton.icon(
                            onPressed: () async {
                              final st = AppStateScope.of(context);
                              final ok = await confirmDialog(
                                context,
                                title: 'Delete this report?',
                                message:
                                    'It will be removed from your reports list on this device.',
                                confirmLabel: 'Delete',
                              );
                              if (ok) st.removeUploadedReport(r.id);
                            },
                            icon: const Icon(Icons.delete_outline,
                                size: 16),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                                foregroundColor:
                                    RemedooTheme.destructive),
                          ),
                      ],
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
