import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'appointments_screen.dart';

/// Book an appointment for a doctor, hospital or lab visit.
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

  @override
  Widget build(BuildContext context) {
    final slots = AppStateScope.of(context).slotsFor(_date);
    final isReschedule = widget.prefill != null;
    return Scaffold(
      appBar:
          AppBar(title: Text(isReschedule ? 'Reschedule' : 'Book Appointment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InitialsAvatar(name: widget.title, radius: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(widget.subtitle,
                            style: const TextStyle(
                                color: RemedooTheme.primary,
                                fontWeight: FontWeight.w600)),
                        Text(widget.place,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(inr(widget.fee),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: RemedooTheme.primary)),
                ],
              ),
            ),
          ),
          if (widget.tests != null && widget.tests!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected Tests',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...widget.tests!.map((t) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(t.name)),
                              Text(inr(t.price),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Select Date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
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
                    width: 62,
                    decoration: BoxDecoration(
                      color: sel
                          ? RemedooTheme.primary
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: sel
                              ? RemedooTheme.primary
                              : Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_weekdays[d.weekday - 1],
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : Colors.grey,
                                fontSize: 12)),
                        Text('${d.day}',
                            style: TextStyle(
                                color:
                                    sel ? Colors.white : null,
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Time',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((s) {
              final sel = s == _time;
              return ChoiceChip(
                label: Text(s),
                selected: sel,
                onSelected: (_) => setState(() => _time = s),
                selectedColor: RemedooTheme.primary,
                labelStyle: TextStyle(
                    color: sel
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Notes (optional)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
                hintText: 'Anything the doctor should know…'),
          ),
          const SizedBox(height: 16),
          const Text('Payment',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          _payCard('At Clinic', 'Pay when you visit',
              Icons.payments_outlined),
          _payCard('Pay Online', 'Auto-confirm your slot',
              Icons.credit_card),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final state = AppStateScope.of(context);
              if (isReschedule) {
                state.rescheduleAppointment(
                  widget.prefill!.id,
                  _date,
                  _time,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Appointment rescheduled!')),
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
                  const SnackBar(
                      content:
                          Text('Appointment booked successfully!')),
                );
              }
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const AppointmentsScreen()),
                (r) => r.isFirst,
              );
            },
            child: Text(isReschedule
                ? 'Confirm Reschedule'
                : 'Confirm Booking • ${inr(widget.fee)}'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _payCard(String value, String sub, IconData icon) {
    final sel = _payment == value;
    return InkWell(
      onTap: () => setState(() => _payment = value),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: sel ? RemedooTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon,
                  color: sel
                      ? RemedooTheme.primary
                      : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (sel)
                const Icon(Icons.check_circle,
                    color: RemedooTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
