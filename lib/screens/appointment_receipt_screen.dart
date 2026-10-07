import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models.dart';
import '../state/app_state.dart';

/// Printable appointment letter with all booking details.
/// Shown after doctor confirms the appointment.
class AppointmentReceiptScreen extends StatelessWidget {
  final Appointment appointment;

  const AppointmentReceiptScreen({super.key, required this.appointment});

  Future<void> _printReceipt(BuildContext context) async {
    final state = AppStateScope.of(context);
    final a = appointment;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 50,
                      height: 50,
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.teal,
                        borderRadius: pw.BorderRadius.all(
                            pw.Radius.circular(10)),
                      ),
                      child: pw.Center(
                        child: pw.Text('R',
                            style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white)),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Remedoo',
                            style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight:
                                    pw.FontWeight.bold)),
                        pw.Text('Appointment Confirmation Letter',
                            style: const pw.TextStyle(
                                fontSize: 14,
                                color: PdfColors.grey700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 16),
                _pdfRow('Booking ID', a.id),
                _pdfRow('Patient', state.displayName),
                if (a.bookingForName != null)
                  _pdfRow('Booking For', a.bookingForName!),
                _pdfRow('Doctor', a.doctorName),
                _pdfRow('Specialty', a.specialty),
                _pdfRow('Clinic/Hospital', a.place),
                _pdfRow('Date',
                    '${a.date.day}/${a.date.month}/${a.date.year}'),
                _pdfRow('Time', a.timeLabel),
                _pdfRow('Consultation Fee',
                    'Rs ${a.fee.toStringAsFixed(0)}'),
                _pdfRow('Payment Method', a.payment),
                _pdfRow(
                    'Status',
                    a.status == 'upcoming'
                        ? 'CONFIRMED'
                        : 'PENDING APPROVAL'),
                if (a.notes.isNotEmpty)
                  _pdfRow('Notes', a.notes),
                pw.SizedBox(height: 24),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('Instructions:',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text(
                  '• Please arrive 15 minutes before your appointment time\n'
                  '• Carry this letter (printed or on your phone)\n'
                  '• Bring previous medical reports if any\n'
                  '• For queries, contact Remedoo support',
                  style: const pw.TextStyle(
                      fontSize: 12, height: 1.6),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text(
                    'Generated on ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} via Remedoo',
                    style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Remedoo_Appointment_${a.id}.pdf',
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: const pw.TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

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
            onPressed: () => _printReceipt(context),
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
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    onPressed: () => _printReceipt(context),
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
