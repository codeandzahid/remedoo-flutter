import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  } catch (_) {
    return iso;
  }
}

/// Who booked and who they booked with, for one admin appointment
/// row. Provider names come from the query's embedded provider rows;
/// 'patient_name' is stamped onto the row by the repository (there
/// is no FK from appointments.patient_id to profiles to embed).
({String patient, String provider}) adminAppointmentNames(
    Map<String, dynamic> a) {
  String embeddedName(String key) {
    final v = a[key];
    return v is Map ? '${v['name'] ?? ''}'.trim() : '';
  }

  var provider = '';
  for (final key in ['doctors', 'hospitals', 'labs', 'pharmacies']) {
    if (provider.isEmpty) provider = embeddedName(key);
  }
  final patient = '${a['patient_name'] ?? ''}'.trim();
  return (
    patient: patient.isEmpty ? 'Patient' : patient,
    provider: provider.isEmpty
        ? '${a['service_type'] ?? 'Appointment'}'
        : provider,
  );
}

/// Everything the admin appointment detail view shows for one row.
/// Names resolve exactly like the list ([adminAppointmentNames]);
/// specialty and fee come from the embedded doctor record — the
/// appointments table has neither column (the patient's receipt
/// derives them the same way, in AppState's row mapper). Contact
/// fields are the 'patient_email' / 'patient_phone' values the
/// repository stamps onto the row from the patient's profile.
({
  String patient,
  String email,
  String phone,
  String provider,
  String specialty,
  String date,
  String time,
  String status,
  String payment,
  double? fee,
  String notes,
  String bookedOn,
}) adminAppointmentDetail(Map<String, dynamic> a) {
  final names = adminAppointmentNames(a);
  final doc = a['doctors'];
  final docMap = doc is Map ? doc : const <String, dynamic>{};
  var time = '${a['appointment_time'] ?? ''}'.trim();
  if (time.length > 5) time = time.substring(0, 5);
  return (
    patient: names.patient,
    email: '${a['patient_email'] ?? ''}'.trim(),
    phone: '${a['patient_phone'] ?? ''}'.trim(),
    provider: names.provider,
    specialty: '${docMap['specialization'] ?? ''}'.trim(),
    date: _fmtDate(a['appointment_date']?.toString()),
    time: time,
    status: '${a['status'] ?? ''}'.trim(),
    payment: AppState.paymentLabelFor(a['payment_method']),
    fee: (docMap['consultation_fee'] as num?)?.toDouble(),
    notes: '${a['notes'] ?? ''}'.trim(),
    bookedOn: _fmtDate(a['created_at']?.toString()),
  );
}

/// Admin appointments: real Supabase appointments, filterable.
class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends State<AdminAppointmentsScreen> {
  String _filter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadAdminAppointments();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    // Canonical stored statuses (the appointments CHECK constraint);
    // 'upcoming' is a patient-side display word and never stored, so
    // filtering on it always came back empty.
    final statuses = ['All', 'pending', 'confirmed', 'cancelled', 'completed'];
    var list = state.adminAppointments.toList();
    if (_filter != 'All') {
      list = list
          .where((a) => '${a['status']}' == _filter)
          .toList();
    }
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            itemCount: statuses.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final s = statuses[i];
              return Center(
                child: RFilterChip(
                  label: s,
                  selected: s == _filter,
                  onTap: () =>
                      setState(() => _filter = s),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: list.isEmpty
                      ? const REmptyState(
                          icon:
                              Icons.calendar_month_outlined,
                          title: 'No appointments',
                          subtitle:
                              'Bookings will appear here.',
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(
                                  16, 4, 16, 16),
                          itemCount: list.length,
                          itemBuilder: (_, i) =>
                              _card(list[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> a) {
    final scheme = Theme.of(context).colorScheme;
    final names = adminAppointmentNames(a);
    final when =
        '${_fmtDate(a['appointment_date']?.toString())} ${a['appointment_time'] ?? ''}'
            .trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6),
        child: ListTile(
          onTap: () => _showDetail(a),
          leading: InitialsAvatar(name: names.patient, radius: 22),
          title: Text(names.patient,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${names.provider} • ${when.isEmpty ? '—' : when}${a['notes'] != null && '${a['notes']}'.isNotEmpty ? ' • ${a['notes']}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(status: '${a['status'] ?? ''}'),
              if ('${a['status'] ?? ''}' == 'pending') ...[
                IconButton(
                  icon: Icon(Icons.check_circle,
                      color: Colors.green.shade700, size: 22),
                  tooltip: 'Approve appointment',
                  onPressed: () => _approve(a),
                ),
                IconButton(
                  icon: Icon(Icons.cancel,
                      color: Theme.of(context).colorScheme.error,
                      size: 22),
                  tooltip: 'Reject appointment',
                  onPressed: () => _reject(a),
                ),
              ],
              if ('${a['status'] ?? ''}' != 'cancelled' &&
                  '${a['status'] ?? ''}' != 'completed' &&
                  '${a['status'] ?? ''}' != 'pending') ...[
                IconButton(
                  icon: Icon(Icons.cancel_outlined,
                      color: Theme.of(context).colorScheme.error,
                      size: 20),
                  tooltip: 'Cancel appointment',
                  onPressed: () => _confirmCancel(a),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Record detail for one booking, in the admin panel's usual
  /// dialog form (orders and users present records the same way).
  /// The dialog re-reads its row from state on every build, so the
  /// status and actions it shows stay current after an action
  /// lands; its buttons run this screen's own approve / reject /
  /// cancel handlers, unchanged.
  void _showDetail(Map<String, dynamic> a) {
    showDialog(
      context: context,
      builder: (_) => _AppointmentDetailDialog(
        initialRow: a,
        onApprove: _approve,
        onReject: _reject,
        onCancel: _confirmCancel,
      ),
    );
  }

  Future<void> _confirmCancel(Map<String, dynamic> a) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel appointment?',
      message:
          'This will mark the appointment as cancelled for the patient.',
      confirmLabel: 'Cancel appointment',
    );
    if (!ok || !mounted) return;
    final done = await AppStateScope.of(context)
        .updateAdminAppointment('${a['id']}', {'status': 'cancelled'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? 'Appointment cancelled.'
              : 'Could not cancel. Try again.')),
    );
  }

  Future<void> _approve(Map<String, dynamic> a) async {
    // Approving an already-decided row is a no-op with a plain
    // message, not a failed write with a scary error.
    final status = '${a['status'] ?? ''}';
    if (status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(status == AppState.approvedDbStatus
                ? 'This appointment is already approved.'
                : 'This appointment is already $status.')),
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Approve appointment?',
      message: 'The patient will be notified that their appointment is confirmed.',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    final state = AppStateScope.of(context);
    // 'confirmed' is the storable approved status (see
    // AppState.approvedDbStatus) — writing the display word
    // 'upcoming' here violated the table's CHECK constraint, so
    // every approval failed and the patient was never notified.
    // No app-side notification is sent on success: the database
    // trigger (notify_appointment_change) inserts the patient's
    // "Appointment Confirmed" notification on this status change,
    // and an admin-side insert (RLS-allowed for admins) would
    // duplicate it.
    final done = await state.updateAdminAppointment(
        '${a['id']}', {'status': AppState.approvedDbStatus});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? 'Appointment approved. Patient notified.'
              : 'Could not approve. Try again.')),
    );
  }

  Future<void> _reject(Map<String, dynamic> a) async {
    final ok = await confirmDialog(
      context,
      title: 'Reject appointment?',
      message: 'The patient will be notified that their request was not approved.',
      confirmLabel: 'Reject',
    );
    if (!ok || !mounted) return;
    final state = AppStateScope.of(context);
    final done = await state
        .updateAdminAppointment('${a['id']}', {'status': 'cancelled'});
    // No app-side notification here either: the same DB trigger
    // notifies the patient of the cancellation (see _approve).
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? 'Appointment rejected. Patient notified.'
              : 'Could not reject. Try again.')),
    );
  }
}

/// Detail view for one admin appointment row. Stateless on purpose:
/// it resolves its row from [AppState.adminAppointments] by id on
/// every build (falling back to the row it was opened with), and
/// AppStateScope is an InheritedNotifier, so when an action updates
/// the row this dialog rebuilds with the new status — and the list
/// behind it reads the same rows, so both stay in step. The actions
/// mirror the list's rules exactly (approve/reject while pending,
/// cancel while neither cancelled nor completed) and are the list's
/// own handlers, passed in by the screen.
class _AppointmentDetailDialog extends StatelessWidget {
  final Map<String, dynamic> initialRow;
  final ValueChanged<Map<String, dynamic>> onApprove;
  final ValueChanged<Map<String, dynamic>> onReject;
  final ValueChanged<Map<String, dynamic>> onCancel;

  const _AppointmentDetailDialog({
    required this.initialRow,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  Widget _field(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final id = '${initialRow['id']}';
    var row = initialRow;
    for (final r in state.adminAppointments) {
      if ('${r['id']}' == id) {
        row = r;
        break;
      }
    }
    final d = adminAppointmentDetail(row);
    final status = d.status;
    return AlertDialog(
      title: const Text('Appointment details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: d.patient, radius: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(d.patient,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              if (d.email.isNotEmpty) _field(context, 'Email', d.email),
              if (d.phone.isNotEmpty) _field(context, 'Phone', d.phone),
              _field(context, 'Provider', d.provider),
              if (d.specialty.isNotEmpty)
                _field(context, 'Specialty', d.specialty),
              _field(context, 'Date', d.date.isEmpty ? '—' : d.date),
              if (d.time.isNotEmpty) _field(context, 'Time', d.time),
              if (d.fee != null)
                _field(context, 'Consultation fee',
                    '₹${d.fee!.toStringAsFixed(0)}'),
              _field(context, 'Payment', d.payment),
              if (d.notes.isNotEmpty)
                _field(context, 'Reason / notes', d.notes),
              if (d.bookedOn.isNotEmpty)
                _field(context, 'Booked on', d.bookedOn),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (status == 'pending') ...[
          RButton(
            label: 'Reject',
            small: true,
            variant: RButtonVariant.danger,
            onPressed: () => onReject(row),
          ),
          RButton(
            label: 'Approve',
            small: true,
            onPressed: () => onApprove(row),
          ),
        ] else if (status != 'cancelled' && status != 'completed')
          RButton(
            label: 'Cancel appointment',
            small: true,
            variant: RButtonVariant.danger,
            onPressed: () => onCancel(row),
          ),
      ],
    );
  }
}
