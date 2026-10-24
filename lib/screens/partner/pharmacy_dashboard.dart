import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_repository.dart';
import '../../state/app_state.dart';
import '../../utils/nav_memory.dart';
import '../../utils/provider_team.dart';
import '../../theme.dart';
import '../../widgets/provider_payments.dart';
import '../../widgets/provider_team_screen.dart';
import '../../widgets/provider_profile_form.dart';
import '../../widgets/pharmacy_medicines_manager.dart';
import '../../widgets/provider_wallet_card.dart';
import '../../widgets/upi_setup_dialog.dart';
import '../../widgets/widgets.dart';

/// Dashboard for logged-in pharmacies.
/// Shows orders to fulfill with plain-language actions:
/// confirm the order, mark it ready, send it out, mark it delivered.
class PharmacyDashboard extends StatefulWidget {
  const PharmacyDashboard({super.key});

  @override
  State<PharmacyDashboard> createState() => _PharmacyDashboardState();
}

class _PharmacyDashboardState extends State<PharmacyDashboard> {
  int _tab = 0;
  bool _loading = true;
  bool _upiPromptShown = false;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, Map<String, dynamic>> _deliveries = {};
  // Provider team (2026-10-24): owner sees all tabs + Team;
  // members see only their allowed tabs.
  bool _isOwner = true;
  Map<String, String> _teamAccess = fullTeamAccess('pharmacy');
  String? _teamProviderId;

  SupabaseRepository get _repo =>
      AppStateScope.of(context).supabaseRepository;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Refresh restore + tabs (owner order 2026-10-23): this panel
    // now uses the same tab layout as the doctor panel — work
    // first, then profile, payments, reviews — instead of one
    // long scroll with the profile form on top.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await NavMemory.read(NavMemory.pharmacyTab);
      if (!mounted || saved == null) return;
      if (saved > 0 && saved < 6 && saved != _tab) {
        setState(() => _tab = saved);
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.fetchOwnProviderRecord('pharmacies');
      final orders = await _repo.fetchPharmacyOrders();
      final deliveries = await _repo.fetchDeliveriesForOrders(
          [for (final o in orders) '${o['id']}']);
      final reviews =
          await _repo.fetchProviderReviews('pharmacy', 'pharmacies');
      final teamCtx = await _repo.fetchOwnTeamContext('pharmacies');
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _orders = orders;
        _deliveries = deliveries;
        _reviews = reviews;
        _isOwner = teamCtx.isOwner;
        _teamAccess = teamCtx.access;
        _teamProviderId = teamCtx.providerId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your data. Pull down to try again.';
        _loading = false;
      });
    }
 
    if (mounted && !_upiPromptShown) {
      _upiPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybePromptUpiSetup(context, _profile);
      });
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'Leave the partner app?',
      confirmLabel: 'Log Out',
    );
    if (!ok) return;
    if (!mounted) return;
    final state = AppStateScope.of(context);
    state.switchRole('patient');
    state.logout();
  }

  Future<void> _setStatus(Map<String, dynamic> o, String status) async {
    // Cancelling an order asks first (audit Panelist 17).
    if (status == 'cancelled') {
      final confirmed = await confirmDialog(
        context,
        title: 'Cancel this order?',
        message:
            'The patient will be told the order was cancelled. Any online payment they made will need a refund.',
        confirmLabel: 'Cancel order',
      );
      if (!confirmed || !mounted) return;
    }
    final ok = await _repo.updateOrderStatus('${o['id']}', status);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _orders.indexWhere((x) => '${x['id']}' == '${o['id']}');
        if (i >= 0) _orders[i] = {..._orders[i], 'status': status};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order marked as ${_label(status)}.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  /// Panelist refund for a cancelled paid-online order (owner
  /// order 2026-10-19): opens the shared refund dialog (UPI deep
  /// link + mandatory refund UTR) and marks the order refunded.
  Future<void> _verifyPrescription(Map<String, dynamic> o) async {
    final ok = await _repo.setOrderPrescriptionVerified('${o['id']}');
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _orders.indexWhere((x) => '${x['id']}' == '${o['id']}');
        if (i >= 0) {
          _orders[i] = {
            ..._orders[i],
            'prescription_verified_at':
                DateTime.now().toUtc().toIso8601String(),
          };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription marked verified.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not verify. Try again.')),
      );
    }
  }

  /// Assign-driver sheet (full-check fix 2026-10-22): lists the
  /// active drivers and creates/updates the delivery row the driver
  /// panel reads. Before this, nothing in the app could create a
  /// delivery at all.
  Future<void> _assignDriver(Map<String, dynamic> o) async {
    final drivers = await _repo.fetchAvailableDrivers();
    if (!mounted) return;
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No drivers are available right now. Please try again later.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose a driver',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            for (final d in drivers)
              ListTile(
                leading: const Icon(Icons.delivery_dining),
                title: Text('${d['name'] ?? 'Driver'}'),
                subtitle: Text(
                    '${d['vehicle_type'] ?? 'bike'}${d['vehicle_number'] != null ? ' • ${d['vehicle_number']}' : ''} • ${d['status'] ?? ''}'),
                onTap: () => Navigator.pop(ctx, d),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await _repo.assignOrderToDriver(
      orderId: '${o['id']}',
      driverId: '${picked['id']}',
      deliveryAddress: '${o['delivery_address'] ?? ''}',
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Driver ${picked['name'] ?? ''} assigned to this order.')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not assign the driver. Try again.')),
      );
    }
  }

  Future<void> _refundOrder(Map<String, dynamic> o) async {
    final amount = (o['refund_amount'] as num?)?.toDouble() ??
        (o['total'] as num?)?.toDouble() ??
        0;
    final ref = '${o['payment_ref'] ?? ''}'.trim();
    final utr = await showRefundDialog(
      context,
      amount: amount,
      customerUpi: '${o['customer_upi'] ?? ''}'.trim().isEmpty
          ? null
          : '${o['customer_upi']}',
      customerName: '',
      ref: ref.isNotEmpty ? ref : '${o['id'] ?? ''}',
    );
    if (utr == null || !mounted) return;
    final ok = await _repo.updateOrderRefund(
      id: '${o['id']}',
      refundStatus: 'refunded',
      refundUtr: utr,
    );
    if (ref.isNotEmpty) {
      await _repo.updateSessionRefundByRef(ref, 'refunded',
          refundUtr: utr);
    }
    if (!mounted) return;
    if (ok) {
      setState(() {
        final i = _orders.indexWhere((x) => '${x['id']}' == '${o['id']}');
        if (i >= 0) {
          _orders[i] = {
            ..._orders[i],
            'refund_status': 'refunded',
            'refund_utr': utr,
          };
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund marked as done.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  /// Plain-language label for each order status.
  String _label(String status) {
    switch (status) {
      case 'placed':
        return 'New order';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'confirmed':
      case 'preparing':
        return RemedooTheme.teal;
      case 'out_for_delivery':
        return scheme.primary;
      case 'delivered':
        return RemedooTheme.success;
      case 'cancelled':
        return scheme.error;
      default:
        return RemedooTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Team tabs (2026-10-24): members see only allowed tabs,
    // owners also get the Team tab.
    final tabState = partnerTabs(
      entries: [
        (
          'orders',
          _workTab(context),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Orders',
          ),
        ),
        (
          'medicines',
          _medicinesTab(context),
          const BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Medicines',
          ),
        ),
        (
          'profile',
          _profileTab(context),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ),
        (
          'payments',
          _paymentsTab(context),
          const BottomNavigationBarItem(
            icon: Icon(Icons.payments),
            label: 'Payments',
          ),
        ),
        (
          'reviews',
          _reviewsTab(context),
          const BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Reviews',
          ),
        ),
      ],
      isOwner: _isOwner,
      access: _teamAccess,
      currentIndex: _tab,
      providerType: 'pharmacy',
      providerId: _teamProviderId,
      repo: _repo,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const RLoading()
          : _error != null
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      REmptyState(
                        icon: Icons.cloud_off,
                        title: 'Something went wrong',
                        subtitle: _error!,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (tabState.viewOnly) viewOnlyBanner(),
                    Expanded(
                      child: IndexedStack(
                        index: tabState.index,
                        children: [
                          for (final t in tabState.tabs) t.$2,
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabState.index,
        onTap: (i) {
          setState(() => _tab = i);
          NavMemory.save(NavMemory.pharmacyTab, i);
        },
        type: BottomNavigationBarType.fixed,
        items: [for (final t in tabState.tabs) t.$3],
      ),
    );
  }

  // Orders tab: welcome, stats, orders to fulfill and history.
  Widget _workTab(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _orders
        .where((o) =>
            '${o['status']}' != 'delivered' &&
            '${o['status']}' != 'cancelled')
        .toList();
    final done = _orders
        .where((o) =>
            '${o['status']}' == 'delivered' ||
            '${o['status']}' == 'cancelled')
        .toList();
    final newCount =
        _orders.where((o) => '${o['status']}' == 'placed').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: RemedooTheme.warning
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.storefront,
                    color: RemedooTheme.warning, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_profile?['name'] ?? 'Pharmacy'}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${_profile?['location'] ?? ''}',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                'New orders',
                '$newCount',
                'Need your confirmation',
                Icons.fiber_new,
                RemedooTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                'In progress',
                '${active.length}',
                'Being prepared or delivered',
                Icons.pending_actions,
                scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                context,
                'Completed',
                '${done.length}',
                'Delivered or cancelled',
                Icons.check_circle,
                RemedooTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const RSectionHeader(
          title: 'Orders to Fulfill',
          subtitle:
              'Confirm new orders, then move them step by step to delivered',
        ),
        const SizedBox(height: 12),
        if (active.isEmpty)
          const REmptyState(
            icon: Icons.check_circle,
            title: 'All caught up!',
            subtitle: 'New medicine orders from customers will appear here.',
            compact: true,
          )
        else
          ...active.map((o) => _orderCard(context, o)),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 24),
          const RSectionHeader(
            title: 'Recent History',
            subtitle: 'Finished orders',
          ),
          const SizedBox(height: 12),
          ...done.take(10).map((o) => _orderCard(context, o)),
        ],
        const SizedBox(height: 24),
      ],
    ),
    );
  }

  // Medicines tab: stock and catalogue.
  Widget _medicinesTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        PharmacyMedicinesManager(repo: _repo),
        ],
      ),
    );
  }

  // Profile tab: the provider profile form and setup.
  Widget _profileTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        ProviderProfileForm(
          table: 'pharmacies',
          profile: _profile,
          repo: _repo,
          onSaved: _load,
        ),
        const SizedBox(height: 16),
        RouteOnboardingTile(
          providerType: 'pharmacy',
          providerId: '${_profile?['id'] ?? ''}',
          providerName: '${_profile?['name'] ?? ''}',
        ),
        ],
      ),
    );
  }

  // Payments tab: UPI settings, online payments and wallet.
  Widget _paymentsTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        ProviderUpiSettingsCard(
          table: 'pharmacies',
          profile: _profile,
          repo: _repo,
          onSaved: _load,
        ),
        const SizedBox(height: 16),
        ProviderOnlinePayments(repo: _repo),
        const SizedBox(height: 16),
        ProviderWalletCard(
          repo: _repo,
          providerType: 'pharmacy',
          providerId: '${_profile?['id'] ?? ''}',
        ),
        ],
      ),
    );
  }

  // Reviews tab: what patients said.
  Widget _reviewsTab(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
        ProviderReviewsList(reviews: _reviews),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      String hint, IconData icon, Color color) {
    return RCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, Map<String, dynamic> o) {
    final scheme = Theme.of(context).colorScheme;
    final status = '${o['status'] ?? 'placed'}';
    final color = _statusColor(context, status);
    final items = (o['order_items'] as List?) ?? [];
    final shortId = '${o['id'] ?? ''}';
    final displayId =
        shortId.length > 8 ? shortId.substring(0, 8).toUpperCase() : shortId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #$displayId',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _label(status).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (items.isNotEmpty)
              ...items.take(4).map((it) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• ${it['medicines']?['name'] ?? 'Medicine'} × ${it['quantity'] ?? 1}',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant),
                    ),
                  )),
            if (items.length > 4)
              Text('+ ${items.length - 4} more items',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Total: ${inr((o['total'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Text(
                  '${o['payment_method'] ?? 'cod'}'.toUpperCase(),
                  style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if ('${o['delivery_address'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Deliver to: ${o['delivery_address']}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant),
                ),
              ),
            // The patient's checkout note rides along in the row
            // (fetchPharmacyOrders selects *) — surface it like the
            // other partner dashboards surface appointment notes
            // (sweep fix 2026-10-20).
            if ('${o['notes'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Note: ${o['notes']}',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant),
                ),
              ),
            // The uploaded prescription (audit M3): the pharmacy
            // can open the actual file and record verification
            // (orders.prescription_verified_by/_at) instead of
            // fulfilling an Rx order blind.
            if ('${o['prescription_url'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RButton(
                      label: 'View prescription',
                      icon: Icons.description_outlined,
                      small: true,
                      variant: RButtonVariant.outline,
                      onPressed: () => launchUrl(
                        Uri.parse('${o['prescription_url']}'),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if ('${o['prescription_verified_at'] ?? ''}'.isEmpty)
                    Expanded(
                      child: RButton(
                        label: 'Verify prescription',
                        icon: Icons.verified_outlined,
                        small: true,
                        onPressed: () => _verifyPrescription(o),
                      ),
                    )
                  else
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 16, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Prescription verified',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ],
            // Step-by-step action buttons
            if (status == 'placed') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: RButton(
                      label: 'Confirm order',
                      small: true,
                      onPressed: () =>
                          _setStatus(o, 'confirmed'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RButton(
                      label: 'Cancel',
                      small: true,
                      variant: RButtonVariant.danger,
                      onPressed: () =>
                          _setStatus(o, 'cancelled'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'confirmed') ...[
              // The preparing step (audit Panelist 16: the status
              // existed with a label and colour but NO button ever
              // set it, so the documented flow skipped it).
              const SizedBox(height: 12),
              RButton(
                label: 'Start preparing',
                small: true,
                onPressed: () => _setStatus(o, 'preparing'),
              ),
            ] else if (status == 'preparing') ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Mark ready — out for delivery',
                small: true,
                onPressed: () =>
                    _setStatus(o, 'out_for_delivery'),
              ),
            ] else if (status == 'out_for_delivery') ...[
              const SizedBox(height: 12),
              RButton(
                label: 'Mark as delivered',
                small: true,
                onPressed: () =>
                    _setStatus(o, 'delivered'),
              ),
            ],
            // Driver assignment (full-check fix 2026-10-22: the
            // driver panel could never receive a delivery because
            // nothing created delivery rows — this is that missing
            // action). Available once the order is confirmed;
            // re-assignment stays possible until delivered.
            if (status == 'confirmed' ||
                status == 'preparing' ||
                status == 'out_for_delivery') ...[
              const SizedBox(height: 10),
              if (_deliveries['${o['id']}'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.delivery_dining,
                          size: 16, color: RemedooTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Driver: ${_deliveries['${o['id']}']!['driver_name'] ?? 'Assigned'} • ${_deliveryStatusLabel('${_deliveries['${o['id']}']!['status'] ?? ''}')}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              RButton(
                label: _deliveries['${o['id']}'] == null
                    ? 'Assign driver'
                    : 'Change driver',
                icon: Icons.delivery_dining,
                small: true,
                variant: RButtonVariant.outline,
                onPressed: () => _assignDriver(o),
              ),
            ],
            // Cancelled paid-online order with a refund owed: the
            // customer cancelled, the pharmacy refunds from here.
            if (status == 'cancelled' &&
                '${o['payment_method'] ?? ''}' == 'online' &&
                '${o['refund_status'] ?? ''}' == 'requested') ...[
              const SizedBox(height: 10),
              Text(
                'Refund requested by customer — payment already made.',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.error),
              ),
              const SizedBox(height: 8),
              RButton(
                label:
                    'Refund ${inr((o['refund_amount'] as num?)?.toDouble() ?? (o['total'] as num?)?.toDouble() ?? 0)}',
                icon: Icons.currency_rupee,
                small: true,
                variant: RButtonVariant.danger,
                onPressed: () => _refundOrder(o),
              ),
            ],
            if ('${o['refund_status'] ?? ''}' == 'refunded')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Refunded'
                  '${('${o['refund_utr'] ?? ''}'.trim().isNotEmpty) ? ' · UTR ${o['refund_utr']}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: RemedooTheme.success),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Human label for a delivery_orders status (pharmacy chip).
String _deliveryStatusLabel(String status) {
  switch (status) {
    case 'assigned':
      return 'Assigned';
    case 'picked_up':
      return 'Picked up';
    case 'in_transit':
      return 'On the way';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Pending';
  }
}
