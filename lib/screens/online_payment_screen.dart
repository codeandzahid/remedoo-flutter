import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../responsive/responsive.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Online payment page: shows the amount due and collects payment via UPI
/// (the real payment rail — the money goes directly to the provider's UPI
/// ID, Remedoo never touches it).
///
/// Returns `true` when the user confirms they completed the payment,
/// `false`/`null` when they cancel or go back.
class OnlinePaymentScreen extends StatefulWidget {
  final double amount;
  final String recipientName;
  final String? recipientUpiId;
  final String orderId;
  final String orderLabel;

  const OnlinePaymentScreen({
    super.key,
    required this.amount,
    required this.recipientName,
    required this.recipientUpiId,
    required this.orderId,
    this.orderLabel = 'Order',
  });

  @override
  State<OnlinePaymentScreen> createState() => _OnlinePaymentScreenState();
}

class _OnlinePaymentScreenState extends State<OnlinePaymentScreen> {
  bool _upiLaunched = false;

  String get _upiLink {
    final params = {
      'pa': widget.recipientUpiId ?? '',
      'pn': widget.recipientName,
      'am': widget.amount.toStringAsFixed(2),
      'cu': 'INR',
      'tn': widget.orderId,
    };
    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }

  Future<void> _launchUpi() async {
    final uri = Uri.parse(_upiLink);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        setState(() => _upiLaunched = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not open UPI app. Please pay manually to the UPI ID shown.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not open UPI app. Please pay manually to the UPI ID shown.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasUpi =
        widget.recipientUpiId != null && widget.recipientUpiId!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment')),
      body: SafeArea(
        child: MaxWidthBox(
          maxWidth: 520,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RCard(
                  child: Column(
                    children: [
                      Text(
                        widget.orderLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inr(widget.amount),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payable to ${widget.recipientName}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${widget.orderId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!hasUpi)
                  RCard(
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_outlined,
                            color: RemedooTheme.warning),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'This provider has not set up online payments yet. Please choose another payment method.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  RCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: RemedooTheme.success
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.qr_code_2,
                                color: RemedooTheme.success,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Pay via UPI',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  scheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.recipientUpiId!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                      text: widget.recipientUpiId!));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('UPI ID copied')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        RButton(
                          label: 'Open UPI App to Pay',
                          icon: Icons.open_in_new,
                          fullWidth: true,
                          onPressed: _launchUpi,
                        ),
                        if (_upiLaunched) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Complete the payment in your UPI app, then confirm below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (hasUpi) ...[
                  RButton(
                    label: _upiLaunched
                        ? "I've Completed the Payment"
                        : 'Continue Without Paying',
                    fullWidth: true,
                    variant: _upiLaunched
                        ? RButtonVariant.primary
                        : RButtonVariant.outline,
                    onPressed: () =>
                        Navigator.pop(context, _upiLaunched),
                  ),
                  const SizedBox(height: 10),
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
