import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
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
                  label: s == 'All' ? 'All' : s,
                  selected: s == _filter,
                  onTap: () => setState(() => _filter = s),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const REmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No appointments',
                  subtitle: 'Bookings will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      16, 4, 16, 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) =>
                      _card(state, list[i]),
                ),
        ),
      ],
    );
  }

  Widget _card(AppState state, Appointment a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 6),
        child: ListTile(
          leading: InitialsAvatar(
              name: a.doctorName, radius: 22),
          title: Text(a.doctorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${a.specialty} • ${a.dateLabel} ${a.timeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
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
      ),
    );
  }
}
