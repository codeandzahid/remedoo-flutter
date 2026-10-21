import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import 'widgets.dart';

/// Doctor prescription sheet (form-pages audit M3): the
/// prescriptions + prescription_items tables and doctor-insert
/// RLS existed, but no doctor-panel form ever wrote to them.
///
/// Opened from a completed appointment: shows the prescription
/// already written for the appointment when one exists, otherwise
/// the creation form (diagnosis, notes, and any number of medicine
/// rows — name / generic / dosage / frequency / duration /
/// instructions, the prescription_items columns).
class PrescriptionSheet extends StatefulWidget {
  final String appointmentId;
  final String patientName;
  final SupabaseRepository? repo;

  const PrescriptionSheet({
    super.key,
    required this.appointmentId,
    required this.patientName,
    this.repo,
  });

  static Future<void> show(
    BuildContext context, {
    required String appointmentId,
    required String patientName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PrescriptionSheet(
        appointmentId: appointmentId,
        patientName: patientName,
      ),
    );
  }

  @override
  State<PrescriptionSheet> createState() => _PrescriptionSheetState();
}

class _ItemRow {
  final name = TextEditingController();
  final generic = TextEditingController();
  final dosage = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final instructions = TextEditingController();

  void dispose() {
    name.dispose();
    generic.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    instructions.dispose();
  }

  bool get complete =>
      name.text.trim().isNotEmpty &&
      dosage.text.trim().isNotEmpty &&
      frequency.text.trim().isNotEmpty &&
      duration.text.trim().isNotEmpty;

  Map<String, String> toMap() => {
        'medicine_name': name.text.trim(),
        'generic_name': generic.text.trim(),
        'dosage': dosage.text.trim(),
        'frequency': frequency.text.trim(),
        'duration': duration.text.trim(),
        'instructions': instructions.text.trim(),
      };
}

class _PrescriptionSheetState extends State<PrescriptionSheet> {
  SupabaseRepository get _repo =>
      widget.repo ?? SupabaseRepository.instance;

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _existing;
  bool _writing = false;

  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final List<_ItemRow> _items = [_ItemRow()];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _diagnosis.dispose();
    _notes.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final p =
        await _repo.fetchPrescriptionForAppointment(widget.appointmentId);
    if (!mounted) return;
    setState(() {
      _existing = p;
      _writing = p == null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final rows = _items.where((i) => i.name.text.trim().isNotEmpty).toList();
    if (rows.isEmpty || rows.any((i) => !i.complete)) {
      setState(() => _error =
          'Add at least one medicine with name, dosage, frequency and duration.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = await _repo.createPrescription(
      appointmentId: widget.appointmentId,
      diagnosis: _diagnosis.text.trim(),
      notes: _notes.text.trim(),
      items: rows.map((i) => i.toMap()).toList(),
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _saving = false;
        _error = 'Could not save. Try again.';
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prescription saved.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prescription — ${widget.patientName}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_writing && _existing != null)
              _existingView(scheme)
            else
              _form(scheme),
          ],
        ),
      ),
    );
  }

  Widget _existingView(ColorScheme scheme) {
    final p = _existing!;
    final items = (p['items'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ('${p['diagnosis'] ?? ''}'.isNotEmpty)
          Text('Diagnosis: ${p['diagnosis']}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final raw in items) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final it = Map<String, dynamic>.from(raw as Map);
            return Text(
              '• ${it['medicine_name']} — ${it['dosage']}, '
              '${it['frequency']}, ${it['duration']}'
              '${'${it['instructions'] ?? ''}'.isNotEmpty ? ' (${it['instructions']})' : ''}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            );
          }),
        ],
        if ('${p['notes'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Notes: ${p['notes']}',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 16),
        RButton(
          label: 'Write a new prescription',
          small: true,
          variant: RButtonVariant.outline,
          onPressed: () => setState(() => _writing = true),
        ),
      ],
    );
  }

  Widget _form(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RTextField(controller: _diagnosis, label: 'Diagnosis'),
        const SizedBox(height: 10),
        for (var i = 0; i < _items.length; i++) ...[
          Row(
            children: [
              Text('Medicine ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_items.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => setState(() {
                    _items.removeAt(i).dispose();
                  }),
                ),
            ],
          ),
          RTextField(
              controller: _items[i].name, label: 'Medicine name *'),
          const SizedBox(height: 8),
          RTextField(
              controller: _items[i].generic,
              label: 'Generic name (optional)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RTextField(
                    controller: _items[i].dosage, label: 'Dosage *'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RTextField(
                    controller: _items[i].frequency,
                    label: 'Frequency *'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RTextField(
                    controller: _items[i].duration, label: 'Duration *'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RTextField(
              controller: _items[i].instructions,
              label: 'Instructions (optional)'),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _items.add(_ItemRow())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add medicine'),
          ),
        ),
        RTextField(
            controller: _notes, label: 'Notes for the patient (optional)'),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: TextStyle(color: scheme.error, fontSize: 13)),
        ],
        const SizedBox(height: 14),
        RButton(
          label: _saving ? 'Saving…' : 'Save prescription',
          fullWidth: true,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
