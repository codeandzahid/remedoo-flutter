import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Support tickets with new-ticket form.
class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Support Tickets')),
      body: state.tickets.isEmpty
          ? const EmptyState(
              icon: Icons.support_agent,
              title: 'No tickets yet',
              subtitle: 'Raise a ticket and our team will help you out.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.tickets.length,
              itemBuilder: (_, i) =>
                  _card(context, state.tickets[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newTicket(context, state),
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
    );
  }

  Widget _card(BuildContext context, SupportTicket t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color:
                RemedooTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.support_agent,
              color: RemedooTheme.primary),
        ),
        title: Text(t.subject,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${t.category} • ${t.date.day}/${t.date.month}/${t.date.year}'),
        trailing: StatusChip(status: t.status),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description),
                if (t.response.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RemedooTheme.ratingGreen
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('Support response',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(t.response),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _newTicket(BuildContext context, AppState state) {
    final subject = TextEditingController();
    final desc = TextEditingController();
    String category = ticketCategories.first;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New Ticket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subject,
                decoration:
                    const InputDecoration(labelText: 'Subject'),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: ticketCategories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setD(() => category = v ?? category),
                decoration:
                    const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                    labelText: 'Description'),
                maxLines: 3,
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
                if (subject.text.trim().isEmpty) return;
                state.addTicket(
                  subject: subject.text.trim(),
                  category: category,
                  description: desc.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Ticket submitted!')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
