import 'dart:convert';

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../utils/file_download.dart';
import '../../widgets/widgets.dart';

/// One exportable dataset (friendly label -> table).
const kExportDatasets = <(String, String, IconData)>[
  ('Doctors', 'doctors', Icons.person_search),
  ('Hospitals', 'hospitals', Icons.local_hospital),
  ('Labs', 'labs', Icons.science),
  ('Lab Tests', 'lab_tests', Icons.biotech),
  ('Pharmacies', 'pharmacies', Icons.storefront),
  ('Medicines', 'medicines', Icons.medication),
  ('Appointments', 'appointments', Icons.calendar_month),
  ('Orders', 'orders', Icons.shopping_bag),
  ('Order Items', 'order_items', Icons.receipt_long),
  ('Users', 'profiles', Icons.people),
  ('User Roles', 'user_roles', Icons.badge),
  ('Payments (Remedoo Pay)', 'remedoo_pay_sessions', Icons.qr_code_2),
  ('Support Tickets', 'support_tickets', Icons.support_agent),
  ('Reviews', 'reviews', Icons.star),
  ('Announcements', 'announcements', Icons.campaign),
  ('Provider Applications', 'provider_applications', Icons.approval),
  ('Refunds', 'refunds', Icons.replay),
  ('Emergency Requests', 'emergency_requests', Icons.sos),
  ('Notifications', 'notifications', Icons.notifications),
  // Added in the audit-76 programme: finance and operations
  // datasets the export screen used to omit.
  ('Payout Requests', 'payout_requests', Icons.payments),
  ('Provider Wallets', 'provider_wallets', Icons.account_balance_wallet),
  ('Provider Earnings', 'provider_earnings', Icons.trending_up),
  ('Coupons', 'coupons', Icons.local_offer),
  ('FAQs', 'faqs', Icons.help_outline),
  ('Lab Samples', 'lab_sample_collections', Icons.science_outlined),
  ('Deliveries', 'delivery_orders', Icons.delivery_dining),
  ('Subscription Plans', 'subscription_plans', Icons.workspace_premium),
];

String _csvCell(dynamic v) {
  if (v == null) return '';
  final s = v is Map || v is List ? jsonEncode(v) : '$v';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _toCsv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final cols = <String>[];
  for (final r in rows) {
    for (final k in r.keys) {
      if (!cols.contains(k)) cols.add(k);
    }
  }
  final buf = StringBuffer()..writeln(cols.map(_csvCell).join(','));
  for (final r in rows) {
    buf.writeln(cols.map((c) => _csvCell(r[c])).join(','));
  }
  return buf.toString();
}

/// Admin > Export Data: download the project's data as CSV files, or
/// one full JSON backup. Exports run under the signed-in account's
/// own access level — staff only receive data for their sections.
class AdminExportScreen extends StatefulWidget {
  const AdminExportScreen({super.key});

  @override
  State<AdminExportScreen> createState() => _AdminExportScreenState();
}

class _AdminExportScreenState extends State<AdminExportScreen> {
  final Set<String> _busy = {};
  bool _backupBusy = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportCsv(String label, String table) async {
    final state = AppStateScope.of(context);
    setState(() => _busy.add(table));
    try {
      final rows = await state.supabaseRepository.exportTable(table);
      if (rows.isEmpty) {
        _snack('$label: no data to export.');
        return;
      }
      downloadTextFile('$table.csv', _toCsv(rows));
      _snack('$label exported — ${rows.length} rows.');
    } catch (e) {
      _snack('$label: export failed (no access or offline).');
    } finally {
      if (mounted) setState(() => _busy.remove(table));
    }
  }

  Future<void> _exportBackup() async {
    final state = AppStateScope.of(context);
    setState(() => _backupBusy = true);
    try {
      final tables = <String, dynamic>{};
      var total = 0;
      for (final d in kExportDatasets) {
        try {
          final rows = await state.supabaseRepository.exportTable(d.$2);
          tables[d.$2] = rows;
          total += rows.length;
        } catch (_) {
          tables[d.$2] = [];
        }
      }
      final payload = {
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'tables': tables,
      };
      downloadTextFile(
        'remedoo-backup.json',
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      _snack('Full backup downloaded — $total rows in all.');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const RSectionHeader(
          title: 'Export Data',
          subtitle: 'Download the project\'s data as files',
        ),
        const SizedBox(height: 12),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.backup_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Full project backup',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'One JSON file with every table below — keep it safe as your backup.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              RButton(
                label: _backupBusy
                    ? 'Preparing backup…'
                    : 'Download full backup (JSON)',
                fullWidth: true,
                onPressed: _backupBusy ? null : _exportBackup,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Or export one dataset at a time (CSV — opens in Excel):',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...kExportDatasets.map((d) {
          final busy = _busy.contains(d.$2);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(d.$3, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  RButton(
                    label: busy ? 'Working…' : 'CSV',
                    small: true,
                    onPressed: busy ? null : () => _exportCsv(d.$1, d.$2),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Text(
          'Exports follow your account\'s access: staff accounts only receive data from the sections assigned to them.',
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
