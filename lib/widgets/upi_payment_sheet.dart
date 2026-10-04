import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'widgets.dart';

/// UPI payment sheet: shows the provider's UPI ID and a button to pay
/// via UPI app. The payment goes DIRECTLY to the provider's UPI ID —
/// Remedoo never touches the money.
class UpiPaymentSheet extends StatelessWidget {
  final String upiId;
  final String providerName;
  final double amount;
  final String orderId;

  const UpiPaymentSheet({
    super.key,
    required this.upiId,
    required this.providerName,
    required this.amount,
    required this.orderId,
  });

  /// Builds a UPI deep link: upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...
  String get _upiLink {
    final params = {
      'pa': upiId,
      'pn': providerName,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': orderId,
    };
    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }

  Future<void> _launchUpi(BuildContext context) async {
    final uri = Uri.parse(_upiLink);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open UPI app. Please pay manually to the UPI ID shown.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not open UPI app. Please pay manually to the UPI ID shown.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RemedooTheme.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code_2,
                  color: RemedooTheme.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pay via UPI',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Pay directly to $providerName',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UPI ID',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        upiId,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    // Copy UPI ID to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI ID copied')),
                    );
                  },
                  tooltip: 'Copy UPI ID',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Amount: ',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RButton(
            label: 'Pay ₹${amount.toStringAsFixed(0)} via UPI App',
            icon: Icons.open_in_new,
            fullWidth: true,
            onPressed: () => _launchUpi(context),
          ),
          const SizedBox(height: 8),
          Text(
            'You will be redirected to your UPI app (GPay, PhonePe, Paytm, etc.) to complete the payment directly to the provider.',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the UPI payment sheet as a modal bottom sheet.
/// Returns true if the user initiated payment.
Future<bool> showUpiPaymentSheet(
  BuildContext context, {
  required String upiId,
  required String providerName,
  required double amount,
  required String orderId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: UpiPaymentSheet(
          upiId: upiId,
          providerName: providerName,
          amount: amount,
          orderId: orderId,
        ),
      ),
    ),
  );
  return result ?? false;
}
