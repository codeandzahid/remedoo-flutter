import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

/// Admin support tickets with a reply box.
class AdminSupportTicketsScreen extends StatelessWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (state.tickets.isEmpty) {
      return const EmptyState(
        icon: Icons.support_agent,
        title: 'No tickets',
        subtitle: 'Patient tickets will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.tickets.length,
      itemBuilder: (_, i) =>
          _card(context, state, state.tickets[i]),
    );
  }

  Widget _card(
      BuildContext context, AppState state, SupportTicket t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.subject,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800)),
                ),
                StatusChip(status: t.status),
              ],
            ),
            Text('${t.category} • ${t.date.day}/${t.date.month}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(t.description),
            if (t.response.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RemedooTheme.ratingGreen
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Reply: ${t.response}'),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _replyDialog(context, state, t),
                    child: Text(t.response.isEmpty
                        ? 'Reply'
                        : 'Update Reply'),
                  ),
                ),
                const SizedBox(width: 8),
                if (t.status == 'open')
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        t.status = 'resolved';
                        state.refresh();
                      },
                      child: const Text('Resolve'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _replyDialog(
      BuildContext context, AppState state, SupportTicket t) {
    final ctrl = TextEditingController(text: t.response);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reply to ticket'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
              hintText: 'Write your response…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              t.response = ctrl.text.trim();
              state.refresh();
              Navigator.pop(context);
            },
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }
}
