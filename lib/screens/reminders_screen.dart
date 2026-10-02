import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Health reminders with Upcoming / Completed tabs.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Reminders'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: RemedooTheme.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          indicatorColor: RemedooTheme.primary,
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Completed')],
        ),
      ),
      body: MaxWidthBox(
        child: TabBarView(
          controller: _tabs,
          children: [
            _list(state, false),
            _list(state, true),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      ),
    );
  }

  Widget _list(AppState state, bool completed) {
    final list = state.reminders
        .where((r) => r.completed == completed)
        .toList();
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.alarm,
        title: completed ? 'No completed reminders' : 'No reminders yet',
        subtitle: completed
            ? 'Finished reminders will show up here.'
            : 'Set reminders for medicines, checkups and more.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => StaggerItem(
        index: i % 6,
        child: _card(state, list[i]),
      ),
    );
  }

  Widget _card(AppState state, Reminder r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: RemedooTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.alarm,
              color: RemedooTheme.primary),
        ),
        title: Text(r.title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: r.completed
                    ? TextDecoration.lineThrough
                    : null)),
        subtitle: Text('${r.time} • ${r.repeat}'),
        trailing: IconButton(
          icon: Icon(
            r.completed
                ? Icons.check_circle
                : Icons.circle_outlined,
            color: r.completed
                ? RemedooTheme.ratingGreen
                : Colors.grey,
          ),
          onPressed: () => state.toggleReminder(r.id),
        ),
      ),
    );
  }

  void _addDialog(BuildContext context, AppState state) {
    final title = TextEditingController();
    final time = TextEditingController(text: '09:00');
    String repeat = 'Daily';
    showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration:
                    const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: time,
                decoration: const InputDecoration(
                    labelText: 'Time (HH:MM)'),
              ),
              DropdownButtonFormField<String>(
                initialValue: repeat,
                items: const ['Daily', 'Weekly', 'Once']
                    .map((o) => DropdownMenuItem(
                        value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setD(() => repeat = v ?? 'Daily'),
                decoration:
                    const InputDecoration(labelText: 'Repeat'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                state.addReminder(
                  title: title.text.trim(),
                  date: DateTime.now(),
                  timeLabel: time.text.trim(),
                  notes: repeat,
                );
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
