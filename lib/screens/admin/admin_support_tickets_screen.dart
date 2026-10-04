import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/widgets.dart';

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    return '${d.day}/${d.month}/${d.year}';
  } catch (_) {
    return iso;
  }
}

/// Admin support tickets from Supabase with reply + status.
class AdminSupportTicketsScreen extends StatefulWidget {
  const AdminSupportTicketsScreen({super.key});

  @override
  State<AdminSupportTicketsScreen> createState() =>
      _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState
    extends State<AdminSupportTicketsScreen> {
  bool _loading = true;

  static const _statuses = [
    'open',
    'in_progress',
    'resolved',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context).loadSupportTickets();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    if (state.supportTickets.isEmpty) {
      return const REmptyState(
        icon: Icons.support_agent_outlined,
        title: 'No tickets',
        subtitle: 'Patient tickets will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.supportTickets.length,
        itemBuilder: (_, i) => _card(
            context, state, state.supportTickets[i]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> t) {
    final scheme = Theme.of(context).colorScheme;
    final id = '${t['id']}';
    final response =
        (t['admin_response'] as String?)?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${t['subject'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15)),
                ),
                StatusChip(status: '${t['status'] ?? ''}'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                '${t['category'] ?? 'general'} • ${_fmtDate(t['created_at']?.toString())}',
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('${t['description'] ?? ''}'),
            if (response.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RemedooTheme.success
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Reply: $response',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RButton(
                    label: response.isEmpty
                        ? 'Reply'
                        : 'Update Reply',
                    small: true,
                    variant: RButtonVariant.outline,
                    onPressed: () =>
                        _replyDialog(context, state, t),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statuses
                            .contains('${t['status']}')
                        ? '${t['status']}'
                        : 'open',
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                                s.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      final ok =
                          await state.updateSupportTicket(
                              id, {'status': v});
                      if (context.mounted && !ok) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Update failed. Try again.')),
                        );
                      }
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

  void _replyDialog(BuildContext context, AppState state,
      Map<String, dynamic> t) {
    final ctrl = TextEditingController(
        text: (t['admin_response'] as String?) ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reply to ticket',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800)),
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
            onPressed: () async {
              final text = ctrl.text.trim();
              Navigator.pop(context);
              final ok = await state.updateSupportTicket(
                  '${t['id']}',
                  {
                    'admin_response': text,
                    'status': 'in_progress',
                  });
              if (context.mounted && !ok) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Reply failed. Try again.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
