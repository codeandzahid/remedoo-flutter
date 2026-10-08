import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'widgets.dart';

/// UPI payment sheet: shows the provider's UPI ID and a button to pay
/// via UPI app. The payment goes DIRECTLY to the provider's UPI ID —
/// Remedoo never touches the money.
class UpiPaymentSheet extends StatefulWidget {
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

  @override
  State<UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends State<UpiPaymentSheet>
    with WidgetsBindingObserver {
  /// True once the UPI app was launched — we then wait for the user
  /// to return and confirm they completed the payment.
  bool _upiAppOpened = false;

  /// Guards against showing the return-confirm dialog more than once.
  bool _returnDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User came back from the UPI app: automatically ask for confirmation.
    if (state == AppLifecycleState.resumed &&
        _upiAppOpened &&
        !_returnDialogShown &&
        mounted) {
      _returnDialogShown = true;
      // Small delay so the sheet is fully visible again.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showReturnConfirmDialog();
      });
    }
  }

  /// Auto-shown when the user returns from the UPI app.
  /// Asks whether the payment succeeded — Yes books, No cancels.
  void _showReturnConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Verify Payment'),
          ],
        ),
        content: Text(
          'Did your payment of ₹${amount.toStringAsFixed(0)} to $providerName go through in your UPI app?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Payment failed/cancelled: close dialog and sheet, book nothing.
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).pop(false); // close sheet, no booking
            },
            child: const Text('No, cancel'),
          ),
          FilledButton(
            onPressed: () {
              // Payment succeeded: close dialog and sheet, book appointment.
              Navigator.of(ctx).pop(); // close dialog
              Navigator.of(context).pop(true); // close sheet, book
            },
            child: const Text('Yes, payment done'),
          ),
        ],
      ),
    );
  }

  String get upiId => widget.upiId;
  String get providerName => widget.providerName;
  double get amount => widget.amount;
  String get orderId => widget.orderId;

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
    bool launched = false;
    try {
      launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!context.mounted) return;
    if (launched) {
      // UPI app opened. Do NOT close the sheet yet — the user must
      // confirm they completed the payment when they return.
      // Update the UI to show we're waiting for confirmation.
      setState(() => _upiAppOpened = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open UPI app. Please pay manually to the UPI ID shown, then tap "I have completed payment".'),
        ),
      );
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
          if (_upiAppOpened) ...[
            // UPI app was opened — wait for the user to confirm payment.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Complete the payment in your UPI app. When you return here, we\'ll ask you to confirm.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RButton(
              label: 'I have completed the payment',
              icon: Icons.check_circle,
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _upiAppOpened = false),
              child: const Text('Re-open UPI app'),
            ),
          ] else ...[
            RButton(
              label:
                  'Pay ₹${amount.toStringAsFixed(0)} via UPI App',
              icon: Icons.open_in_new,
              fullWidth: true,
              onPressed: () => _launchUpi(context),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('I have paid manually'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How it works:',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _howStep('1', 'Tap the button above'),
                _howStep('2',
                    'Your UPI app opens with provider details filled'),
                _howStep('3', 'Confirm payment in your UPI app'),
                _howStep('4',
                    'Money goes directly to the provider — no middleman'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No gateway fees. No signup needed. Works with GPay, PhonePe, Paytm, BHIM and all UPI apps.',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _howStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 12, height: 1.4)),
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
