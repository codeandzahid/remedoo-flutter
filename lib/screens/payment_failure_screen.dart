import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/widgets.dart';
import 'cart_screen.dart';

/// "Payment Failed" with retry options.
class PaymentFailureScreen extends StatelessWidget {
  final double amount;

  const PaymentFailureScreen({super.key, this.amount = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ResponsiveBody(
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
                    size: 56, color: RemedooTheme.emergency),
              ),
              const SizedBox(height: 24),
              const Text('Payment Failed',
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'Your payment could not be processed. '
                'No money was charged. Please try again or choose a different payment method.',
                textAlign: TextAlign.center,
              ),
              if (amount > 0) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('Amount',
                            style: TextStyle(color: Colors.grey)),
                        const Spacer(),
                        Text(inr(amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Retrying payment… (demo)')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CartScreen()),
                ),
                child: const Text('Choose Different Method'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
