import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// UPI setup popup shown after a provider's account is verified.
/// Guides them to add their UPI ID so patients can pay them directly.
/// Dismissible via the X button or tapping outside.
class UpiSetupDialog extends StatefulWidget {
  const UpiSetupDialog({super.key});

  @override
  State<UpiSetupDialog> createState() =>
      _UpiSetupDialogState();
}

class _UpiSetupDialogState
    extends State<UpiSetupDialog> {
  final _upiId = TextEditingController();
  bool _busy = false;
  String? _error;

  // Basic UPI ID format: something@bank
  static final _upiRegex =
      RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _upiId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _upiId.text.trim();
    if (!_upiRegex.hasMatch(id)) {
      setState(() => _error =
          'Enter a valid UPI ID (e.g. yourname@okhdfcbank).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AppStateScope.of(context)
        .saveProviderUpiId(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'UPI ID saved! Patients can now pay you directly.')),
      );
    } else {
      setState(() => _error =
          'Could not save. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // Icon
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: RemedooTheme.success
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      color: RemedooTheme.success,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Set up UPI Payments',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your UPI ID so patients can pay you directly. The money goes straight to your account — Remedoo never touches it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Guide steps
                _GuideStep(
                  number: '1',
                  text:
                      'Open GPay, PhonePe, or Paytm and find your UPI ID (looks like name@okhdfcbank).',
                ),
                const SizedBox(height: 10),
                _GuideStep(
                  number: '2',
                  text:
                      'Enter it below and tap Save. Patients will see a "Pay via UPI" option at checkout.',
                ),
                const SizedBox(height: 18),
                RTextField(
                  label: 'Your UPI ID',
                  hint: 'yourname@okhdfcbank',
                  controller: _upiId,
                  prefixIcon: const Icon(
                      Icons.account_balance_outlined,
                      size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(
                        Icons.content_paste,
                        size: 18),
                    tooltip: 'Paste',
                    onPressed: () async {
                      final data = await Clipboard
                          .getData('text/plain');
                      final text =
                          data?.text?.trim() ?? '';
                      if (text.isNotEmpty) {
                        setState(
                            () => _upiId.text = text);
                      }
                    },
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: RemedooTheme.emergency,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                RButton(
                  label:
                      _busy ? 'Saving…' : 'Save UPI ID',
                  fullWidth: true,
                  onPressed: _busy ? null : _save,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false),
                  child: Text(
                    'I\'ll do this later',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // X close button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, size: 22),
              tooltip: 'Close',
              onPressed: () =>
                  Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  final String number;
  final String text;

  const _GuideStep(
      {required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color:
                scheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the UPI setup dialog. Returns true if the user saved a UPI ID.
Future<bool> showUpiSetupDialog(
    BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const UpiSetupDialog(),
  );
  return result ?? false;
}
