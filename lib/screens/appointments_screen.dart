import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'appointment_detail_screen.dart';
import 'booking_screen.dart';
import 'doctors_screen.dart';
import '../app_navigator.dart';

/// Upcoming / Past appointments with reschedule + cancel.
/// Mirrors the React Appointments page: orange gradient header with
/// Upcoming/Past pill tabs, status-pill cards, tap to detail.
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
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    final upcoming =
        state.appointments.where((a) => a.status == 'upcoming').toList();
    final past =
        state.appointments.where((a) => a.status != 'upcoming').toList();
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => goBack(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // Keeps the historic 'Appointments (N)' title text
                        // (widget tests assert it); count badge lives in the
                        // tab pills like the React page.
                        'Appointments (${state.appointments.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _tabPill(
                            'Upcoming (${upcoming.length})', 0)),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            _tabPill('Past (${past.length})', 1)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _list(upcoming, state, isUpcoming: true),
                  _list(past, state, isUpcoming: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pill tab: active = white bg + orange text, inactive = translucent white.
  Widget _tabPill(String label, int index) {
    final selected = _tabs.index == index;
    return Material(
      color: selected
          ? Colors.white
          : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _tabs.animateTo(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? RemedooTheme.primary : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
            ? () => pushPage(context, const DoctorsScreen())
            : null,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => StaggerItem(
        index: i % 6,
        child: _card(list[i], state, isUpcoming),
      ),
    );
  }

  Widget _card(Appointment a, AppState state, bool isUpcoming) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RCard(
        padding: const EdgeInsets.all(12),
        onTap: () =>
            pushPage(context, AppointmentDetailScreen(appointment: a)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: a.doctorName, radius: 22),
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
                          style: TextStyle(
                              color: scheme.primary, fontSize: 13)),
                      Text('${a.dateLabel} • ${a.timeLabel}',
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant)),
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
                    child: RButton(
                      label: 'Reschedule',
                      variant: RButtonVariant.outline,
                      small: true,
                      onPressed: () => pushPage(
                        context,
                        BookingScreen(
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
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RButton(
                      label: 'Cancel',
                      variant: RButtonVariant.danger,
                      small: true,
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
                    ),
                  ),
                ],
              ),
            ] else if (state.canReview(a.id)) ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Write a review',
                icon: Icons.star_outline,
                variant: RButtonVariant.outline,
                small: true,
                onPressed: () =>
                    ReviewDialog.show(context, a.id, a.doctorName),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
