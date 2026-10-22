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
import '../widgets/form_kit.dart';
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
  // UI redesign: no pre-selected date/time — both start empty so
  // the form never looks already filled. A reschedule prefill (an
  // explicit upstream choice) still selects its own slot.
  DateTime? _date;
  String? _time;
  late String _payment;
  final _notes = TextEditingController();
  // Department is a dropdown of real specialties (was free text);
  // pre-filled with the provider's own when known.
  String? _departmentSel;
  bool _deptInit = false;
  bool _video = false;
  // Lab collection choice (audit Patient 11).
  String _collectionType = 'walk_in';
  final _collectionAddress = TextEditingController();
  final _payerUpi = TextEditingController();
  late List<DateTime> _days;
  String? _bookingForMemberId; // null = for self

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(7, (i) => now.add(Duration(days: i)));
    if (widget.prefill != null) {
      // Reschedule starts from the appointment's OWN date
      // (full-check fix 2026-10-22: it used to prefill today, so
      // the form opened on the wrong day).
      _date = DateTime(widget.prefill!.date.year,
          widget.prefill!.date.month, widget.prefill!.date.day);
      _time = widget.prefill!.timeLabel;
      if (_date!.isAfter(_days.last)) {
        _days = List.generate(7, (i) => _date!.add(Duration(days: i)));
      }
    }
    _payment = widget.prefill?.payment ?? 'Pay Online';
    if (widget.prefill != null) _notes.text = widget.prefill!.notes;
    // Load the doctor's blocked slots so they can be filtered
    // out of the offered times (audit M14).
    if (widget.kind == 'doctor') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppStateScope.of(context).loadBlockedSlots(widget.refId);
      });
    }
    // Prefill the home-collection address from the profile.
    if (widget.kind == 'lab') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final addr = AppStateScope.of(context).userAddress;
        if (mounted && addr != null && addr.isNotEmpty) {
          _collectionAddress.text = addr;
        }
      });
    }
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
    _collectionAddress.dispose();
    _payerUpi.dispose();
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

    // Remedoo Pay allows only ONE open payment. If one is pending,
    // ask the customer: wait (it auto-expires within 1 minute) or
    // "Pay New" — cancel the pending one and start this payment now.
    PaymentService.instance.onPaymentBusy = () async {
      if (!mounted) return false;
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, size: 36),
          title: const Text('A payment is pending'),
          content: const Text(
            'Another payment is being completed right now. It will '
            'finish, or auto-expire within 5 minutes.\n\n'
            'You can wait and try again — or tap Pay New to cancel '
            'the pending payment and start yours now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Wait'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay New'),
            ),
          ],
        ),
      );
      return choice ?? false;
    };

    PaymentService.instance.pay(
      amount: widget.fee,
      orderId: orderId,
      description: 'Appointment: ${widget.title}',
      providerKind: widget.kind,
      providerId: widget.refId,
      payerUpi: _payerUpi.text.trim().isEmpty
          ? null
          : _payerUpi.text.trim(),
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
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please pick a date and a time first.')),
      );
      return;
    }
    // Owner's rule: no active payment option on the panelist means
    // no booking (the button is disabled too — this is the backstop).
    if (!isReschedule && _payment == 'Not Available') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Booking is not available — this provider has not activated any payment option yet.'),
        ),
      );
      return;
    }
    final state = AppStateScope.of(context);

    // Pay at clinic: show warning with double confirmation
    // (full-check fix 2026-10-22: the 'Pay at Hospital' / 'Pay at
    // Lab' branches here were dead — the payment card only ever
    // sets 'Pay Online' or 'At Clinic').
    if (!isReschedule && _payment == 'At Clinic') {
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
            'on ${_date!.day}/${_date!.month}/${_date!.year} at ${rTime12(_time!)}?\n\n'
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
      final moved = await state.rescheduleAppointment(
        widget.prefill!.id,
        _date!,
        _time!,
      );
      if (!mounted) return;
      if (!moved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not reschedule. The old time is kept — please try again.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment rescheduled!')),
      );
    } else {
      // "Pay Online" uses in-app Razorpay (UPI/cards/netbanking).
      // The appointment is only booked after payment succeeds.
      String? paymentRef;
      if (_payment == 'Pay Online') {
        final orderId =
            'APT${DateTime.now().millisecondsSinceEpoch}';
        paymentRef = orderId;
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
        if (prescriptionUrl == null) {
          // Full-check fix 2026-10-22: a failed upload used to
          // fall back silently to the local device path, which
          // the server write drops — the provider never saw the
          // prescription while the patient believed it was sent.
          // Stop and say so; the patient can retry.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Prescription upload failed. Please check your connection and try again — the booking was not placed.')),
          );
          return;
        }
      }

      final appt = await state.bookAppointment(
        kind: widget.kind,
        refId: widget.refId,
        title: widget.title,
        subtitle: widget.subtitle,
        place: widget.place,
        fee: widget.fee,
        date: _date!,
        timeLabel: _time!,
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
        prescriptionPath: prescriptionUrl,
        prescriptionName: _prescriptionName,
        paymentRef: paymentRef,
        customerUpi: _payerUpi.text.trim().isEmpty
            ? null
            : _payerUpi.text.trim(),
        department: _departmentSel,
        isVideoConsultation: _video,
        collectionType: widget.kind == 'lab' ? _collectionType : null,
        collectionAddress: widget.kind == 'lab' &&
                _collectionType == 'home'
            ? _collectionAddress.text.trim()
            : null,
      );
      if (!mounted) return;
      if (appt == null) {
        // The backend rejected the booking — nothing was booked,
        // so say so instead of celebrating (full-check fix
        // 2026-10-22).
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Booking failed — please check your connection and try again.')),
        );
        return;
      }
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
    final slots = _date == null
        ? const <String>[]
        : st.doctorSlotsFor(widget.refId, widget.title, _date!);
    // Department dropdown options: the real specialties in the
    // catalogue, pre-filled with this provider's own when known.
    final deptOptions = <String>{
      for (final d in st.activeDoctors)
        if (d.specialty.trim().isNotEmpty) d.specialty.trim(),
    }.toList()
      ..sort();
    if (!_deptInit) {
      _deptInit = true;
      if (widget.kind == 'doctor') {
        final own = st.activeDoctors
            .where((d) => d.id == widget.refId)
            .firstOrNull
            ?.specialty
            .trim();
        if (own != null && own.isNotEmpty) _departmentSel = own;
      }
    }
    final isReschedule = widget.prefill != null;
    final prov = _provider(st);
    final payInClinic = prov?.payInClinicEnabled ?? false;

    // Remedoo Pay rule (owner's order): online payment goes straight to
    // the provider's own UPI. A provider who has not added their UPI ID
    // shows online payment as NOT AVAILABLE — no fallback to Remedoo.
    final provUpiReady = prov != null &&
        ((prov.upiId as String?)?.trim().isNotEmpty ?? false) &&
        prov.upiEnabled == true;
    final isYoupi = PaymentService.instance.activeGateway == 'youpi';
    final onlineAvailable = PaymentService.instance.hasActiveGateway &&
        (!isYoupi || provUpiReady);

    // Owner's rule (2026-10-18): a panelist who has not activated ANY
    // payment option — Pay Online (their own UPI) or Pay at Clinic —
    // cannot be booked at all. Rescheduling an existing appointment
    // is not a new booking and stays allowed. When the provider
    // record isn't loaded we cannot prove they offer nothing, so
    // booking is not blocked on missing data.
    final bookingBlocked =
        !isReschedule && prov != null && !payInClinic && !onlineAvailable;

    // Keep the selection on a visible option: providers activate their
    // payment options themselves (Pay Online and/or Pay at Clinic);
    // until they do, neither is selected.
    if (widget.prefill == null) {
      final paymentOptions = <String>[
        if (onlineAvailable) 'Pay Online',
        if (payInClinic) 'At Clinic',
      ];
      if (!paymentOptions.contains(_payment)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _payment = paymentOptions.isNotEmpty
                ? paymentOptions.first
                : 'Not Available');
          }
        });
      }
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
      if (_date == null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Pick a date first — available times will appear here.',
            style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        )
      else
        _timePicker(slots),
      const SizedBox(height: 14),
      RKitField(
        label: 'Notes (optional)',
        icon: Icons.notes_outlined,
        hint: 'Anything the doctor should know…',
        controller: _notes,
        maxLines: 2,
      ),
      const SizedBox(height: 14),
      if (deptOptions.isNotEmpty)
        RKitDropdown<String>(
          label: 'Department (optional)',
          labelIcon: Icons.local_hospital_outlined,
          icon: Icons.local_hospital_outlined,
          value: _departmentSel != null &&
                  deptOptions.contains(_departmentSel)
              ? _departmentSel
              : null,
          hint: 'Choose a department',
          items: deptOptions
              .map((d) =>
                  DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _departmentSel = v),
        ),
      if (widget.kind == 'doctor' &&
          (st.activeDoctors
                  .where((d) => d.id == widget.refId)
                  .firstOrNull
                  ?.videoConsultationEnabled ??
              false)) ...[
        const SizedBox(height: 6),
        RFormSwitchTile(
          icon: Icons.videocam_outlined,
          title: 'Video consultation',
          subtitle:
              'Meet the doctor on a video call instead of visiting',
          value: _video,
          onChanged: (v) => setState(() => _video = v),
        ),
      ],
      // Lab bookings: walk-in or home collection (Patient 11).
      // Home collection is only offered when at least one chosen
      // test supports it.
      if (widget.kind == 'lab' &&
          (widget.tests?.any((t) => t.homeCollection) ?? false)) ...[
        const SizedBox(height: 14),
        _sectionTitle(Icons.home_outlined, 'Sample Collection'),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'walk_in',
              label: Text('Visit lab'),
              icon: Icon(Icons.directions_walk, size: 18),
            ),
            ButtonSegment(
              value: 'home',
              label: Text('Home collection'),
              icon: Icon(Icons.home_outlined, size: 18),
            ),
          ],
          selected: {_collectionType},
          onSelectionChanged: (s) =>
              setState(() => _collectionType = s.first),
        ),
        if (_collectionType == 'home') ...[
          const SizedBox(height: 10),
          RKitField(
            label: 'Collection address',
            icon: Icons.home_outlined,
            hint: 'Where the sample should be collected from',
            controller: _collectionAddress,
            maxLines: 2,
          ),
          if ((widget.tests?.fold<double>(
                      0, (sum, t) => sum + t.homeCollectionFee) ??
                  0) >
              0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Home collection fee applies per test (shown on the lab\'s test list).',
                style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ],
      const SizedBox(height: 14),
      _prescriptionCard(),
      const SizedBox(height: 14),
      _sectionTitle(Icons.credit_card, 'Payment Method'),
      const SizedBox(height: 10),
      if (onlineAvailable) ...[
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
            color: RemedooTheme.warning.withValues(alpha: 0.08),
            border:
                Border.all(color: RemedooTheme.warning.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: RemedooTheme.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    !payInClinic
                        ? 'This ${widget.kind} has not activated any payment option yet — booking is not available.'
                        : isYoupi && !provUpiReady
                            ? 'Online payment is not available for this ${widget.kind} — please pay at the clinic.'
                            : 'Online payment is not available right now — please pay at the clinic.',
                    style: const TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
        if (payInClinic) const SizedBox(height: 10),
      ],
      if (payInClinic)
        _payCard('At Clinic', 'Pay when you visit',
            Icons.payments_outlined),
      // UPI-for-refunds sits BELOW the payment option cards so the
      // option group is never split (UI redesign).
      if (onlineAvailable && _payment == 'Pay Online') ...[
        const SizedBox(height: 14),
        RKitField(
          label: 'Your UPI ID (for refunds, optional)',
          icon: Icons.account_balance_wallet_outlined,
          hint: 'name@bank',
          controller: _payerUpi,
        ),
      ],
    ];

    final summary = _summaryCard();
    // Orange pill via the theme's FilledButton style (kept as FilledButton:
    // widget tests tap this exact widget type).
    final confirm = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: RFormBrand.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      onPressed: bookingBlocked || _date == null || _time == null
          ? null
          : () => _confirm(isReschedule),
      child: Text(bookingBlocked
          ? 'Booking Not Available'
          : isReschedule
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
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: MaxWidthBox(
                            maxWidth: 640,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                ...sections,
                                const SizedBox(height: 24),
                                confirm,
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Sticky summary: the side column does not
                      // scroll with the form (UI redesign).
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                              0, 16, 16, 16),
                          child: summary,
                        ),
                      ),
                    ],
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
        // One extra tile: the calendar, so dates beyond the
        // 7-day strip can be picked (audit Patient 12).
        itemCount: _days.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == _days.length) {
            return InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 90)),
                );
                if (picked == null) return;
                setState(() {
                  final day =
                      DateTime(picked.year, picked.month, picked.day);
                  if (!_days.any((d) =>
                      d.year == day.year &&
                      d.month == day.month &&
                      d.day == day.day)) {
                    _days = [..._days, day]
                      ..sort((a, b) => a.compareTo(b));
                  }
                  _date = day;
                  _time = null;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 66,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 20, color: scheme.primary),
                    const SizedBox(height: 2),
                    Text('More',
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }
          final d = _days[i];
          final sel = _date != null &&
              d.day == _date!.day &&
              d.month == _date!.month &&
              d.year == _date!.year;
          return InkWell(
            key: ValueKey('booking-date-$i'),
            onTap: () => setState(() {
              _date = d;
              _time = null;
            }),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 66,
              decoration: BoxDecoration(
                color: sel ? RFormBrand.blue : scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel
                        ? RFormBrand.blue
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
    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No slots on this date — the provider is closed, on leave, '
          'or fully booked. Please pick another date.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((s) {
        final sel = s == _time;
        return ChoiceChip(
          label: Text(rTime12(s)),
          labelPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          selected: sel,
          onSelected: (_) => setState(() => _time = s),
          selectedColor: RFormBrand.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(
            color:
                sel ? RFormBrand.blue : Theme.of(context).dividerColor,
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
            color: sel ? RFormBrand.blue : Theme.of(context).dividerColor,
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
                      ? RFormBrand.blue.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 20,
                    color: sel
                        ? RFormBrand.blue
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
                                    ? RFormBrand.blue
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
                const Icon(Icons.check_circle, color: RFormBrand.blue),
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
    final dateLabel = _date == null
        ? 'Not selected yet'
        : '${_weekdays[_date!.weekday - 1]}, ${_date!.day} ${_months[_date!.month - 1]}';
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
          _sumRow('Time', _time == null ? 'Not selected yet' : rTime12(_time!)),
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
