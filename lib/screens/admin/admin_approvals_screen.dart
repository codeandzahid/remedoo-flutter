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
        RSectionHeader(
            title: 'Pending Review',
            subtitle: '${pending.length} applications waiting'),
        const SizedBox(height: 12),
        if (pending.isEmpty)
          const REmptyState(
            icon: Icons.check_circle_outline,
            title: 'All caught up',
            subtitle: 'No pending applications to review.',
          )
        else
          ...pending.map((a) => _card(context, state, a, true)),
        const SizedBox(height: 24),
        RSectionHeader(
            title: 'Decided',
            subtitle: '${done.length} reviewed applications'),
        const SizedBox(height: 12),
        ...done.map((a) => _card(context, state, a, false)),
      ],
    );
  }

  Widget _card(BuildContext context, AppState state,
      ProviderApplication a, bool pending) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: a.name, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${a.role} • ${a.email}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                StatusChip(status: a.status),
              ],
            ),
            const SizedBox(height: 10),
            Text('Phone: ${a.phone} • License: ${a.license}',
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant)),
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RButton(
                      label: 'Reject',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () => state.setApplicationStatus(
                          a.id, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RButton(
                      label: 'Approve',
                      small: true,
                      onPressed: () => state.setApplicationStatus(
                          a.id, 'approved'),
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
