import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/existing_user_lookup.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: RButton(
            label: 'Book for patient',
            icon: Icons.calendar_month_outlined,
            fullWidth: true,
            onPressed: _bookForPatient,
          ),
        ),
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
                      ? (state.listLoadFailed('appointments')
                          ? REmptyState(
                              icon: Icons.cloud_off_outlined,
                              title: 'Could not load appointments',
                              subtitle:
                                  'The list failed to load — it is not necessarily empty.',
                              actionLabel: 'Retry',
                              onAction: _load,
                            )
                          : const REmptyState(
                              icon:
                                  Icons.calendar_month_outlined,
                              title: 'No appointments',
                              subtitle:
                                  'Bookings will appear here.',
                            ))
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
        onEdit: _editAppointment,
      ),
    );
  }

  /// Book-for-patient (owner order, 2026-11-11): opens the booking
  /// form; on success the admin list reloads and the booked
  /// patient's name is reported back.
  Future<void> _bookForPatient() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _BookForPatientDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appointment booked for $name.')),
    );
  }


  /// Appointment editor (audit Admin gap 10: appointments were
  /// action-only — no way to correct a date/time, set a token,
  /// department, video link or payment status).
  Future<void> _editAppointment(Map<String, dynamic> a) async {
    final date = TextEditingController(
        text: '${a['appointment_date'] ?? ''}'.split('T').first);
    final time = TextEditingController(
        text: '${a['appointment_time'] ?? ''}');
    final token = TextEditingController(
        text: '${a['token_number'] ?? ''}');
    final department =
        TextEditingController(text: '${a['department'] ?? ''}');
    final meetingLink = TextEditingController(
        text: '${a['video_meeting_link'] ?? ''}');
    final notes =
        TextEditingController(text: '${a['notes'] ?? ''}');
    var video = a['is_video_consultation'] == true;
    var payStatus = '${a['payment_status'] ?? 'pending'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edit appointment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RKitField(controller: date, label: 'Date (YYYY-MM-DD)'),
                RKitField(controller: time, label: 'Time (HH:MM)'),
                RKitField(controller: token, label: 'Token number', keyboardType: TextInputType.number),
                RKitField(controller: department, label: 'Department'),
                RFormSwitchTile(
                  title: 'Video consultation',
                  value: video,
                  onChanged: (v) => setD(() => video = v),
                ),
                RKitField(controller: meetingLink, label: 'Video meeting link'),
                RKitDropdown<String>(
                  label: 'Payment status',
                  // Full-check fix 2026-10-22: 'refunded' is
                  // refund vocabulary (appointments.refund_status,
                  // written by the refund flow) and 'failed' has
                  // no consumer — every payment writer uses only
                  // pending/paid for payment_status. A legacy row
                  // carrying 'refunded' here displays as pending
                  // and is repaired on save.
                  value: const ['pending', 'paid'].contains(payStatus)
                      ? payStatus
                      : 'pending',
                  items: const [
                    DropdownMenuItem(
                        value: 'pending', child: Text('pending')),
                    DropdownMenuItem(value: 'paid', child: Text('paid')),
                  ],
                  onChanged: (v) =>
                      setD(() => payStatus = v ?? 'pending'),
                ),
                RKitField(controller: notes, label: 'Notes', maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    if (date.text.trim().isNotEmpty &&
        DateTime.tryParse(date.text.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Date must be YYYY-MM-DD.')));
      return;
    }
    // Full-check fix 2026-10-22: cleared date/time were sent as
    // '' to DATE/TIME columns (DB rejects the whole update), the
    // time was never validated, and an empty/garbage token
    // silently wrote NULL over an existing token_number while
    // reporting success. Blank now means "leave unchanged", and
    // garbage is a validation error.
    final timeText = time.text.trim();
    if (timeText.isNotEmpty &&
        !RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(timeText)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Time must be HH:MM.')));
      return;
    }
    final tokenText = token.text.trim();
    int? tokenValue;
    if (tokenText.isNotEmpty) {
      tokenValue = int.tryParse(tokenText);
      if (tokenValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Token number must be a number.')));
        return;
      }
    }
    final done = await AppStateScope.of(context)
        .updateAdminAppointment('${a['id']}', {
      if (date.text.trim().isNotEmpty)
        'appointment_date': date.text.trim(),
      if (timeText.isNotEmpty) 'appointment_time': timeText,
      if (tokenValue != null) 'token_number': tokenValue,
      'department': department.text.trim().isEmpty
          ? null
          : department.text.trim(),
      'is_video_consultation': video,
      'video_meeting_link': meetingLink.text.trim().isEmpty
          ? null
          : meetingLink.text.trim(),
      'payment_status': payStatus,
      'notes': notes.text.trim(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? 'Appointment updated.'
              : 'Could not update. Try again.')),
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
  final ValueChanged<Map<String, dynamic>> onEdit;

  const _AppointmentDetailDialog({
    required this.initialRow,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onEdit,
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
              if (row['token_number'] != null)
                _field(context, 'Token', '${row['token_number']}'),
              if ('${row['department'] ?? ''}'.isNotEmpty)
                _field(context, 'Department', '${row['department']}'),
              if (row['is_video_consultation'] == true)
                _field(context, 'Video consult', 'Yes'),
              if ('${row['video_meeting_link'] ?? ''}'.isNotEmpty)
                _field(context, 'Meeting link',
                    '${row['video_meeting_link']}'),
              if ('${row['payment_status'] ?? ''}'.isNotEmpty)
                _field(context, 'Payment status',
                    '${row['payment_status']}'),
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
        TextButton(
          onPressed: () => onEdit(row),
          child: const Text('Edit'),
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

/// Book-for-patient form (owner order, 2026-11-11).
///
/// The patient must already have a Remedoo account: the admin types
/// their phone or email, the autofill lookup offers their saved
/// details, and Fill pins the booking to that account. Without a
/// found patient the booking cannot be made — appointments.
/// patient_id must be a real user id. Doctor, date and time slot
/// follow the patient booking flow (same working-hours slots and
/// blocked-slot filtering via [AppState.doctorSlotsFor]). The
/// booking starts 'pending', like a patient-made one.
class _BookForPatientDialog extends StatefulWidget {
  const _BookForPatientDialog();

  @override
  State<_BookForPatientDialog> createState() =>
      _BookForPatientDialogState();
}

class _BookForPatientDialogState extends State<_BookForPatientDialog> {
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  FormUserRecord? _patient;
  String? _doctorId;
  String _doctorName = '';
  DateTime _date = DateTime.now();
  String? _slot;
  String _payment = 'At Clinic';
  bool _saving = false;
  late final List<DateTime> _days;

  static const _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _days = List.generate(7, (i) => _date.add(Duration(days: i)));
  }

  @override
  void dispose() {
    _contact.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _slot = null;
    });
  }

  Future<void> _save() async {
    final state = AppStateScope.of(context);
    final patient = _patient;
    final doctorId = _doctorId;
    final slot = _slot;
    final date = _date;
    final error = validateAdminBookingForPatient(
      patientId: patient?.userId ?? '',
      doctorId: doctorId ?? '',
      date: date,
      timeLabel: slot ?? '',
    );
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    var specialty = '';
    for (final d in state.activeDoctors) {
      if (d.id == doctorId) specialty = d.specialty;
    }
    setState(() => _saving = true);
    final id = await state.bookAppointmentForPatient(
      patientId: patient!.userId,
      doctorId: doctorId!,
      doctorName: _doctorName,
      date: date,
      timeLabel: slot!,
      payment: _payment,
      notes: _notes.text,
      department: specialty.isEmpty ? null : specialty,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not book. Try again.')),
      );
      return;
    }
    Navigator.pop(
        context,
        patient.fullName.isEmpty ? 'the patient' : patient.fullName);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final doctors = state.activeDoctors;
    final slots = _doctorId == null
        ? const <String>[]
        : state.doctorSlotsFor(_doctorId!, _doctorName, _date);
    return AlertDialog(
      title: const Text('Book for patient',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExistingUserLookup(
                trigger: _contact,
                onFill: (record) {
                  setState(() => _patient = record);
                },
                child: RKitField(
                  controller: _contact,
                  label: 'Patient phone or email',
                  hint: '9876543210 or name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_patient != null) {
                      setState(() => _patient = null);
                    }
                  },
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'The patient needs a Remedoo account. If they have '
                'one, their saved details appear — tap Fill.',
                style: TextStyle(fontSize: 12),
              ),
              if (_patient != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(
                          name: _patient!.fullName, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patient!.fullName.isEmpty
                                  ? 'Patient'
                                  : _patient!.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            if (_patient!.email.isNotEmpty)
                              Text(_patient!.email,
                                  style: const TextStyle(
                                      fontSize: 12)),
                            if (_patient!.phone.isNotEmpty)
                              Text(_patient!.phone,
                                  style: const TextStyle(
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              RKitDropdown<String>(
                label: 'Doctor',
                value: _doctorId,
                hint: doctors.isEmpty
                    ? 'No doctors loaded'
                    : 'Choose a doctor',
                items: [
                  for (final d in doctors)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.name} — ${d.specialty} • ₹${d.fee.toStringAsFixed(0)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  var name = '';
                  for (final d in doctors) {
                    if (d.id == v) name = d.name;
                  }
                  setState(() {
                    _doctorId = v;
                    _doctorName = name;
                    _slot = null;
                  });
                  state.loadBlockedSlots(v);
                },
              ),
              const SizedBox(height: 14),
              const Text('Date',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _days.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == _days.length) {
                      return InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor),
                          ),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_month_outlined,
                                  size: 20,
                                  color: scheme.primary),
                              const SizedBox(height: 2),
                              const Text('More',
                                  style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    }
                    final d = _days[i];
                    final sel = _sameDay(d, _date);
                    return InkWell(
                      onTap: () => setState(() {
                        _date = d;
                        _slot = null;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 58,
                        decoration: BoxDecoration(
                          color: sel
                              ? scheme.primary
                              : scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel
                                  ? scheme.primary
                                  : Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(_weekdays[d.weekday - 1],
                                style: TextStyle(
                                    fontSize: 11,
                                    color: sel
                                        ? Colors.white
                                        : scheme.onSurfaceVariant)),
                            Text('${d.day}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? Colors.white
                                        : scheme.onSurface)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Date: ${_date.day}/${_date.month}/${_date.year}',
                style: const TextStyle(fontSize: 12),
              ),
              if (_doctorId != null) ...[
                const SizedBox(height: 14),
                const Text('Time slot',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (slots.isEmpty)
                  const Text(
                    'No slots on this day for this doctor.',
                    style: TextStyle(fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in slots)
                        RFilterChip(
                          label: s,
                          selected: s == _slot,
                          onTap: () =>
                              setState(() => _slot = s),
                        ),
                    ],
                  ),
              ],
              const SizedBox(height: 14),
              RKitDropdown<String>(
                label: 'Payment',
                value: _payment,
                items: const [
                  DropdownMenuItem(
                      value: 'At Clinic',
                      child: Text('At Clinic')),
                  DropdownMenuItem(
                      value: 'Pay Online',
                      child: Text('Pay Online')),
                ],
                onChanged: (v) =>
                    setState(() => _payment = v ?? 'At Clinic'),
              ),
              const SizedBox(height: 14),
              RKitField(
                controller: _notes,
                label: 'Notes (optional)',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        RButton(
          label: _saving ? 'Booking…' : 'Book appointment',
          small: true,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
