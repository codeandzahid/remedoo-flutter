import 'package:flutter/material.dart';

import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'cart_screen.dart';
import 'settings_screen.dart';

/// "Payment Failed" with retry options.
class PaymentFailureScreen extends StatelessWidget {
  final double amount;

  const PaymentFailureScreen({super.key, this.amount = 0});

  static const _reasons = [
    'Insufficient balance in the selected account',
    'Card limit reached or card expired',
    'Bank declined the transaction for security',
    'Poor network connection during payment',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: MaxWidthBox(
          maxWidth: 520,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: RemedooTheme.emergency
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 56,
                      color: RemedooTheme.emergency),
                ),
                const SizedBox(height: 24),
                const Text('Payment Unsuccessful',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(
                  'Your payment could not be processed. '
                  'No money was charged. Please try again or choose a different payment method.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onSurfaceVariant),
                ),
                if (amount > 0) ...[
                  const SizedBox(height: 16),
                  RCard(
                    child: Row(
                      children: [
                        Text('Amount',
                            style: TextStyle(
                                color:
                                    scheme.onSurfaceVariant)),
                        const Spacer(),
                        Text(inr(amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                RButton(
                  label: 'Try Again',
                  fullWidth: true,
                  onPressed: () {
                    // Back to the payment step for a real retry.
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 10),
                RButton(
                  label: 'Choose Different Method',
                  variant: RButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CartScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const SettingsScreen()),
                  ),
                  child: const Text(
                      'Need help? Contact Support'),
                ),
                const SizedBox(height: 12),
                RCard(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Common reasons for failure',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      ..._reasons.map((r) => Padding(
                            padding:
                                const EdgeInsets.only(
                                    bottom: 6),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('•  ',
                                    style: TextStyle(
                                        color: scheme
                                            .onSurfaceVariant)),
                                Expanded(
                                  child: Text(r,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: scheme
                                              .onSurfaceVariant)),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 4),
                      Text(
                        '💡 No money has been deducted. If an amount was debited, it will be refunded automatically within 5–7 business days.',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
