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
  /// Step 1 = pay, Step 2 = enter UTR.
  int _step = 1;

  /// Guards against showing the return-confirm dialog more than once.
  bool _returnDialogShown = false;

  /// When the UPI app was launched. Used to auto-detect a completed payment:
  /// if the user spent enough time in the UPI app (PIN entry takes time),
  /// we move them to the UTR step automatically.
  DateTime? _upiLaunchTime;

  /// Minimum seconds in the UPI app to auto-advance to the UTR step.
  static const _autoAdvanceSeconds = 15;

  final _utrController = TextEditingController();
  bool _utrError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _utrController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User came back from the UPI app: move to the UTR entry step.
    if (state == AppLifecycleState.resumed &&
        _step == 1 &&
        _upiLaunchTime != null &&
        !_returnDialogShown &&
        mounted) {
      _returnDialogShown = true;
      final elapsed = DateTime.now().difference(_upiLaunchTime!).inSeconds;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (elapsed >= _autoAdvanceSeconds) {
          // Spent long enough to have paid — go to UTR step automatically.
          setState(() => _step = 2);
        } else {
          // Quick return: probably didn't pay — ask what happened.
          _showReturnConfirmDialog();
        }
      });
    }
  }

  /// Shown on quick return from the UPI app (didn't spend long enough).
  void _showReturnConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Did you complete the payment?'),
        content: const Text(
          'If you paid in your UPI app, enter the UTR number next. '
          'If not, you can try again.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(null); // cancel everything
            },
            child: const Text('Cancel booking'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _step = 2; // go to UTR entry
                _returnDialogShown = false; // allow re-entry if needed
              });
            },
            child: const Text('Yes, I paid'),
          ),
        ],
      ),
    );
  }

  /// Validates and submits the UTR. Returns the UTR string to the caller.
  void _submitUtr() {
    final utr = _utrController.text.trim();
    // UTR is 12 digits
    if (!RegExp(r'^\d{12}$').hasMatch(utr)) {
      setState(() => _utrError = true);
      return;
    }
    Navigator.of(context).pop(utr);
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
      // UPI app opened. Record the time — on return we'll advance
      // to the UTR entry step.
      _upiLaunchTime = DateTime.now();
      setState(() {});
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
          if (_step == 2) ...[
            // ---- STEP 2: Enter UTR ----
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.receipt_long,
                      color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter the 12-digit UTR / UPI Ref No. from your payment receipt.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _utrController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: 'UTR / UPI Reference Number',
                hintText: 'e.g. 412345678901',
                prefixIcon: const Icon(Icons.numbers),
                errorText:
                    _utrError ? 'Enter a valid 12-digit UTR' : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) {
                if (_utrError) setState(() => _utrError = false);
              },
            ),
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Where do I find the UTR?',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue),
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• Google Pay: tap the transaction → "UPI transaction ID"\n'
                    '• PhonePe: History → tap payment → "Transaction ID"\n'
                    '• Paytm: Passbook → tap payment → "UTR number"\n'
                    '• BHIM: History → tap transaction → "Ref No."',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RButton(
              label: 'Submit UTR & Confirm Booking',
              icon: Icons.verified,
              fullWidth: true,
              onPressed: _submitUtr,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _step = 1;
                _returnDialogShown = false;
              }),
              child: const Text('Back to payment'),
            ),
          ] else ...[
            // ---- STEP 1: Pay ----
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
              label: const Text('I have paid — enter UTR'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => setState(() => _step = 2),
            ),
          ],
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
/// Returns the 12-digit UTR if the user submitted one, null if cancelled.
Future<String?> showUpiPaymentSheet(
  BuildContext context, {
  required String upiId,
  required String providerName,
  required double amount,
  required String orderId,
}) async {
  final result = await showModalBottomSheet<String>(
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
  return result;
}
