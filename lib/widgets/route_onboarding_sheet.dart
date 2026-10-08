import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../widgets/widgets.dart';

/// Razorpay Route onboarding: provider adds bank details so patient
/// payments are automatically split directly to their bank account.
/// Can be updated anytime from the provider profile.
class RouteOnboardingSheet extends StatefulWidget {
  final String providerType; // doctor, hospital, lab, pharmacy
  final String providerId;
  final String providerName;

  const RouteOnboardingSheet({
    super.key,
    required this.providerType,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<RouteOnboardingSheet> createState() => _RouteOnboardingSheetState();
}

class _RouteOnboardingSheetState extends State<RouteOnboardingSheet> {
  final _accountNumber = TextEditingController();
  final _confirmAccount = TextEditingController();
  final _ifsc = TextEditingController();
  final _beneficiaryName = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _accountNumber.dispose();
    _confirmAccount.dispose();
    _ifsc.dispose();
    _beneficiaryName.dispose();
    super.dispose();
  }

  static final _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

  Future<void> _submit() async {
    final acct = _accountNumber.text.trim();
    final confirm = _confirmAccount.text.trim();
    final ifsc = _ifsc.text.trim().toUpperCase();
    final name = _beneficiaryName.text.trim();

    if (acct.length < 9 || acct.length > 18 || !RegExp(r'^\d+$').hasMatch(acct)) {
      setState(() => _error = 'Enter a valid bank account number.');
      return;
    }
    if (acct != confirm) {
      setState(() => _error = 'Account numbers do not match.');
      return;
    }
    if (!_ifscRegex.hasMatch(ifsc)) {
      setState(() => _error = 'Enter a valid IFSC code (e.g. HDFC0001234).');
      return;
    }
    if (name.length < 3) {
      setState(() => _error = 'Enter the beneficiary name as per bank records.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = AppStateScope.of(context);
      final res = await Supabase.instance.client.functions.invoke(
        'route-create-account',
        body: {
          'provider_type': widget.providerType,
          'provider_id': widget.providerId,
          'business_name': widget.providerName,
          'beneficiary_name': name,
          'account_number': acct,
          'ifsc': ifsc,
          'email': state.email,
          'phone': state.phone,
        },
      );

      if (res.data?['success'] == true) {
        setState(() {
          _success =
              'Bank account linked! Patient payments will now go directly to your account. Complete KYC in Razorpay if prompted.';
          _busy = false;
        });
      } else {
        setState(() {
          _error = '${res.data?['error'] ?? 'Onboarding failed. Try again.'}';
          _busy = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not connect. Check internet and try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance,
                      color: Colors.green, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Direct Bank Payouts',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      Text(
                        'Patient payments go directly to your bank account',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'How it works:\n'
                '• Add your bank account below\n'
                '• Patients pay via UPI/cards in the app\n'
                '• Money is automatically split — your share goes directly to this bank account\n'
                '• You can change these details anytime',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            RTextField(
              label: 'Beneficiary Name',
              hint: 'Name as per bank records',
              controller: _beneficiaryName,
            ),
            const SizedBox(height: 12),
            RTextField(
              label: 'Bank Account Number',
              hint: 'Enter account number',
              controller: _accountNumber,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            RTextField(
              label: 'Confirm Account Number',
              hint: 'Re-enter account number',
              controller: _confirmAccount,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            RTextField(
              label: 'IFSC Code',
              hint: 'e.g. HDFC0001234',
              controller: _ifsc,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_success!,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            RButton(
              label: _busy ? 'Linking...' : 'Link Bank Account',
              fullWidth: true,
              onPressed: _busy
                  ? null
                  : () {
                      if (_success != null) {
                        Navigator.pop(context, true);
                      } else {
                        _submit();
                      }
                    },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Show the Route onboarding sheet
Future<bool?> showRouteOnboarding(
  BuildContext context, {
  required String providerType,
  required String providerId,
  required String providerName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => RouteOnboardingSheet(
      providerType: providerType,
      providerId: providerId,
      providerName: providerName,
    ),
  );
}
