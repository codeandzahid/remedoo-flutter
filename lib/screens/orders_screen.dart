import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'order_tracking_screen.dart';
import 'remedoo_pharmacy_screen.dart';
import '../app_navigator.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// My Orders — matches MyOrders.tsx: gradient header with "N total" and
/// white Active/Past pill tabs, order cards with status pills.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _tab = 'active';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Skeleton shimmer on first load; data itself is local.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  String _fmtDate(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, $h12:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    if (!state.isSignedIn) {
      return const GuestGate();
    }
    final active = state.activeOrders;
    final past = state.pastOrders;
    final display = _tab == 'active' ? active : past;
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    _HeaderBack(
                        onTap: () =>
                            goBack(context)),
                    const SizedBox(width: 12),
                    const Text('My Orders',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${state.orders.length} total',
                        style: TextStyle(
                            color: Colors.white
                                .withValues(alpha: 0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _pillTab('Active (${active.length})',
                        _tab == 'active', () {
                      setState(() => _tab = 'active');
                    }),
                    const SizedBox(width: 8),
                    _pillTab('Past (${past.length})',
                        _tab == 'past', () {
                      setState(() => _tab = 'past');
                    }),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: MaxWidthBox(child: _list(display)),
          ),
        ],
      ),
    );
  }

  Widget _pillTab(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected
          ? Colors.white
          : Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 9),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? RemedooTheme.primary
                      : Colors.white)),
        ),
      ),
    );
  }

  Widget _list(List<MedOrder> list) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: 4,
        itemBuilder: (_, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: SkeletonCard(),
        ),
      );
    }
    if (list.isEmpty) {
      return REmptyState(
        icon: Icons.shopping_bag_outlined,
        title: _tab == 'active'
            ? 'No active orders'
            : 'No past orders',
        subtitle: _tab == 'active'
            ? 'Your active orders will appear here'
            : 'Your completed orders will show here',
        actionLabel: 'Browse Pharmacies',
        onAction: () =>
            pushPage(context, const RemedooPharmacyScreen()),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(
            const Duration(milliseconds: 500));
        if (mounted) AppStateScope.of(context).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: list.length,
        itemBuilder: (_, i) =>
            StaggerItem(index: i % 6, child: _card(list[i])),
      ),
    );
  }

  Widget _card(MedOrder o) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: EdgeInsets.zero,
      onTap: () => pushPage(context, OrderTrackingScreen(order: o)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('💊',
                    style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(o.pharmacyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '#${o.id} • ${_fmtDate(o.placedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  StatusChip(status: o.status),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(inr(o.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBack extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderBack({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.arrow_back,
              size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
