import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../services/payment_service.dart';
import '../services/supabase_repository.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'appointments_screen.dart';
import '../app_navigator.dart';

/// Book an appointment for a doctor, hospital or lab visit.
/// Layout mirrors the React BookAppointment page: orange gradient header,
/// provider card, date strip, time-slot grid, notes, payment toggle cards,
/// booking summary and an orange pill confirm button.
///
/// NOTE (regression): the payment toggle cards must stay InkWell-wrapped,
/// time slots must stay ChoiceChips, and the confirm action must stay a
/// FilledButton — widget tests depend on this structure.
class BookingScreen extends StatefulWidget {
  final String kind; // doctor | hospital | lab
  final String refId;
  final String title;
  final String subtitle;
  final String place;
  final double fee;
  final List<LabTest>? tests;
  final Appointment? prefill; // reschedule mode

  const BookingScreen({
    super.key,
    required this.kind,
    required this.refId,
    required this.title,
    required this.subtitle,
    required this.place,
    required this.fee,
    this.tests,
    this.prefill,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

class _BookingScreenState extends State<BookingScreen> {
  late DateTime _date;
  late String _time;
  late String _payment;
  final _notes = TextEditingController();
  late List<DateTime> _days;
  String? _bookingForMemberId; // null = for self

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(7, (i) => now.add(Duration(days: i)));
    _date = widget.prefill != null
        ? DateTime(now.year, now.month, now.day)
        : _days.first;
    _time = widget.prefill?.timeLabel ?? '10:00';
    _payment = widget.prefill?.payment ?? 'Pay Online';
    if (widget.prefill != null) _notes.text = widget.prefill!.notes;
  }

  String? _prescriptionPath;
  String? _prescriptionName;
  Uint8List? _prescriptionBytes;

  Widget _prescriptionCard() {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Prescription (optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Upload a prescription for the doctor to review',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_prescriptionName != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_prescriptionName!,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () =>
                            _previewPrescription(context),
                        child: const Text('Preview'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _prescriptionPath = null;
                          _prescriptionName = null;
                          _prescriptionBytes = null;
                        }),
                      ),
                    ],
                  ),
                  // Show image thumbnail preview
                  if (_prescriptionBytes != null &&
                      !_prescriptionName!
                          .toLowerCase()
                          .endsWith('.pdf')) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _previewPrescription(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _prescriptionBytes!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            RButton(
              label: 'Upload Prescription',
              icon: Icons.upload_file,
              variant: RButtonVariant.outline,
              onPressed: () async {
                final files = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                );
                if (files != null && files.isNotEmpty) {
                  final file = files.single;
                  Uint8List? data;
                  try {
                    data = await file.readAsBytes();
                  } catch (_) {}
                  if (!context.mounted) return;
                  setState(() {
                    _prescriptionPath = file.path;
                    _prescriptionName = file.name;
                    _prescriptionBytes = data;
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  void _previewPrescription(BuildContext context) {
    if (_prescriptionBytes == null || _prescriptionName == null) return;
    final isPdf = _prescriptionName!.toLowerCase().endsWith('.pdf');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _prescriptionName!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: isPdf
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf,
                              size: 64, color: Colors.red),
                          SizedBox(height: 16),
                          Text(
                              'PDF selected. It will be uploaded with your booking.'),
                        ],
                      )
                    : InteractiveViewer(
                        child: Image.memory(
                          _prescriptionBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bookingForCard(AppState st) {    final members = st.family;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking for',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Myself (${st.displayName})'),
                selected: _bookingForMemberId == null,
                onSelected: (_) =>
                    setState(() => _bookingForMemberId = null),
              ),
              ...members.map((m) => ChoiceChip(
                    label: Text('${m.name} (${m.relation})'),
                    selected: _bookingForMemberId == m.id,
                    onSelected: (_) =>
                        setState(() => _bookingForMemberId = m.id),
                  )),
            ],
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Add family members in Family section to book for them.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// Returns the provider object for toggle checks.
  dynamic _provider(AppState state) {
    if (widget.kind == 'doctor') {
      final d = state.activeDoctors.where((d) => d.id == widget.refId);
      if (d.isNotEmpty) return d.first;
    } else if (widget.kind == 'lab') {
      final l = state.activeLabs.where((l) => l.id == widget.refId);
      if (l.isNotEmpty) return l.first;
    } else if (widget.kind == 'hospital') {
      final h = state.activeHospitals.where((h) => h.id == widget.refId);
      if (h.isNotEmpty) return h.first;
    }
    return null;
  }

  /// Process in-app Razorpay payment. Returns true if payment succeeded.
  /// Process Razorpay Route payment: creates a split order via Edge Function
  /// (money auto-splits to provider), then opens Razorpay checkout.
  /// Standard Razorpay checkout (no Route needed).
  /// Uses the test/live key from Admin > Settings > Payments.
  Future<bool> _processRazorpayPayment(String orderId) async {
    final completer = Completer<bool>();
    final state = AppStateScope.of(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Opening ${PaymentService.instance.gatewayDisplayName} payment...')),
      );
    }

    PaymentService.instance.pay(
      amount: widget.fee,
      orderId: orderId,
      description: 'Appointment: ${widget.title}',
      contact: state.phone.isNotEmpty ? state.phone : null,
      email: state.email.isNotEmpty ? state.email : null,
      customerName: state.userName.isNotEmpty ? state.userName : null,
      onPaymentSuccess: (paymentId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment successful: $paymentId')),
          );
        }
        if (!completer.isCompleted) completer.complete(true);
      },
      onPaymentError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed: $error')),
          );
        }
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    return completer.future;
  }


  void _confirm(bool isReschedule) async {
    if (!checkLogin(context, 'Please login to book appointments')) return;
    final state = AppStateScope.of(context);

    // Pay at clinic: show warning with double confirmation
    if (!isReschedule &&
        (_payment == 'At Clinic' ||
            _payment == 'Pay at Hospital' ||
            _payment == 'Pay at Lab')) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pay at Clinic'),
          content: const Text(
            'Please note:\n\n'
            '• This booking is NOT 100% guaranteed\n'
            '• The doctor may cancel or reschedule\n'
            '• You may have to wait in queue at the clinic\n'
            '• Payment is due at the clinic\n\n'
            'Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('I Understand, Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      // Second confirmation
      final doubleConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Final Confirmation'),
          content: Text(
            'Book appointment with ${widget.title}\n'
            'on ${_date.day}/${_date.month}/${_date.year} at $_time?\n\n'
            'This will send a request to the doctor for approval.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Book Appointment'),
            ),
          ],
        ),
      );
      if (doubleConfirmed != true || !mounted) return;
    }

    if (isReschedule) {
      state.rescheduleAppointment(
        widget.prefill!.id,
        _date,
        _time,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment rescheduled!')),
      );
    } else {
      // "Pay Online" uses in-app Razorpay (UPI/cards/netbanking).
      // The appointment is only booked after payment succeeds.
      if (_payment == 'Pay Online') {
        final orderId =
            'APT${DateTime.now().millisecondsSinceEpoch}';
        if (!PaymentService.instance.isConfigured) {
          // No gateway active: popup explains and switches the
          // customer to the offline option instead of booking online.
          if (mounted) {
            await PaymentService.showNoGatewayDialog(context,
                offlineLabel: 'Pay at Clinic');
            if (mounted) setState(() => _payment = 'At Clinic');
          }
          return;
        }
        final paid = await _processRazorpayPayment(orderId);
        // Payment failed or cancelled: do not book.
        if (!paid || !mounted) return;
      }
      // Upload prescription if attached
      String? prescriptionUrl;
      if (_prescriptionName != null &&
          (_prescriptionBytes != null || _prescriptionPath != null)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading prescription...')),
          );
        }
        prescriptionUrl =
            await SupabaseRepository.instance.uploadPrescriptionData(
          _prescriptionBytes,
          _prescriptionPath,
          _prescriptionName!,
        );
      }

      final appt = state.bookAppointment(
        kind: widget.kind,
        refId: widget.refId,
        title: widget.title,
        subtitle: widget.subtitle,
        place: widget.place,
        fee: widget.fee,
        date: _date,
        timeLabel: _time,
        payment: _payment,
        notes: _notes.text.trim(),
        tests: widget.tests ?? const [],
        bookingForMemberId: _bookingForMemberId,
        bookingForName: _bookingForMemberId == null
            ? null
            : state.family
                .where((m) => m.id == _bookingForMemberId)
                .firstOrNull
                ?.name,
        prescriptionPath: prescriptionUrl ?? _prescriptionPath,
        prescriptionName: _prescriptionName,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully!')),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
      (r) => r.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppStateScope.of(context);
    final slots = st.doctorSlotsFor(widget.refId, widget.title, _date);
    final isReschedule = widget.prefill != null;
    final prov = _provider(st);
    final payInClinic = prov?.payInClinicEnabled ?? true;

    // No active gateway: Pay Online is hidden, so never leave it
    // selected — fall back to the offline option automatically.
    if (!PaymentService.instance.hasActiveGateway &&
        _payment == 'Pay Online') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _payment = 'At Clinic');
      });
    }

    final sections = <Widget>[
      _providerCard(),
      const SizedBox(height: 12),
      _bookingForCard(st),
      if (widget.tests != null && widget.tests!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _testsCard(),
      ],
      const SizedBox(height: 14),
      _sectionTitle(Icons.calendar_month, 'Select Date'),
      const SizedBox(height: 10),
      _datePicker(),
      const SizedBox(height: 14),
      _sectionTitle(Icons.schedule, 'Select Time'),
      const SizedBox(height: 10),
      _timePicker(slots),
      const SizedBox(height: 14),
      RTextField(
        label: 'Notes (optional)',
        hint: 'Anything the doctor should know…',
        controller: _notes,
        maxLines: 2,
      ),
      const SizedBox(height: 14),
      _prescriptionCard(),
      const SizedBox(height: 14),
      _sectionTitle(Icons.credit_card, 'Payment Method'),
      const SizedBox(height: 10),
      if (PaymentService.instance.hasActiveGateway) ...[
        _payCard(
            'Pay Online',
            'UPI, Cards & Netbanking via '
                '${PaymentService.instance.gatewayDisplayName}',
            Icons.credit_card,
            badge: 'Secure'),
        if (payInClinic) const SizedBox(height: 10),
      ] else ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Online payment is not available right now — please pay at the clinic.',
                    style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
        if (payInClinic) const SizedBox(height: 10),
      ],
      if (payInClinic)
        _payCard('At Clinic', 'Pay when you visit',
            Icons.payments_outlined),
    ];

    final summary = _summaryCard();
    // Orange pill via the theme's FilledButton style (kept as FilledButton:
    // widget tests tap this exact widget type).
    final confirm = FilledButton(
      onPressed: () => _confirm(isReschedule),
      child: Text(isReschedule
          ? 'Confirm Reschedule'
          : 'Confirm Booking • ${inr(widget.fee)}'),
    );

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
                  child: Text(
                    isReschedule ? 'Reschedule' : 'Book Appointment',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: context.isCompact
                ? MaxWidthBox(
                    maxWidth: 640,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ...sections,
                        const SizedBox(height: 16),
                        summary,
                        const SizedBox(height: 24),
                        confirm,
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: DetailSplit(
                      main: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...sections,
                          const SizedBox(height: 24),
                          confirm,
                        ],
                      ),
                      side: summary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }

  Widget _providerCard() {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking with',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                widget.kind[0].toUpperCase() +
                    widget.kind.substring(1),
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600),
              ),
              if (widget.fee > 0) ...[
                const SizedBox(width: 6),
                Text('· ${inr(widget.fee)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _testsCard() {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selected Tests',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          ...widget.tests!.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(inr(t.price),
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _datePicker() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = _days[i];
          final sel = d.day == _date.day && d.month == _date.month;
          return InkWell(
            onTap: () => setState(() => _date = d),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 66,
              decoration: BoxDecoration(
                color: sel ? scheme.primary : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel
                        ? scheme.primary
                        : Theme.of(context).dividerColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_weekdays[d.weekday - 1],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: sel
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                          fontSize: 12)),
                  Text('${d.day}',
                      style: TextStyle(
                          color: sel ? Colors.white : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _timePicker(List<String> slots) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((s) {
        final sel = s == _time;
        return ChoiceChip(
          label: Text(s),
          labelPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          selected: sel,
          onSelected: (_) => setState(() => _time = s),
          selectedColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(
            color:
                sel ? scheme.primary : Theme.of(context).dividerColor,
          ),
          labelStyle: TextStyle(
              color: sel ? Colors.white : scheme.onSurface,
              fontWeight: FontWeight.w600),
        );
      }).toList(),
    );
  }

  Widget _payCard(String value, String sub, IconData icon,
      {String? badge}) {
    final scheme = Theme.of(context).colorScheme;
    final sel = _payment == value;
    return InkWell(
      onTap: () => setState(() => _payment = value),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: sel ? scheme.primary : Theme.of(context).dividerColor,
            width: sel ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sel
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 20,
                    color: sel
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(value,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? scheme.primary
                                    : scheme.onSurface)),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(badge,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green)),
                          ),
                        ],
                      ],
                    ),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (sel)
                Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    final scheme = Theme.of(context).colorScheme;
    final dateLabel =
        '${_weekdays[_date.weekday - 1]}, ${_date.day} ${_months[_date.month - 1]}';
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Summary',
              style:
                  TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          _sumRow('Provider', widget.title),
          _sumRow('Date', dateLabel),
          _sumRow('Time', _time),
          _sumRow('Payment', _payment),
          const Divider(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Total payable',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(inr(widget.fee),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: scheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Free cancellation up to 2 hours before your slot.',
            style: TextStyle(
                fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
