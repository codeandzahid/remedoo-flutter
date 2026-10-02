import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models.dart';
import '../../responsive/animations.dart';
import '../../responsive/responsive.dart';
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
      return const REmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No appointments',
        subtitle: 'Patient bookings will appear here.',
      );
    }
    return MaxWidthBox(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final a = list[i];
          return StaggerItem(
            index: i % 6,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                onTap: () => _detail(state, a),
                child: ListTile(
                  leading: InitialsAvatar(
                      name: a.doctorName, radius: 22),
                  title: Text(a.doctorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  subtitle: Text('${a.dateLabel} • ${a.timeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: StatusChip(status: a.status),
                ),
              ),
            ),
          );
        },
      ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
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
                  child: RButton(
                    label: 'Cancel',
                    small: true,
                    variant: RButtonVariant.danger,
                    onPressed: () {
                      state.cancelAppointment(a.id);
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RButton(
                    label: 'Complete',
                    small: true,
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _scheduleTab() {
    final state = AppStateScope.of(context);
    final slots = state.doctorSlots(_me.id, _day);
    return MaxWidthBox(
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _days.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) {
                return Center(
                  child: RFilterChip(
                    label: _days[i],
                    selected: i == _day,
                    onTap: () => setState(() => _day = i),
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
                            deleteIcon: const Icon(Icons.close,
                                size: 16),
                            onDeleted: () =>
                                state.removeDoctorSlot(
                                    _me.id, _day, s),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                RButton(
                  label: 'Add slot',
                  icon: Icons.add,
                  variant: RButtonVariant.outline,
                  onPressed: () => _addSlotDialog(state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addSlotDialog(AppState state) {
    final ctrl = TextEditingController(text: '11:00');
    showResponsiveDialog(
      context,
      (_) => AlertDialog(
        title: Text('Add slot • ${_days[_day]}',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        content: RTextField(
          controller: ctrl,
          label: 'Time (HH:MM)',
          hint: '11:00',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Add',
            small: true,
            onPressed: () {
              state.addDoctorSlot(
                  _me.id, _day, ctrl.text.trim());
              Navigator.pop(context);
            },
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
    final scheme = Theme.of(context).colorScheme;
    return MaxWidthBox(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: RemedooTheme.success
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.payments,
                      color: RemedooTheme.success, size: 28),
                ),
                const SizedBox(height: 12),
                Text('Total earnings',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(inr(total),
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: RemedooTheme.success)),
                const SizedBox(height: 8),
                Text('${mine.length} appointments',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
