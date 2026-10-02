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
      return const EmptyState(
        icon: Icons.sos,
        title: 'No SOS alerts',
        subtitle: 'Emergency alerts will appear here.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(state, list[i]),
    );
  }

  Widget _card(AppState state, SosAlert a) {
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
            Text('${a.phone} • ${a.location}'),
            Text(
              '${a.time.day}/${a.time.month} ${a.time.hour}:${a.time.minute.toString().padLeft(2, '0')}',
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (a.status != 'dispatched') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (a.status == 'new')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => state.setSosStatus(
                            a.id, 'acknowledged'),
                        child: const Text('Acknowledge'),
                      ),
                    ),
                  if (a.status == 'new')
                    const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => state.setSosStatus(
                          a.id, 'dispatched'),
                      child: const Text('Dispatch'),
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
