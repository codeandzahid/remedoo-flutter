import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Order tracking: ETA, vertical timeline, items, bill.
class OrderTrackingScreen extends StatelessWidget {
  final MedOrder order;

  const OrderTrackingScreen({super.key, required this.order});

  static const _steps = [
    ('Placed', Icons.receipt),
    ('Confirmed', Icons.check_circle),
    ('Out for Delivery', Icons.delivery_dining),
    ('Delivered', Icons.home),
  ];

  int get _doneIndex {
    switch (order.status) {
      case 'placed':
        return 0;
      case 'packed':
        return 1;
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final done = _doneIndex;
    return Scaffold(
      appBar: AppBar(title: Text('Order Tracking • ${o.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: RemedooTheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.timer,
                        color: RemedooTheme.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated arrival',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        Text(o.eta,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  StatusChip(status: o.status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(_steps.length, (i) {
                  final (label, icon) = _steps[i];
                  final isDone = i <= done;
                  final isLast = i == _steps.length - 1;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? RemedooTheme.ratingGreen
                                  : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon,
                                size: 18,
                                color: isDone
                                    ? Colors.white
                                    : Colors.grey),
                          ),
                          if (!isLast)
                            Container(
                              width: 3,
                              height: 28,
                              color: i < done
                                  ? RemedooTheme.ratingGreen
                                  : Colors.grey.shade200,
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDone ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront,
                          color: RemedooTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(o.pharmacyName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Call pharmacy'),
                            content: const Text(
                                'Calling the pharmacy… (demo)'),
                            actions: [
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        ),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ],
                  ),
                  const Divider(),
                  InfoRow(
                      icon: Icons.location_on,
                      label: 'Deliver to',
                      value: o.address),
                  InfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Payment',
                      value: o.payment),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Items',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...o.lines.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  '${l.medicine.name} × ${l.qty}'),
                            ),
                            Text(inr(l.lineTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Total',
                          style:
                              TextStyle(color: Colors.grey)),
                      const Spacer(),
                      Text(inr(o.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: RemedooTheme.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
