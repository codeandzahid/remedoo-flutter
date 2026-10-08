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
  List<Map<String, dynamic>> _verifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await SupabaseRepository.instance
        .fetchPendingUtrVerifications();
    if (mounted) {
      setState(() {
        _verifications = rows;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment Records'),
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
          : _verifications.isEmpty
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
                        'No records found',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'UTR submissions from patients will appear here.\n'
                        'Cross-check against your bank statement.',
                        textAlign: TextAlign.center,
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
                    itemCount: _verifications.length,
                    itemBuilder: (ctx, i) =>
                        _verificationCard(_verifications[i]),
                  ),
                ),
    );
  }

  /// Extracts the UTR from appointment notes (format: "UTR:123456789012")
  String _extractUtr(String? notes) {
    if (notes == null) return '-';
    final match = RegExp(r'UTR:(\d{12})').firstMatch(notes);
    return match?.group(1) ?? '-';
  }

  /// Gets the provider name from the joined data
  String _providerName(Map<String, dynamic> v) {
    if (v['doctors'] != null) return '${v['doctors']['name']}';
    if (v['hospitals'] != null) return '${v['hospitals']['name']}';
    if (v['labs'] != null) return '${v['labs']['name']}';
    return '-';
  }

  Widget _verificationCard(Map<String, dynamic> v) {
    final scheme = Theme.of(context).colorScheme;
    final id = '${v['id']}';
    final utr = _extractUtr(v['notes'] as String?);
    // All UTR payments are auto-approved (optimistic); this screen is
    // for reconciliation against the bank statement.
    const status = 'approved';
    const statusColor = Colors.green;
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
                    color:
                        statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
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
                          utr,
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
                          ClipboardData(text: utr));
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
            _infoRow('Provider', _providerName(v), false),
            _infoRow('Date', '${v['appointment_date'] ?? '-'}', false),
            _infoRow('Appointment ID', '$id', false),
            _infoRow('Full notes', '${v['notes'] ?? '-'}', false),
            const SizedBox(height: 16),
            // Reconciliation note — all UTRs are auto-approved (SMM style).
            // Cross-check against bank statement; flag fraud if needed.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Auto-approved on submit. Cross-check this UTR in your bank/UPI statement.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
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
