import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../app_navigator.dart';

/// Health reminders with Upcoming / Completed segmented filter.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () =>
                          goBack(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.notifications_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Health Reminders',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 52, top: 2),
                  child: Text(
                      'Stay on top of your health schedule',
                      style: TextStyle(
                          color: Colors.white
                              .withValues(alpha: 0.75),
                          fontSize: 12)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _seg('Upcoming', !_completed,
                        () => setState(() => _completed = false)),
                    const SizedBox(width: 8),
                    _seg('Completed', _completed,
                        () => setState(() => _completed = true)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 760,
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: RButton(
                      label: 'Add Reminder',
                      icon: Icons.add,
                      fullWidth: true,
                      onPressed: () =>
                          _addDialog(context, state),
                    ),
                  ),
                  Expanded(child: _list(state, _completed)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg(
      String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? RemedooTheme.primary
                    : Colors.white)),
      ),
    );
  }

  Widget _list(AppState state, bool completed) {
    final list =
        state.reminders.where((r) => r.done == completed).toList();
    if (list.isEmpty) {
      return REmptyState(
        icon: Icons.alarm,
        title:
            completed ? 'No completed reminders' : 'No reminders yet',
        subtitle: completed
            ? 'Finished reminders will show up here.'
            : 'Set reminders for medicines, checkups and more.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: list.length,
      itemBuilder: (_, i) => StaggerItem(
        index: i % 6,
        child: _card(state, list[i]),
      ),
    );
  }

  Widget _card(AppState state, Reminder r) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => state.toggleReminder(r.id),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: r.done
                      ? RemedooTheme.success
                          .withValues(alpha: 0.18)
                      : scheme.primary
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  r.done
                      ? Icons.check
                      : Icons.alarm_outlined,
                  color: r.done
                      ? RemedooTheme.success
                      : scheme.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: r.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: r.done
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _pill(
                        icon: Icons.schedule,
                        label: r.time,
                        bg: scheme.surfaceContainerHighest,
                        fg: scheme.onSurfaceVariant,
                      ),
                      _pill(
                        label: r.repeat,
                        bg: scheme.primary
                            .withValues(alpha: 0.12),
                        fg: scheme.primary,
                        bold: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _addDialog(context, state, existing: r),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.edit_outlined,
                    size: 20, color: Colors.grey),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => state.deleteReminder(r.id),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.delete_outline,
                    size: 20, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
      {IconData? icon,
      required String label,
      required Color bg,
      required Color fg,
      bool bold = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: fg,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  /// Add dialog, or edit dialog when [existing] is passed. The
  /// chosen Repeat is stored as the reminder's repeat (it used to
  /// be stuffed into the notes field, so every reminder displayed
  /// "Daily" — audit fix 2026-10-19), and the date is pickable
  /// instead of silently always being today. The time is picked
  /// with a real time picker and a note can be added (audit
  /// Patient 14: free-text unvalidated time, description column
  /// never written).
  void _addDialog(BuildContext context, AppState state,
      {Reminder? existing}) {
    final title = TextEditingController(text: existing?.title ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    String repeat = existing?.repeat ?? 'Daily';
    DateTime date = existing?.date ?? DateTime.now();
    TimeOfDay time = _parseTime(existing?.timeLabel) ??
        const TimeOfDay(hour: 9, minute: 0);
    String? error;

    String label(TimeOfDay t) {
      final ap = t.period == DayPeriod.pm ? 'PM' : 'AM';
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      return '$h:${t.minute.toString().padLeft(2, '0')} $ap';
    }

    showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
        builder: (ctx, setD) {
          void save() {
            if (title.text.trim().isEmpty) {
              setD(() => error = 'Please enter a title.');
              return;
            }
            if (existing != null) {
              state.updateReminder(
                existing.id,
                title: title.text.trim(),
                date: date,
                timeLabel: label(time),
                notes: notes.text.trim(),
                repeat: repeat,
              );
            } else {
              state.addReminder(
                title: title.text.trim(),
                date: date,
                timeLabel: label(time),
                notes: notes.text.trim(),
                repeat: repeat,
              );
            }
            Navigator.pop(context);
          }

          return AlertDialog(
            title:
                Text(existing == null ? 'Add Reminder' : 'Edit Reminder'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RTextField(
                      label: 'Title *',
                      hint: 'Reminder title',
                      controller: title),
                  const SizedBox(height: 12),
                  RTextField(
                      label: 'Notes (optional)',
                      hint: 'e.g. Take after food',
                      controller: notes),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.schedule_outlined,
                          size: 18),
                      label: Text('Time: ${label(time)}'),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: time,
                        );
                        if (picked != null) setD(() => time = picked);
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined,
                          size: 18),
                      label: Text(
                          'Date: ${date.day}/${date.month}/${date.year}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) setD(() => date = picked);
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: repeat,
                    decoration:
                        const InputDecoration(labelText: 'Repeat'),
                    items: const ['Daily', 'Weekly', 'Once']
                        .map((o) => DropdownMenuItem(
                            value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) =>
                        setD(() => repeat = v ?? 'Daily'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(error!,
                          style: TextStyle(
                              color:
                                  Theme.of(ctx).colorScheme.error,
                              fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              RButton(
                label: existing == null ? 'Add' : 'Save',
                small: true,
                onPressed: save,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Parses a stored time label ('9:00 AM', '09:00', '21:30') for
  /// the time picker; null when it can't be understood.
  static TimeOfDay? _parseTime(String? label) {
    if (label == null) return null;
    final db = AppState.reminderDbTime(label);
    if (db == null) return null;
    final parts = db.split(':');
    return TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
