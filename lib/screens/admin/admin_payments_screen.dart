import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/route_onboarding_sheet.dart';
import '../../widgets/widgets.dart';
import '../../widgets/form_kit.dart';
import '../../widgets/provider_payments.dart';

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
    final state = AppStateScope.of(context);
    await state.loadAdminTable(widget.table);
    if (state.allProfiles.isEmpty) {
      await state.loadAllProfiles();
    }
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
                // Money control (full-check fix 2026-10-22):
                // changing where patient money goes needs the
                // admin's email code first, like every other
                // payment change in the app.
                final verified = await requireEmailOtp(context,
                    title: 'Confirm with email code',
                    message:
                        'Enter the 6-digit code sent to your email to change this payment setting.');
                if (!verified || !context.mounted) return;
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
                final verified = await requireEmailOtp(context,
                    title: 'Confirm with email code',
                    message:
                        'Enter the 6-digit code sent to your email to change this payment setting.');
                if (!verified || !context.mounted) return;
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
                onPressed: () => _onboardRoute(context, state, r),
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
      Map<String, dynamic> r) async {
    // Full-check fix 2026-10-22: replaceAll('s', '') turned
    // 'pharmacies' into 'pharmacie', which the Edge Function's
    // table map does not know — the account was created at
    // Razorpay but never written back to the provider's record.
    const typeByTable = {
      'doctors': 'doctor',
      'hospitals': 'hospital',
      'labs': 'lab',
      'pharmacies': 'pharmacy',
    };
    final providerType = typeByTable[widget.table] ?? 'doctor';
    final providerId = '${r['id']}';
    final providerName = '${r['name'] ?? 'Provider'}';
    // The provider's OWN contact (profile email via user_id,
    // phone from the provider record) — never the admin's.
    var contactEmail = '';
    final userId = '${r['user_id'] ?? ''}';
    if (userId.isNotEmpty) {
      for (final p in state.allProfiles) {
        if ('${p['user_id']}' == userId) {
          contactEmail = '${p['email'] ?? ''}';
          break;
        }
      }
    }
    final done = await showRouteOnboarding(
      context,
      providerType: providerType,
      providerId: providerId,
      providerName: providerName,
      contactEmail: contactEmail,
      contactPhone: '${r['phone'] ?? ''}',
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
        content: RKitField(
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
    // Money control (full-check fix 2026-10-22): the admin's email
    // code is required before a provider's receiving UPI changes.
    final verified = await requireEmailOtp(context,
        title: 'Confirm with email code',
        message:
            'Enter the 6-digit code sent to your email to change this provider\'s UPI ID.');
    if (!verified || !context.mounted) return;
    final saved = await state.updateProviderPayment(
        widget.table, id,
        upiId: ctrl.text.trim());
    if (context.mounted) {
      _snack(context,
          saved ? 'UPI ID saved.' : 'Save failed. Try again.');
    }
  }
}
