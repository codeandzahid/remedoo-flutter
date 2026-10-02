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
      return const REmptyState(
        icon: Icons.support_agent_outlined,
        title: 'No tickets',
        subtitle: 'Patient tickets will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.tickets.length,
      itemBuilder: (_, i) =>
          _card(context, state, state.tickets[i]),
    );
  }

  Widget _card(
      BuildContext context, AppState state, SupportTicket t) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                StatusChip(status: t.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('${t.category} • ${t.date.day}/${t.date.month}',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(t.description),
            if (t.response.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RemedooTheme.success
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Reply: ${t.response}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RButton(
                    label: t.response.isEmpty
                        ? 'Reply'
                        : 'Update Reply',
                    small: true,
                    variant: RButtonVariant.outline,
                    onPressed: () =>
                        _replyDialog(context, state, t),
                  ),
                ),
                const SizedBox(width: 10),
                if (t.status == 'open')
                  Expanded(
                    child: RButton(
                      label: 'Resolve',
                      small: true,
                      onPressed: () {
                        t.status = 'resolved';
                        state.refresh();
                      },
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
        title: const Text('Reply to ticket',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        content: RTextField(
          controller: ctrl,
          maxLines: 4,
          hint: 'Write your response…',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Send Reply',
            small: true,
            onPressed: () {
              t.response = ctrl.text.trim();
              state.refresh();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
