import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_repository.dart';
import 'widgets.dart';

/// Lab sample-collection workflow (form-pages audit Panelist 2 /
/// Patient 11: lab_sample_collections was never touched and
/// "Report ready" uploaded nothing — it just flipped the
/// appointment status). From each booking the lab creates the
/// sample record, advances it scheduled → collected →
/// processing, and uploads the finished report (private
/// lab-reports bucket; the patient reads it under their own id).
class LabSamplesManager extends StatefulWidget {
  final SupabaseRepository repo;
  final List<Map<String, dynamic>> bookings;

  const LabSamplesManager({
    super.key,
    required this.repo,
    required this.bookings,
  });

  @override
  State<LabSamplesManager> createState() => _LabSamplesManagerState();
}

class _LabSamplesManagerState extends State<LabSamplesManager> {
  List<Map<String, dynamic>> _samples = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.repo.fetchLabSamples();
    if (!mounted) return;
    setState(() {
      _samples = rows;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Map<String, dynamic>? _sampleFor(String appointmentId) {
    for (final s in _samples) {
      if ('${s['appointment_id']}' == appointmentId) return s;
    }
    return null;
  }

  static String _testNameFrom(Map<String, dynamic> booking) {
    final notes = '${booking['notes'] ?? ''}';
    if (notes.startsWith('Tests:')) {
      final first = notes.substring(6).split('•').first.trim();
      return first;
    }
    return notes;
  }

  Future<void> _createSample(Map<String, dynamic> booking) async {
    final testName =
        TextEditingController(text: _testNameFrom(booking));
    final collector =
        TextEditingController(text: '${booking['collector_name'] ?? ''}');
    var type = '${booking['collection_type'] ?? ''}' == 'home'
        ? 'home'
        : 'walk_in';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Start sample record'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: testName,
                  decoration: const InputDecoration(
                      labelText: 'Test name(s) *'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                      labelText: 'Collection type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'walk_in', child: Text('Walk-in')),
                    DropdownMenuItem(
                        value: 'home',
                        child: Text('Home collection')),
                  ],
                  onChanged: (v) =>
                      setD(() => type = v ?? 'walk_in'),
                ),
                TextField(
                  controller: collector,
                  decoration: const InputDecoration(
                      labelText: 'Collector name (optional)'),
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
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (testName.text.trim().isEmpty) {
      _snack('The sample record needs the test name.');
      return;
    }
    final ok = await widget.repo.createLabSample({
      'appointment_id': '${booking['id']}',
      'patient_id': '${booking['patient_id'] ?? ''}',
      'test_name': testName.text.trim(),
      'collection_type': type,
      'collection_address': booking['collection_address'],
      'scheduled_date': '${booking['appointment_date'] ?? ''}'
              .length >= 10
          ? '${booking['appointment_date']}'.substring(0, 10)
          : DateTime.now().toIso8601String().substring(0, 10),
      'scheduled_time': booking['appointment_time'],
      if (collector.text.trim().isNotEmpty)
        'collector_name': collector.text.trim(),
    });
    _snack(ok
        ? 'Sample record created.'
        : 'Could not create. Try again.');
    if (ok) _load();
  }

  Future<void> _advance(Map<String, dynamic> sample, String status) async {
    final ok = await widget.repo.updateLabSample('${sample['id']}', {
      'status': status,
      if (status == 'collected')
        'collected_at': DateTime.now().toIso8601String(),
    });
    _snack(ok ? 'Updated.' : 'Could not update. Try again.');
    if (ok) _load();
  }

  Future<void> _uploadReport(Map<String, dynamic> sample) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.xFile.readAsBytes();
    final path = await widget.repo.uploadLabReport(
      patientId: '${sample['patient_id']}',
      sampleId: '${sample['id']}',
      fileName: file.name,
      bytes: bytes,
    );
    if (path == null) {
      _snack('Upload failed. Check your connection and try again.');
      return;
    }
    final url = await widget.repo
        .signedStorageUrl('lab-reports', path);
    final version = (sample['report_version'] as num?)?.toInt() ?? 1;
    final ok = await widget.repo.updateLabSample('${sample['id']}', {
      'report_url': url ?? path,
      'status': 'completed',
      'report_version': version + (sample['report_url'] == null ? 0 : 1),
    });
    if (ok) {
      // The appointment itself is finished once the report is out.
      await widget.repo.updateAppointmentStatus(
          '${sample['appointment_id']}', 'completed');
    }
    _snack(ok
        ? 'Report uploaded. The patient can now download it.'
        : 'Report stored, but status could not be updated.');
    if (ok) _load();
  }

  Future<void> _viewReport(Map<String, dynamic> sample) async {
    var url = '${sample['report_url'] ?? ''}';
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      url = await widget.repo.signedStorageUrl('lab-reports', url) ??
          url;
    }
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Active bookings (not cancelled) drive sample creation.
    final active = widget.bookings
        .where((b) => '${b['status']}' != 'cancelled')
        .toList();
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RSectionHeader(
            title: 'Samples & Reports',
            subtitle:
                'Track each sample and upload the finished report',
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (active.isEmpty && _samples.isEmpty)
            Text('No bookings yet.',
                style: TextStyle(color: scheme.onSurfaceVariant))
          else ...[
            for (final b in active) ...[
              if (_sampleFor('${b['id']}') == null)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.science_outlined, size: 20),
                  title: Text(
                      '${b['patient_name'] ?? 'Patient'} • ${b['appointment_date'] ?? ''}'),
                  subtitle: Text(
                    '${b['collection_type'] == 'home' ? 'Home collection' : 'Walk-in'}'
                    '${'${b['collection_address'] ?? ''}'.isNotEmpty ? ' • ${b['collection_address']}' : ''}',
                  ),
                  trailing: RButton(
                    label: 'Start sample',
                    small: true,
                    variant: RButtonVariant.outline,
                    onPressed: () => _createSample(b),
                  ),
                ),
            ],
            for (final s in _samples)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s['status'] == 'completed'
                      ? Icons.task_alt
                      : Icons.biotech_outlined,
                  size: 20,
                ),
                title: Text('${s['test_name'] ?? 'Test'}'),
                subtitle: Text(
                  '${s['status']}'
                  '${s['collection_type'] == 'home' ? ' • Home' : ' • Walk-in'}'
                  '${'${s['report_url'] ?? ''}'.isNotEmpty ? ' • Report v${s['report_version']}' : ''}',
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    if (s['status'] == 'scheduled')
                      TextButton(
                        onPressed: () => _advance(s, 'collected'),
                        child: const Text('Collected'),
                      ),
                    if (s['status'] == 'collected')
                      TextButton(
                        onPressed: () => _advance(s, 'processing'),
                        child: const Text('Processing'),
                      ),
                    if (s['status'] == 'processing' ||
                        s['status'] == 'collected')
                      TextButton(
                        onPressed: () => _uploadReport(s),
                        child: const Text('Upload report'),
                      ),
                    if ('${s['report_url'] ?? ''}'.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.description_outlined,
                            size: 20),
                        onPressed: () => _viewReport(s),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
