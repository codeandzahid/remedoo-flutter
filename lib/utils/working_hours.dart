/// Structured working-hours handling (form-pages audit M4/M14).
///
/// The backend stores working_hours as JSONB shaped like
/// {"mon-fri": "09:00-17:00", "sat": "09:00-14:00", "sun": "closed"}
/// (schema defaults). The doctor panel used to overwrite that
/// with {'note': free text} on every profile save, destroying
/// the schedule. These helpers parse the stored shapes (range
/// keys and per-day keys), expand them to per-day values, and
/// serialise back to per-day keys — and they generate the real
/// booking slots for a date.

/// One day's hours; null start/end means closed.
class DayHours {
  final String? start; // 'HH:MM'
  final String? end; // 'HH:MM'

  const DayHours(this.start, this.end);
  const DayHours.closed()
      : start = null,
        end = null;

  bool get isOpen => start != null && end != null;

  @override
  bool operator ==(Object other) =>
      other is DayHours && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// DateTime.weekday (Mon=1..Sun=7) → our day key.
String dayKeyForWeekday(int weekday) => dayKeys[(weekday - 1) % 7];

DayHours _parseRange(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty || v == 'closed' || v == 'off') {
    return const DayHours.closed();
  }
  final parts = v.split('-');
  if (parts.length != 2) return const DayHours.closed();
  final s = parts[0].trim();
  final e = parts[1].trim();
  if (!_isTime(s) || !_isTime(e)) return const DayHours.closed();
  return DayHours(_norm(s), _norm(e));
}

bool _isTime(String s) =>
    RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s) &&
    int.parse(s.split(':')[0]) <= 23 &&
    int.parse(s.split(':')[1]) <= 59;

String _norm(String s) {
  final p = s.split(':');
  return '${p[0].padLeft(2, '0')}:${p[1]}';
}

/// Parses stored working_hours JSONB into per-day hours. Range
/// keys ('mon-fri') expand to each covered day; unknown shapes
/// yield an all-closed map, and null yields the standard default
/// (Mon–Fri 09:00–17:00, Sat 09:00–14:00, Sun closed) so a
/// provider who never set hours still offers sane slots.
Map<String, DayHours> parseWorkingHours(dynamic raw) {
  if (raw is! Map) return _defaults();
  final out = <String, DayHours>{
    for (final k in dayKeys) k: const DayHours.closed(),
  };
  var any = false;
  raw.forEach((key, value) {
    if (value == null) return;
    final k = '$key'.trim().toLowerCase();
    final hours = _parseRange('$value');
    if (dayKeys.contains(k)) {
      out[k] = hours;
      any = true;
    } else if (k.contains('-')) {
      final bounds = k.split('-');
      final from = dayKeys.indexOf(bounds.first.trim());
      final to = dayKeys.indexOf(bounds.last.trim());
      if (from >= 0 && to >= from) {
        for (var i = from; i <= to; i++) {
          out[dayKeys[i]] = hours;
        }
        any = true;
      }
    }
  });
  return any ? out : _defaults();
}

Map<String, DayHours> _defaults() => {
      'mon': const DayHours('09:00', '17:00'),
      'tue': const DayHours('09:00', '17:00'),
      'wed': const DayHours('09:00', '17:00'),
      'thu': const DayHours('09:00', '17:00'),
      'fri': const DayHours('09:00', '17:00'),
      'sat': const DayHours('09:00', '14:00'),
      'sun': const DayHours.closed(),
    };

/// Serialises per-day hours back to JSONB (per-day keys, closed
/// days written explicitly so a stored range can't resurrect
/// hours the provider turned off).
Map<String, String> workingHoursToJson(Map<String, DayHours> days) {
  return {
    for (final k in dayKeys)
      k: (days[k]?.isOpen ?? false)
          ? '${days[k]!.start}-${days[k]!.end}'
          : 'closed',
  };
}

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _label(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// The slot labels ('HH:MM') a provider offers on [date], given
/// their hours and consultation length. Empty when the day is
/// closed or the date is a vacation day.
List<String> slotsForDate(
  Map<String, DayHours> hours,
  DateTime date, {
  int durationMinutes = 30,
  List<String> vacationDates = const [],
}) {
  final iso = date.toIso8601String().substring(0, 10);
  if (vacationDates.contains(iso)) return const [];
  final day = hours[dayKeyForWeekday(date.weekday)];
  if (day == null || !day.isOpen) return const [];
  final start = _minutes(day.start!);
  final end = _minutes(day.end!);
  final step = durationMinutes <= 0 ? 30 : durationMinutes;
  final out = <String>[];
  for (var m = start; m + step <= end; m += step) {
    out.add(_label(m));
  }
  return out;
}

/// True when [label] ('HH:MM') falls inside a blocked range
/// (doctor_blocked_slots row shape). A full-day block covers
/// every slot.
bool slotBlocked(String label, Map<String, dynamic> block) {
  if (block['is_full_day'] == true) return true;
  final s = '${block['start_time'] ?? ''}';
  final e = '${block['end_time'] ?? ''}';
  if (s.length < 5 || e.length < 5) return false;
  final t = _minutes(label);
  return t >= _minutes(s.substring(0, 5)) && t < _minutes(e.substring(0, 5));
}

/// Display rows for a "Working Hours" card, built from the
/// provider's real stored hours (full-check fix 2026-10-22: the
/// doctor and hospital pages showed the same hard-coded hours for
/// everyone). Consecutive days with identical hours collapse
/// into one row ("Mon – Fri"). A null/unset value yields the
/// standard default schedule — the same one booking slots use.
List<({String days, String hours, bool closed})> workingHoursDisplayRows(
    dynamic raw) {
  final parsed = parseWorkingHours(raw);
  const names = {
    'mon': 'Monday',
    'tue': 'Tuesday',
    'wed': 'Wednesday',
    'thu': 'Thursday',
    'fri': 'Friday',
    'sat': 'Saturday',
    'sun': 'Sunday',
  };
  String fmt(String hhmm) {
    final p = hhmm.split(':');
    var h = int.parse(p[0]);
    final suffix = h >= 12 ? 'PM' : 'AM';
    h = h % 12 == 0 ? 12 : h % 12;
    return '$h:${p[1]} $suffix';
  }

  final rows = <({String days, String hours, bool closed})>[];
  var i = 0;
  while (i < dayKeys.length) {
    final day = parsed[dayKeys[i]]!;
    var j = i;
    while (j + 1 < dayKeys.length && parsed[dayKeys[j + 1]] == day) {
      j++;
    }
    final label = i == j
        ? names[dayKeys[i]]!
        : '${names[dayKeys[i]]} – ${names[dayKeys[j]]}';
    rows.add((
      days: label,
      hours: day.isOpen ? '${fmt(day.start!)} – ${fmt(day.end!)}' : 'Closed',
      closed: !day.isOpen,
    ));
    i = j + 1;
  }
  return rows;
}

/// One-line summary of today's hours, e.g. "Today: 9:00 AM –
/// 5:00 PM" or "Closed today" — for compact panels.
String todayHoursLabel(dynamic raw) {
  final parsed = parseWorkingHours(raw);
  final today = parsed[dayKeyForWeekday(DateTime.now().weekday)]!;
  if (!today.isOpen) return 'Closed today';
  String fmt(String hhmm) {
    final p = hhmm.split(':');
    var h = int.parse(p[0]);
    final suffix = h >= 12 ? 'PM' : 'AM';
    h = h % 12 == 0 ? 12 : h % 12;
    return '$h:${p[1]} $suffix';
  }

  return 'Today: ${fmt(today.start!)} – ${fmt(today.end!)}';
}
