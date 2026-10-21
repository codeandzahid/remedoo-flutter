import 'package:flutter/material.dart';

import '../utils/working_hours.dart';

/// Structured working-hours editor (form-pages audit M4).
///
/// The doctor profile used to keep working hours in a free-text
/// field and, on save, overwrote the structured JSONB schedule
/// with {'note': text}. This editor edits the real per-day
/// open/close times and serialises via [workingHoursToJson], so
/// the schedule the booking flow reads is the schedule the
/// provider set.
class WorkingHoursEditor extends StatefulWidget {
  final Map<String, DayHours> initial;
  final ValueChanged<Map<String, DayHours>> onChanged;

  const WorkingHoursEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<WorkingHoursEditor> createState() => _WorkingHoursEditorState();
}

class _WorkingHoursEditorState extends State<WorkingHoursEditor> {
  late Map<String, DayHours> _days;

  static const _labels = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
    'sun': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _days = Map.of(widget.initial);
  }

  void _emit() => widget.onChanged(Map.of(_days));

  TimeOfDay _toTime(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(String key, bool isStart) async {
    final day = _days[key]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: _toTime(isStart ? day.start! : day.end!),
    );
    if (picked == null) return;
    setState(() {
      _days[key] = isStart
          ? DayHours(_fmt(picked), day.end)
          : DayHours(day.start, _fmt(picked));
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in dayKeys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(_labels[key]!,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: _days[key]!.isOpen,
                  onChanged: (open) {
                    setState(() {
                      _days[key] = open
                          ? const DayHours('09:00', '17:00')
                          : const DayHours.closed();
                    });
                    _emit();
                  },
                ),
                if (_days[key]!.isOpen) ...[
                  TextButton(
                    onPressed: () => _pick(key, true),
                    child: Text(_days[key]!.start!),
                  ),
                  Text('–', style: TextStyle(color: scheme.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => _pick(key, false),
                    child: Text(_days[key]!.end!),
                  ),
                ] else
                  Text('Closed',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}
