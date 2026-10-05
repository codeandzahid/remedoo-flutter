import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../app_navigator.dart';

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
        return -1; // rejected / unknown
    }
  }

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'completed':
        return RemedooTheme.success;
      case 'requested':
        return RemedooTheme.warning;
      case 'approved':
      case 'processed':
        return scheme.primary;
      default:
        return RemedooTheme.destructive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final list = state.refundRequests;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding:
                const EdgeInsets.fromLTRB(12, 8, 20, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white),
                  onPressed: () =>
                      goBack(context),
                ),
                const SizedBox(width: 4),
                const Text('Refund Status',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 720,
              child: list.isEmpty
                  ? const REmptyState(
                      icon: Icons.replay,
                      title: 'No refunds',
                      subtitle:
                          'Refund requests will appear here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          20, 16, 20, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => StaggerItem(
                        index: i % 6,
                        child: _card(context, list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, RefundRequest r) {
    final scheme = Theme.of(context).colorScheme;
    final done = _doneIndex(r.status);
    final color = _statusColor(r.status, scheme);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child:
                      Icon(Icons.replay, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(inr(r.amount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      const SizedBox(height: 2),
                      Text('Order ${r.orderId}',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                StatusChip(status: r.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(r.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (done >= 0)
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
                                ? RemedooTheme.success
                                : scheme
                                    .surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              isDone
                                  ? Icons.check
                                  : Icons.circle,
                              size: 14,
                              color: isDone
                                  ? Colors.white
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 4),
                        Text(_steps[i],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                color: isDone
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RemedooTheme.destructive
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'This refund request was rejected. Please contact support if you need help.',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
