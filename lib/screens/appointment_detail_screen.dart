import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

/// Appointment detail with cancel + reschedule.
class AppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final a = appointment;
    final isUpcoming = a.status == 'upcoming';
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  InitialsAvatar(name: a.doctorName, radius: 40),
                  const SizedBox(height: 10),
                  Text(a.doctorName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(a.specialty,
                      style: const TextStyle(
                          color: RemedooTheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  StatusChip(status: a.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(
                      icon: Icons.calendar_month,
                      label: 'Date',
                      value: a.dateLabel),
                  InfoRow(
                      icon: Icons.schedule,
                      label: 'Time',
                      value: a.timeLabel),
                  InfoRow(
                      icon: Icons.location_on,
                      label: 'Place',
                      value: a.place),
                  InfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Payment',
                      value: a.payment),
                  InfoRow(
                      icon: Icons.currency_rupee,
                      label: 'Fee',
                      value: inr(a.fee)),
                  if (a.notes.isNotEmpty)
                    InfoRow(
                        icon: Icons.note_outlined,
                        label: 'Notes',
                        value: a.notes),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (isUpcoming) ...[
            FilledButton(
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
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: RemedooTheme.emergency),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Cancel appointment?',
                  message: 'This slot will be released.',
                  confirmLabel: 'Yes, cancel',
                );
                if (ok && context.mounted) {
                  state.cancelAppointment(a.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Appointment cancelled')),
                  );
                }
              },
              child: const Text('Cancel Appointment'),
            ),
          ] else if (state.canReview(a.id)) ...[
            FilledButton.icon(
              onPressed: () =>
                  ReviewDialog.show(context, a.id, a.doctorName),
              icon: const Icon(Icons.star_outline),
              label: const Text('Write a review'),
            ),
          ],
        ],
      ),
    );
  }
}
