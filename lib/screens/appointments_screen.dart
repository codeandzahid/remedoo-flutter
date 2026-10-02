import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'appointment_detail_screen.dart';
import 'booking_screen.dart';
import 'doctors_screen.dart';

/// Upcoming / Past appointments with reschedule + cancel.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final upcoming = state.appointments
        .where((a) => a.status == 'upcoming')
        .toList();
    final past =
        state.appointments.where((a) => a.status != 'upcoming').toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Appointments (${state.appointments.length})'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: RemedooTheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: RemedooTheme.primary,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _list(upcoming, state, isUpcoming: true),
          _list(past, state, isUpcoming: false),
        ],
      ),
    );
  }

  Widget _list(
      List<Appointment> list, AppState state, {required bool isUpcoming}) {
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_month,
        title: isUpcoming
            ? 'No upcoming appointments'
            : 'No past appointments',
        subtitle: isUpcoming
            ? 'Book a visit and it will show up here.'
            : 'Your completed visits will appear here.',
        actionLabel: isUpcoming ? 'Book Now' : null,
        onAction: isUpcoming
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DoctorsScreen()),
                )
            : null,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(list[i], state, isUpcoming),
    );
  }

  Widget _card(Appointment a, AppState state, bool isUpcoming) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AppointmentDetailScreen(appointment: a)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: a.doctorName, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.doctorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text(a.specialty,
                            style: const TextStyle(
                                color: RemedooTheme.primary,
                                fontSize: 13)),
                        Text('${a.dateLabel} • ${a.timeLabel}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  StatusChip(status: a.status),
                ],
              ),
              if (isUpcoming) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingScreen(
                              kind: a.kind,
                              refId: a.refId,
                              title: a.doctorName,
                              subtitle: a.specialty,
                              place: a.place,
                              fee: a.fee,
                              prefill: a,
                            ),
                          ),
                        ),
                        child: const Text('Reschedule'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: RemedooTheme.emergency),
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            title: 'Cancel appointment?',
                            message:
                                'This slot will be released. This cannot be undone.',
                            confirmLabel: 'Yes, cancel',
                          );
                          if (ok) {
                            state.cancelAppointment(a.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Appointment cancelled')),
                              );
                            }
                          }
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ] else if (state.canReview(a.id)) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ReviewDialog.show(
                      context, a.id, a.doctorName),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Write a review'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
