import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_state.dart';
import '../../services/supabase_repository.dart';

/// Admin screen: verify UPI payments via UTR (SMM-panel style).
/// Shows pending UTR submissions; admin cross-checks against their
/// bank/UPI statement and approves or rejects.
class AdminUtrVerificationScreen extends StatefulWidget {
  const AdminUtrVerificationScreen({super.key});

  @override
  State<AdminUtrVerificationScreen> createState() =>
      _AdminUtrVerificationScreenState();
}

class _AdminUtrVerificationScreenState
    extends State<AdminUtrVerificationScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  final Set<String> _resolving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows =
        await SupabaseRepository.instance.fetchPendingUtrVerifications();
    if (mounted) {
      setState(() {
        _pending = rows;
        _loading = false;
      });
    }
  }

  Future<void> _resolve(String id, bool approve) async {
    String? note;
    if (!approve) {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rejection reason'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. UTR not found in statement',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      // Dialog dismissed without choosing: abort
      if (note == null && mounted) return;
    }
    setState(() => _resolving.add(id));
    final ok = await SupabaseRepository.instance
        .resolveUtrVerification(id, approve, note);
    if (mounted) {
      setState(() => _resolving.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? (approve ? 'Payment approved' : 'Payment rejected')
              : 'Failed to update. Try again.'),
        ),
      );
      if (ok) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify UPI Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined,
                          size: 64,
                          color: scheme.onSurfaceVariant
                              .withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'No pending verifications',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UTR submissions from patients will appear here.',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pending.length,
                    itemBuilder: (ctx, i) =>
                        _verificationCard(_pending[i]),
                  ),
                ),
    );
  }

  Widget _verificationCard(Map<String, dynamic> v) {
    final scheme = Theme.of(context).colorScheme;
    final id = v['id'] as String;
    final busy = _resolving.contains(id);
    final created = DateTime.tryParse(v['created_at'] ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange),
                  ),
                ),
                const Spacer(),
                if (created != null)
                  Text(
                    '${created.day}/${created.month} ${created.hour}:${created.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // UTR - prominent with copy button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UTR',
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '${v['utr'] ?? '-'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy UTR',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: '${v['utr']}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('UTR copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('Amount', '₹${v['amount'] ?? '-'}', true),
            _infoRow(
                'Patient', '${v['patient_name'] ?? '-'}', false),
            _infoRow(
                'Provider', '${v['provider_name'] ?? '-'}', false),
            _infoRow('Provider UPI',
                '${v['provider_upi_id'] ?? '-'}', false),
            _infoRow('Appointment',
                '${v['appointment_id'] ?? '-'}', false),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close,
                        size: 18, color: Colors.red),
                    label: const Text('Reject',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed:
                        busy ? null : () => _resolve(id, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.check, size: 18),
                    label: Text(busy ? 'Working...' : 'Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed:
                        busy ? null : () => _resolve(id, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool highlight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    highlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
