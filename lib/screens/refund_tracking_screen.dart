import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Refund status: cards with per-refund timelines.
class RefundTrackingScreen extends StatelessWidget {
  const RefundTrackingScreen({super.key});

  static const _steps = [
    'Requested',
    'Approved',
    'Processed',
    'Completed',
  ];

  int _doneIndex(String status) {
    switch (status) {
      case 'requested':
        return 0;
      case 'approved':
        return 1;
      case 'processed':
        return 2;
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = state.refundRequests;
    return Scaffold(
      appBar: AppBar(title: const Text('Refund Status')),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.replay,
              title: 'No refunds',
              subtitle: 'Refund requests will appear here.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _card(list[i]),
            ),
    );
  }

  Widget _card(RefundRequest r) {
    final done = _doneIndex(r.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Refund ${r.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                StatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Order ${r.orderId} • ${r.reason}',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(inr(r.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: RemedooTheme.primary,
                    fontSize: 18)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(_steps.length, (i) {
                final isDone = i <= done;
                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isDone
                              ? RemedooTheme.ratingGreen
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                            isDone
                                ? Icons.check
                                : Icons.circle,
                            size: 14,
                            color: isDone
                                ? Colors.white
                                : Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(_steps[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              color: isDone
                                  ? null
                                  : Colors.grey)),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
