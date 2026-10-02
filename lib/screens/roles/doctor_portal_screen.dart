import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Doctor portal: appointments, day-wise schedule manager, earnings.
class DoctorPortalScreen extends StatefulWidget {
  const DoctorPortalScreen({super.key});

  @override
  State<DoctorPortalScreen> createState() =>
      _DoctorPortalScreenState();
}

class _DoctorPortalScreenState extends State<DoctorPortalScreen> {
  int _tab = 0;
  int _day = 0;
  final Doctor _me = doctors[0];

  static const _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Portal')),
      body: [
        _appointmentsTab(),
        _scheduleTab(),
        _earningsTab(),
      ][_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Appointments'),
          NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule),
              label: 'Schedule'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments),
              label: 'Earnings'),
        ],
      ),
    );
  }

  Widget _appointmentsTab() {
    final state = AppStateScope.of(context);
    final list = state.appointments
        .where((a) => a.kind == 'doctor')
        .toList();
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month,
        title: 'No appointments',
        subtitle: 'Patient bookings will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final a = list[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading:
                InitialsAvatar(name: a.doctorName, radius: 22),
            title: Text(a.doctorName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${a.dateLabel} • ${a.timeLabel}'),
            trailing: StatusChip(status: a.status),
            onTap: () => _detail(state, a),
          ),
        );
      },
    );
  }

  void _detail(AppState state, Appointment a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.doctorName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            InfoRow(
                icon: Icons.calendar_month,
                label: 'Date',
                value: a.dateLabel),
            InfoRow(
                icon: Icons.schedule,
                label: 'Time',
                value: a.timeLabel),
            if (a.notes.isNotEmpty)
              InfoRow(
                  icon: Icons.note_outlined,
                  label: 'Notes',
                  value: a.notes),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      state.cancelAppointment(a.id);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            RemedooTheme.emergency),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      state.cancelAppointment(a.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Marked complete! (demo)')),
                      );
                    },
                    child: const Text('Complete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleTab() {
    final state = AppStateScope.of(context);
    final slots = state.doctorSlots(_me.id, _day);
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _days.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == _day;
              return Center(
                child: ChoiceChip(
                  label: Text(_days[i]),
                  selected: sel,
                  onSelected: (_) =>
                      setState(() => _day = i),
                  selectedColor: RemedooTheme.primary,
                  labelStyle: TextStyle(
                      color: sel
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurface),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots
                    .map((s) => Chip(
                          label: Text(s),
                          deleteIcon:
                              const Icon(Icons.close, size: 16),
                          onDeleted: () => state.removeDoctorSlot(
                              _me.id, _day, s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () =>
                    _addSlotDialog(state),
                icon: const Icon(Icons.add),
                label: const Text('Add slot'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addSlotDialog(AppState state) {
    final ctrl = TextEditingController(text: '11:00');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add slot • ${_days[_day]}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Time (HH:MM)', hintText: '11:00'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              state.addDoctorSlot(
                  _me.id, _day, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _earningsTab() {
    final state = AppStateScope.of(context);
    final mine =
        state.appointments.where((a) => a.kind == 'doctor');
    final total =
        mine.fold<double>(0, (s, a) => s + a.fee);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Total earnings',
                    style: TextStyle(color: Colors.grey)),
                Text(inr(total),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: RemedooTheme.ratingGreen)),
                const SizedBox(height: 8),
                Text('${mine.length} appointments'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
