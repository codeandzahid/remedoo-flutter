import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';

/// Printable appointment letter with all booking details.
/// Shown after doctor confirms the appointment.
class AppointmentReceiptScreen extends StatelessWidget {
  final Appointment appointment;

  const AppointmentReceiptScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final a = appointment;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Letter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print / Save PDF',
            onPressed: () {
              // Use browser print dialog on web, system print on mobile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Use your browser\'s Print > Save as PDF to save this letter'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medical_services,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remedoo',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                        Text('Appointment Confirmation Letter',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: a.status == 'upcoming'
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    a.status == 'upcoming'
                        ? 'CONFIRMED'
                        : 'PENDING APPROVAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: a.status == 'upcoming'
                          ? Colors.green.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _row('Booking ID', a.id),
                _row('Patient', state.displayName),
                if (a.bookingForName != null)
                  _row('Booking For', a.bookingForName!),
                _row('Doctor', a.doctorName),
                _row('Specialty', a.specialty),
                _row('Clinic/Hospital', a.place),
                _row('Date',
                    '${a.date.day}/${a.date.month}/${a.date.year}'),
                _row('Time', a.timeLabel),
                _row('Consultation Fee', '₹${a.fee.toStringAsFixed(0)}'),
                _row('Payment Method', a.payment),
                if (a.notes.isNotEmpty)
                  _row('Notes', a.notes),
                if (a.prescriptionName != null)
                  _row('Prescription', a.prescriptionName!),
                const Divider(height: 32),
                const Text(
                  'Instructions:',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Please arrive 15 minutes before your appointment time\n'
                  '• Carry this letter (printed or on your phone)\n'
                  '• Bring previous medical reports if any\n'
                  '• For queries, contact Remedoo support',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
