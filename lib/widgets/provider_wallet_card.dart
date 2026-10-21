import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import '../theme.dart';
import 'widgets.dart';

/// Provider wallet + payout surface (form-pages audit
/// Panelist 11 / M20: provider_wallets, provider_earnings and
/// payout_requests existed with provider RLS policies but no
/// panel showed a balance or offered a payout request). Shows
/// the wallet balance, recent platform earnings, and a payout
/// request form (paid out by Remedoo after admin review — this
/// is separate from Remedoo Pay UPI money, which already goes
/// straight to the provider's own account).
class ProviderWalletCard extends StatefulWidget {
  final SupabaseRepository repo;
  final String providerType; // doctor | hospital | lab | pharmacy
  final String providerId;

  const ProviderWalletCard({
    super.key,
    required this.repo,
    required this.providerType,
    required this.providerId,
  });

  @override
  State<ProviderWalletCard> createState() => _ProviderWalletCardState();
}

class _ProviderWalletCardState extends State<ProviderWalletCard> {
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _earnings = [];
  List<Map<String, dynamic>> _payouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.providerId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final wallet = await widget.repo
        .fetchProviderWallet(widget.providerType, widget.providerId);
    final earnings = await widget.repo
        .fetchProviderEarnings(widget.providerType, widget.providerId);
    final payouts = await widget.repo.fetchOwnPayoutRequests();
    if (!mounted) return;
    setState(() {
      _wallet = wallet;
      _earnings = earnings;
      _payouts = payouts
          .where((p) =>
              '${p['provider_id']}' == widget.providerId)
          .toList();
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _requestPayout() async {
    final available =
        (_wallet?['available_balance'] as num?)?.toDouble() ?? 0;
    final amount = TextEditingController(
        text: available > 0 ? available.toStringAsFixed(0) : '');
    final upi = TextEditingController();
    final name = TextEditingController();
    String? error;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Request payout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Available balance: ₹${available.toStringAsFixed(2)}. '
                  'Remedoo reviews the request and pays out to your UPI.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: upi,
                  decoration: const InputDecoration(
                    labelText: 'Your UPI ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Name on the UPI account',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(amount.text.trim());
                if (v == null || v <= 0) {
                  setD(() => error = 'Enter a valid amount.');
                  return;
                }
                if (available > 0 && v > available) {
                  setD(() =>
                      error = 'More than your available balance.');
                  return;
                }
                if (upi.text.trim().isEmpty) {
                  setD(() => error = 'Enter your UPI ID.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Request'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    final ok = await widget.repo.createPayoutRequest(
      providerType: widget.providerType,
      providerId: widget.providerId,
      amount: double.parse(amount.text.trim()),
      bankDetails: {
        'method': 'upi',
        'upi_id': upi.text.trim(),
        'payee_name': name.text.trim(),
      },
    );
    _snack(ok
        ? 'Payout requested. Remedoo will review it.'
        : 'Could not request. Try again.');
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balance =
        (_wallet?['available_balance'] as num?)?.toDouble() ?? 0;
    final earned =
        (_wallet?['total_earned'] as num?)?.toDouble() ?? 0;
    final withdrawn =
        (_wallet?['total_withdrawn'] as num?)?.toDouble() ?? 0;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RSectionHeader(
            title: 'Wallet & Payouts',
            subtitle:
                'Platform earnings balance — UPI payments from patients already go straight to your account',
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                Expanded(
                  child: _figure('Available', '₹${balance.toStringAsFixed(2)}',
                      scheme.primary),
                ),
                Expanded(
                  child: _figure('Total earned', '₹${earned.toStringAsFixed(2)}',
                      scheme.onSurface),
                ),
                Expanded(
                  child: _figure('Paid out', '₹${withdrawn.toStringAsFixed(2)}',
                      scheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 10),
            RButton(
              label: 'Request payout',
              icon: Icons.payments_outlined,
              small: true,
              variant: RButtonVariant.outline,
              onPressed: _requestPayout,
            ),
            if (_earnings.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Recent earnings',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final e in _earnings.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${e['description'] ?? e['reference_type'] ?? 'Earning'}'),
                  subtitle: Text(
                      '${'${e['created_at'] ?? ''}'.split('T').first} • '
                      'Gross ₹${e['gross_amount']} • Fee ₹${e['commission_amount']}'),
                  trailing: Text('₹${e['net_amount']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
            ],
            if (_payouts.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Payout requests',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final p in _payouts.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('₹${p['amount']}'),
                  subtitle: Text(
                      '${'${p['requested_at'] ?? ''}'.split('T').first}'
                      '${'${p['transaction_reference'] ?? ''}'.isNotEmpty ? ' • ${p['transaction_reference']}' : ''}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: RemedooTheme.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${p['status'] ?? 'pending'}',
                        style: const TextStyle(fontSize: 11.5)),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _figure(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
