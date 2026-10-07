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
    final statuses = ['All', 'pending', 'upcoming', 'cancelled', 'completed'];
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
    final when =
        '${_fmtDate(a['appointment_date']?.toString())} ${a['appointment_time'] ?? ''}'
            .trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6),
        child: ListTile(
          leading: InitialsAvatar(
              name: '${a['service_type'] ?? 'Visit'}',
              radius: 22),
          title: Text('${a['service_type'] ?? 'Appointment'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${when.isEmpty ? '—' : when}${a['notes'] != null && '${a['notes']}'.isNotEmpty ? ' • ${a['notes']}' : ''}',
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
    final ok = await confirmDialog(
      context,
      title: 'Approve appointment?',
      message: 'The patient will be notified that their appointment is confirmed.',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    final state = AppStateScope.of(context);
    final done = await state
        .updateAdminAppointment('${a['id']}', {'status': 'upcoming'});
    if (done) {
      // Notify patient
      final patientId = '${a['patient_id'] ?? a['user_id'] ?? ''}';
      if (patientId.isNotEmpty) {
        await state.supabaseRepository.sendNotificationToUser(
              userId: patientId,
              title: 'Appointment Confirmed',
              message:
                  'Your appointment was successfully booked. You can now view and print your appointment letter.',
              type: 'appointment',
            );
      }
    }
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
    if (done) {
      final patientId = '${a['patient_id'] ?? a['user_id'] ?? ''}';
      if (patientId.isNotEmpty) {
        await state.supabaseRepository.sendNotificationToUser(
              userId: patientId,
              title: 'Appointment Not Approved',
              message:
                  'Your appointment request was not approved. Please try another slot.',
              type: 'appointment',
            );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? 'Appointment rejected. Patient notified.'
              : 'Could not reject. Try again.')),
    );
  }
}
