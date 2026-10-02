import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

/// Pending provider applications with Approve / Reject.
class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final pending = state.providerApplications
        .where((a) => a.status == 'pending')
        .toList();
    final done = state.providerApplications
        .where((a) => a.status != 'pending')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Pending Review',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No pending applications.'),
            ),
          )
        else
          ...pending.map((a) => _card(context, state, a, true)),
        const SizedBox(height: 16),
        const Text('Decided',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...done.map((a) => _card(context, state, a, false)),
      ],
    );
  }

  Widget _card(BuildContext context, AppState state,
      ProviderApplication a, bool pending) {
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
                  child: Text(a.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                StatusChip(status: a.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('${a.role} • ${a.email} • ${a.phone}'),
            Text('License: ${a.license}',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
            if (pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      onPressed: () => state.setApplicationStatus(
                          a.id, 'rejected'),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => state.setApplicationStatus(
                          a.id, 'approved'),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
