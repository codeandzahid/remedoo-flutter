import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../widgets/widgets.dart';

/// SOS alerts with Acknowledge / Dispatch actions.
class AdminEmergenciesScreen extends StatelessWidget {
  const AdminEmergenciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = state.sosAlerts.toList();
    if (list.isEmpty) {
      return const REmptyState(
        icon: Icons.sos,
        title: 'No SOS alerts',
        subtitle: 'Emergency alerts will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(context, state, list[i]),
    );
  }

  Widget _card(BuildContext context, AppState state, SosAlert a) {
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
                  child: Text(a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
                StatusChip(status: a.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${a.phone} • ${a.location}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              '${a.time.day}/${a.time.month} ${a.time.hour}:${a.time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (a.status != 'dispatched') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (a.status == 'new')
                    Expanded(
                      child: RButton(
                        label: 'Acknowledge',
                        small: true,
                        variant: RButtonVariant.outline,
                        onPressed: () => state.setSosStatus(
                            a.id, 'acknowledged'),
                      ),
                    ),
                  if (a.status == 'new')
                    const SizedBox(width: 10),
                  Expanded(
                    child: RButton(
                      label: 'Dispatch',
                      small: true,
                      icon: Icons.emergency,
                      onPressed: () => state.setSosStatus(
                          a.id, 'dispatched'),
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
