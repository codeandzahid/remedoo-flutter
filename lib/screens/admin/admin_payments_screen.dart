import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/route_onboarding_sheet.dart';
import '../../widgets/widgets.dart';

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}

/// Admin control for provider payment settings:
/// UPI ID, UPI payments toggle, Pay-in-clinic toggle
/// (columns upi_id / upi_enabled / pay_in_clinic_enabled).
class AdminProviderPaymentsScreen extends StatelessWidget {
  const AdminProviderPaymentsScreen({super.key});

  static const _tables = [
    'doctors',
    'hospitals',
    'labs',
    'pharmacies'
  ];
  static const _labels = [
    'Doctors',
    'Hospitals',
    'Labs',
    'Pharmacies'
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tables.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final l in _labels) Tab(text: l),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final t in _tables)
                  _ProviderPaymentsTab(table: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderPaymentsTab extends StatefulWidget {
  final String table;
  const _ProviderPaymentsTab({required this.table});

  @override
  State<_ProviderPaymentsTab> createState() =>
      _ProviderPaymentsTabState();
}

class _ProviderPaymentsTabState
    extends State<_ProviderPaymentsTab> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await AppStateScope.of(context)
        .loadAdminTable(widget.table);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final rows = state.adminTable(widget.table);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }
    if (rows.isEmpty) {
      return const REmptyState(
        icon: Icons.payments_outlined,
        title: 'No providers',
        subtitle: 'Providers will appear here once added.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        itemBuilder: (_, i) =>
            _card(context, state, rows[i]),
      ),
    );
  }

  Widget _card(BuildContext context, AppState state,
      Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final id = '${r['id']}';
    final upiId = (r['upi_id'] as String?)?.trim() ?? '';
    final upiEnabled = r['upi_enabled'] != false;
    final payInClinic = r['pay_in_clinic_enabled'] != false;
    final routeAccountId =
        (r['razorpay_account_id'] as String?)?.trim() ?? '';
    final routeStatus =
        (r['route_onboarding_status'] as String?)?.trim() ??
            'not_started';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                    name: '${r['name'] ?? '?'}', radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${r['name'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                if (upiId.isEmpty)
                  StatusChip(status: 'no UPI')
                else
                  StatusChip(status: 'UPI set'),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () =>
                  _editUpi(context, state, id, upiId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.qr_code,
                        size: 18,
                        color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          upiId.isEmpty
                              ? 'Not set — tap to add'
                              : upiId,
                          style: TextStyle(
                              fontSize: 14,
                              color: upiId.isEmpty
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface)),
                    ),
                    Icon(Icons.edit,
                        size: 16,
                        color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            _toggleRow(
              context,
              label: 'UPI payments',
              value: upiEnabled,
              onChanged: (v) async {
                final ok = await state.updateProviderPayment(
                    widget.table, id,
                    upiEnabled: v);
                if (context.mounted && !ok) {
                  _snack(context, 'Update failed. Try again.');
                }
              },
            ),
            _toggleRow(
              context,
              label: 'Pay in clinic',
              value: payInClinic,
              onChanged: (v) async {
                final ok = await state.updateProviderPayment(
                    widget.table, id,
                    payInClinicEnabled: v);
                if (context.mounted && !ok) {
                  _snack(context, 'Update failed. Try again.');
                }
              },
            ),
            const Divider(height: 16),
            // Razorpay Route status
            Row(
              children: [
                Icon(Icons.account_balance,
                    size: 18,
                    color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Razorpay Route (direct payouts)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                StatusChip(
                  status: routeAccountId.isEmpty
                      ? 'not onboarded'
                      : routeStatus == 'created'
                          ? 'active'
                          : routeStatus,
                ),
              ],
            ),
            if (routeAccountId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Account: $routeAccountId',
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                    fontFamily: 'monospace'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              RButton(
                label: 'Onboard to Route',
                icon: Icons.account_balance,
                small: true,
                variant: RButtonVariant.outline,
                onPressed: () => _onboardRoute(context, state, id,
                    '${r['name'] ?? 'Provider'}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Admin triggers Route onboarding for a provider.
  /// Opens the bank details sheet pre-filled for this provider.
  Future<void> _onboardRoute(BuildContext context, AppState state,
      String providerId, String providerName) async {
    final providerType = widget.table.replaceAll('s', ''); // doctors->doctor
    final done = await showRouteOnboarding(
      context,
      providerType: providerType,
      providerId: providerId,
      providerName: providerName,
    );
    if (done == true && context.mounted) {
      _snack(context, 'Route onboarding started for $providerName');
      _load();
    }
  }

  Widget _toggleRow(BuildContext context,
      {required String label,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Switch(
          value: value,
          activeThumbColor: RemedooTheme.success,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _editUpi(BuildContext context, AppState state,
      String id, String current) async {
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Provider UPI ID',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
        content: RTextField(
          controller: ctrl,
          hint: 'e.g. clinic@upi',
          label: 'UPI ID',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          RButton(
            label: 'Save',
            small: true,
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty || !v.contains('@')) {
                _snack(context,
                    'Enter a valid UPI ID (name@bank).');
                return;
              }
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final saved = await state.updateProviderPayment(
        widget.table, id,
        upiId: ctrl.text.trim());
    if (context.mounted) {
      _snack(context,
          saved ? 'UPI ID saved.' : 'Save failed. Try again.');
    }
  }
}
