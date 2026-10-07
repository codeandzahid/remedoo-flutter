import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../app_navigator.dart';
import 'support_chat_screen.dart';

/// Support tickets ("My Queries"): search + ticket cards + new-ticket form.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() =>
      _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  String _search = '';
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tickets = state.tickets.where((t) {
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return t.id.toLowerCase().contains(q) ||
          t.subject.toLowerCase().contains(q) ||
          t.status.toLowerCase().contains(q);
    }).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: white, back + title + count + New button.
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor),
                ),
              ),
              padding:
                  const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () =>
                            goBack(context),
                      ),
                      Icon(Icons.forum_outlined,
                          color: scheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('My Queries',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${state.tickets.length} total queries',
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      RButton(
                        label: 'New',
                        icon: Icons.add,
                        small: true,
                        onPressed: () =>
                            _newTicket(context, state),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: RSearchBar(
                      hint: 'Search by ticket #, subject...',
                      onChanged: (v) =>
                          setState(() => _search = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tickets.isEmpty
                  ? MaxWidthBox(
                      child: REmptyState(
                        icon: Icons.support_agent,
                        title: 'No queries yet',
                        subtitle:
                            'Need help? Create a ticket and our team will help you out.',
                        actionLabel: 'Create Query',
                        onAction: () =>
                            _newTicket(context, state),
                      ),
                    )
                  : MaxWidthBox(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            20, 16, 20, 24),
                        itemCount: tickets.length,
                        itemBuilder: (_, i) => StaggerItem(
                          index: i % 6,
                          child: _card(tickets[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(SupportTicket t) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = _expandedId == t.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        onTap: () =>
            setState(() => _expandedId = expanded ? null : t.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment:
                  WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('#${t.id}',
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary)),
                ),
                StatusChip(status: t.status),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            Theme.of(context).dividerColor),
                  ),
                  child: Text(t.category,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(t.subject,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(t.description,
                maxLines: expanded ? null : 2,
                overflow:
                    expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                    '${t.date.day}/${t.date.month}/${t.date.year}',
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant)),
                const Spacer(),
                if (expanded)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SupportChatScreen(ticket: t),
                      ),
                    ),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('Chat'),
                  ),
                Icon(
                    expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: scheme.onSurfaceVariant),
              ],
            ),
            if (expanded && t.response.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RemedooTheme.success
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
                    Text(t.response,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _newTicket(BuildContext context, AppState state) {
    final subject = TextEditingController();
    final desc = TextEditingController();
    String category = ticketCategories.first;
    showResponsiveDialog(
      context,
      (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New Support Ticket'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RTextField(
                  label: 'Subject',
                  hint: 'Brief summary...',
                  controller: subject),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                    labelText: 'Category'),
                items: ticketCategories
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setD(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              RTextField(
                  label: 'Description',
                  hint: 'Describe your issue...',
                  controller: desc,
                  maxLines: 3),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            RButton(
              label: 'Submit Ticket',
              small: true,
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
            ),
          ],
        ),
      ),
    );
  }
}
