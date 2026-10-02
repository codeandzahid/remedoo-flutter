import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'appointments_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(7, (i) => now.add(Duration(days: i)));
    _date = widget.prefill != null
        ? DateTime(now.year, now.month, now.day)
        : _days.first;
    _time = widget.prefill?.timeLabel ?? '10:00';
    _payment = widget.prefill?.payment ?? 'At Clinic';
    if (widget.prefill != null) _notes.text = widget.prefill!.notes;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _confirm(bool isReschedule) {
    final state = AppStateScope.of(context);
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
      state.bookAppointment(
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
    final slots = AppStateScope.of(context).slotsFor(_date);
    final isReschedule = widget.prefill != null;

    final sections = <Widget>[
      _providerCard(),
      if (widget.tests != null && widget.tests!.isNotEmpty) ...[
        const SizedBox(height: 12),
        _testsCard(),
      ],
      const SizedBox(height: 20),
      _sectionTitle(Icons.calendar_month, 'Select Date'),
      const SizedBox(height: 10),
      _datePicker(),
      const SizedBox(height: 20),
      _sectionTitle(Icons.schedule, 'Select Time'),
      const SizedBox(height: 10),
      _timePicker(slots),
      const SizedBox(height: 20),
      RTextField(
        label: 'Notes (optional)',
        hint: 'Anything the doctor should know…',
        controller: _notes,
        maxLines: 2,
      ),
      const SizedBox(height: 20),
      _sectionTitle(Icons.credit_card, 'Payment Method'),
      const SizedBox(height: 10),
      _payCard('At Clinic', 'Pay when you visit', Icons.payments_outlined),
      const SizedBox(height: 10),
      _payCard('Pay Online', 'Auto-confirm your slot', Icons.credit_card),
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
                  onPressed: () => Navigator.maybePop(context),
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
      height: 84,
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

  Widget _payCard(String value, String sub, IconData icon) {
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
                    Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? scheme.primary
                                : scheme.onSurface)),
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
