import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Order tracking — matches OrderTracking.tsx: gradient header with ETA
/// strip, orange step timeline, pharmacy + call card, address, items + bill,
/// payment row.
class OrderTrackingScreen extends StatelessWidget {
  final MedOrder order;

  const OrderTrackingScreen({super.key, required this.order});

  static const _steps = [
    ('Order Placed', Icons.receipt_long_outlined),
    ('Confirmed', Icons.check),
    ('Out for Delivery', Icons.delivery_dining_outlined),
    ('Delivered', Icons.check),
  ];

  int get _doneIndex {
    switch (order.status) {
      case 'placed':
        return 0;
      case 'confirmed':
      case 'packed':
        return 1;
      case 'out_for_delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    final done = _doneIndex;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HeaderBack(
                        onTap: () =>
                            Navigator.maybePop(context)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('Order Tracking',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          Text('#${o.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.7),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('🕐',
                          style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Delivery',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(o.eta,
                              style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.8),
                                  fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(
              maxWidth: 720,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _timelineCard(context, done),
                  const SizedBox(height: 12),
                  _pharmacyCard(context),
                  const SizedBox(height: 12),
                  _addressCard(context),
                  const SizedBox(height: 12),
                  _itemsBillCard(context),
                  const SizedBox(height: 12),
                  _paymentCard(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard(BuildContext context, int done) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        children: List.generate(_steps.length, (i) {
          final (label, icon) = _steps[i];
          final isDone = i <= done;
          final isCurrent = i == done;
          final isLast = i == _steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDone
                          ? RemedooTheme.primary
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(
                              color: RemedooTheme.primary
                                  .withValues(alpha: 0.25),
                              width: 4,
                            )
                          : null,
                    ),
                    child: Icon(icon,
                        size: 17,
                        color: isDone
                            ? Colors.white
                            : scheme.onSurfaceVariant),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 26,
                      color: i < done
                          ? RemedooTheme.primary
                          : Theme.of(context).dividerColor,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      top: 7, bottom: isLast ? 0 : 22),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isDone
                                ? null
                                : scheme.onSurfaceVariant,
                          )),
                      if (isCurrent &&
                          order.status != 'delivered')
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('In progress…',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      RemedooTheme.primary)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _pharmacyCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child:
                  Text('💊', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.pharmacyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text('Pharmacy',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Material(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => showDialog(
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
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.call,
                    size: 18, color: scheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined,
              size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Address',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(order.address,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsBillCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = order;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Items',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 6),
          ...o.lines.map((l) {
            final unit = l.qty > 0 ? l.lineTotal / l.qty : 0.0;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(l.medicine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5)),
                        Text(
                            'Qty: ${l.qty} × ${inr(unit)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(inr(l.lineTotal),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5)),
                ],
              ),
            );
          }),
          Divider(height: 20, color: Theme.of(context).dividerColor),
          _billRow('Subtotal', inr(o.subtotal), scheme),
          _billRow(
            'Delivery',
            o.deliveryFee == 0
                ? 'FREE'
                : inr(o.deliveryFee),
            scheme,
            valueColor: o.deliveryFee == 0
                ? RemedooTheme.success
                : null,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const Spacer(),
              Text(inr(o.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(
      String label, String value, ColorScheme scheme,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }

  Widget _paymentCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final payLower = order.payment.toLowerCase();
    final emoji = payLower.contains('cash') ? '💵' : '💳';
    return RCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$emoji ${order.payment}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                Text('Status: pending',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(inr(order.total),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}

class _HeaderBack extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderBack({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.arrow_back,
              size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
