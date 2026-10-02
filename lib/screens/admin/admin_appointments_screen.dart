import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin appointments: filterable list with status-change actions.
class AdminAppointmentsScreen extends StatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  State<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends State<AdminAppointmentsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final statuses = ['All', 'upcoming', 'cancelled'];
    var list = state.appointments.toList();
    if (_filter != 'All') {
      list = list.where((a) => a.status == _filter).toList();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: statuses.map((s) {
              final sel = s == _filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s),
                  selected: sel,
                  onSelected: (_) =>
                      setState(() => _filter = s),
                  selectedColor: RemedooTheme.primary,
                  labelStyle: TextStyle(
                      color: sel ? Colors.white : null),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.calendar_month,
                  title: 'No appointments',
                  subtitle: 'Bookings will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _card(state, list[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(AppState state, Appointment a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(a.doctorName,
            style:
                const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${a.specialty} • ${a.dateLabel} ${a.timeLabel}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusChip(status: a.status),
            if (a.status == 'upcoming')
              IconButton(
                icon: const Icon(Icons.cancel_outlined,
                    color: Colors.red),
                tooltip: 'Cancel',
                onPressed: () =>
                    state.cancelAppointment(a.id),
              ),
          ],
        ),
      ),
    );
  }
}
