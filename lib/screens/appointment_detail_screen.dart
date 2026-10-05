import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';
import '../app_navigator.dart';

/// Appointment detail with cancel + reschedule.
/// Mirrors the React AppointmentDetail page: orange gradient header with
/// appointment id, provider card with status pill, schedule card, payment
/// card, notes, and pill-styled cancel/reschedule actions.
/// Adaptive: two-column (details + actions side panel) on tablets and larger.
class AppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  String get _shortId {
    final id = appointment.id;
    return (id.length >= 8 ? id.substring(0, 8) : id).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final a = appointment;
    final isUpcoming = a.status == 'upcoming';
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => goBack(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appointment Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '#$_shortId',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DetailSplit(
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _providerCard(context, a),
                    const SizedBox(height: 12),
                    _scheduleCard(context, a),
                    const SizedBox(height: 12),
                    _paymentCard(context, a),
                    if (a.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _notesCard(context, a),
                    ],
                  ],
                ),
                side: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quickSummaryCard(context, a),
                    const SizedBox(height: 12),
                    if (isUpcoming) ...[
                      RButton(
                        label: 'Reschedule',
                        icon: Icons.calendar_month,
                        fullWidth: true,
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
                      const SizedBox(height: 10),
                      RButton(
                        label: 'Cancel Appointment',
                        variant: RButtonVariant.danger,
                        fullWidth: true,
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
                                  content:
                                      Text('Appointment cancelled')),
                            );
                          }
                        },
                      ),
                    ] else if (state.canReview(a.id)) ...[
                      RButton(
                        label: 'Write a review',
                        icon: Icons.star_outline,
                        fullWidth: true,
                        onPressed: () => ReviewDialog.show(
                            context, a.id, a.doctorName),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerCard(BuildContext context, Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person, size: 26, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        a.doctorName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(status: a.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  a.kind[0].toUpperCase() + a.kind.substring(1),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (a.specialty.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    a.specialty,
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        a.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(BuildContext context, Appointment a) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _scheduleTile(
                      context, Icons.calendar_month, 'Date', a.dateLabel)),
              const SizedBox(width: 12),
              Expanded(
                  child: _scheduleTile(
                      context, Icons.schedule, 'Time', a.timeLabel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleTile(
      BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentCard(BuildContext context, Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_rupee,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Payment',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          _kvRow(context, 'Method', a.payment),
          _kvRow(context, 'Fee', inr(a.fee)),
        ],
      ),
    );
  }

  Widget _kvRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesCard(BuildContext context, Appointment a) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              a.notes,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickSummaryCard(BuildContext context, Appointment a) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Summary',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          InfoRow(
              icon: Icons.calendar_month,
              label: 'Date',
              value: a.dateLabel),
          InfoRow(
              icon: Icons.schedule, label: 'Time', value: a.timeLabel),
          InfoRow(
              icon: Icons.payments_outlined,
              label: 'Payment',
              value: a.payment),
        ],
      ),
    );
  }
}
