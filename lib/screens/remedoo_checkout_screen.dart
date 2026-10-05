import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/device_actions.dart';
import '../widgets/widgets.dart';
import '../widgets/upi_payment_sheet.dart';
import 'online_payment_screen.dart';
import '../app_navigator.dart';

/// Checkout for the Remedoo Pharmacy store — matches RemedooCheckout.tsx:
/// plain sticky header, order summary with (Rx) tags + dashed divider,
/// amber Rx notice, address + GPS, prescription upload, payment boxes,
/// notes, full-width Place Order CTA. Checkout logic kept exactly as before.
class RemedooCheckoutScreen extends StatefulWidget {
  const RemedooCheckoutScreen({super.key});

  @override
  State<RemedooCheckoutScreen> createState() =>
      _RemedooCheckoutScreenState();
}

class _RemedooCheckoutScreenState
    extends State<RemedooCheckoutScreen> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  String _payment = 'Cash on Delivery';
  String? _rxFileName;
  bool _locating = false;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final subtotal = state.cartTotal;
    // Delivery fee + free-delivery threshold are admin-controlled
    // (Settings > App Settings).
    final delivery = subtotal >= state.freeDeliveryThreshold
        ? 0.0
        : state.deliveryFee;
    final total = subtotal + delivery;
    final hasRx =
        state.cartLines.any((l) => l.medicine.rxRequired);
    if (state.cartLines.isEmpty) {
      return Scaffold(
        body: Column(
          children: [
            _stickyHeader(),
            const Expanded(
              child: REmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'No items in cart',
                subtitle:
                    'Add medicines from Remedoo Pharmacy to check out.',
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          _stickyHeader(),
          Expanded(
            child: MaxWidthBox(
              maxWidth: context.isCompact ? 720 : 1200,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  DetailSplit(
                    main: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        _summaryCard(
                            state, subtotal, delivery, total),
                        if (hasRx) ...[
                          const SizedBox(height: 12),
                          _rxNotice(),
                        ],
                        const SizedBox(height: 12),
                        _addressCard(),
                        if (hasRx) ...[
                          const SizedBox(height: 12),
                          _prescriptionCard(),
                        ],
                        const SizedBox(height: 12),
                        _paymentCard(),
                        const SizedBox(height: 12),
                        _notesCard(),
                      ],
                    ),
                    side: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        _payCard(total, state),
                      ],
                    ),
                  ),
                  if (context.isCompact) ...[
                    const SizedBox(height: 16),
                    RButton(
                      label:
                          'Place Order • ${inr(total)}',
                      fullWidth: true,
                      onPressed: () =>
                          _placeOrder(state),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _placeOrder(AppState state) async {
    if (!checkLogin(context)) return;
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a delivery address')),
      );
      return;
    }
    // "Pay Online" opens the payment page first — the order is only
    // placed after the user completes payment there.
    if (_payment == 'Pay Online') {
      final pharmacies = state.activePharmacies
          .where((p) => p.id == state.cartPharmacyId);
      final pharmacy =
          pharmacies.isNotEmpty ? pharmacies.first : null;
      final total = state.cartTotal + state.deliveryFee;
      final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OnlinePaymentScreen(
            amount: total,
            recipientName: pharmacy?.name ?? 'Pharmacy',
            recipientUpiId: pharmacy?.upiId,
            orderId: orderId,
            orderLabel: 'Order Total',
          ),
        ),
      );
      // Payment page dismissed or payment not completed: do not order.
      if (paid != true || !mounted) return;
    }
    // If UPI selected, show the provider's UPI payment sheet first.
    if (_payment == 'UPI') {
      final pharmacies = state.activePharmacies
          .where((p) => p.id == state.cartPharmacyId);
      final upiId =
          pharmacies.isNotEmpty ? pharmacies.first.upiId : null;
      if (upiId == null || upiId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Pharmacy has not set up UPI yet. Please choose another payment method.')),
        );
        return;
      }
      final total = state.cartTotal + state.deliveryFee; // + delivery
      final orderId = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      showUpiPaymentSheet(
        context,
        upiId: upiId,
        providerName:
            pharmacies.first.name,
        amount: total,
        orderId: orderId,
      );
    }
    state.placeOrder(
      address: _address.text.trim(),
      payment: _payment,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order placed successfully!')),
    );
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Widget _stickyHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              _BackCircle(
                  onTap: () =>
                      goBack(context)),
              const SizedBox(width: 12),
              const Text('Checkout',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(AppState state, double subtotal,
      double delivery, double total) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          ...state.cartLines.map((l) {
            final price = state.priceOf(l.medicine);
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${l.medicine.name} × ${l.qty}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5),
                          ),
                        ),
                        if (l.medicine.rxRequired) ...[
                          const SizedBox(width: 4),
                          const Text('(Rx)',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(inr(price * l.qty),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const _DashedDivider(),
          const SizedBox(height: 8),
          _row('Subtotal', inr(subtotal), scheme),
          _row(
            'Delivery',
            delivery == 0 ? 'FREE' : inr(delivery),
            scheme,
            valueColor: delivery == 0
                ? RemedooTheme.success
                : null,
            valueBold: delivery == 0,
          ),
          if (delivery > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Add ${inr(state.freeDeliveryThreshold - subtotal)} more for free delivery',
                style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const Spacer(),
              Text(inr(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rxNotice() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF3A2A12)
            : const Color(0xFFFEF7E7),
        border: Border.all(
            color: dark
                ? const Color(0xFF8A6D2B)
                : const Color(0xFFF5D9A8)),
        borderRadius:
            BorderRadius.circular(RemedooRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📋 Prescription Verification Required',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? const Color(0xFFF5C86B)
                      : const Color(0xFFB45309))),
          const SizedBox(height: 4),
          Text(
            'Some items in your cart require a valid prescription. Your order will be held for pharmacist verification before processing.',
            style: TextStyle(
                fontSize: 12,
                color: dark
                    ? const Color(0xFFE8C87E)
                    : const Color(0xFF92600A))),
        ],
      ),
    );
  }

  Widget _addressCard() {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Address',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          RTextField(
            hint: 'Enter your full address',
            controller: _address,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          RButton(
            label: _locating ? 'Locating…' : 'Use GPS',
            icon: Icons.my_location,
            small: true,
            variant: RButtonVariant.outline,
            onPressed: _locating
                ? null
                : () async {
                    final messenger =
                        ScaffoldMessenger.of(context);
                    setState(() => _locating = true);
                    final address = await fetchCurrentAddress();
                    if (!context.mounted) return;
                    setState(() => _locating = false);
                    if (address == null) {
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Could not detect location. Please allow location access or enter your address manually.')),
                      );
                      return;
                    }
                    _address.text = address;
                    setState(() {});
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Location detected!')),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _prescriptionCard() {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Upload Prescription *',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Upload a clear image of your prescription. Order will not proceed without approval.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: RButton(
              label: _rxFileName != null
                  ? 'Prescription: $_rxFileName'
                  : 'Upload Prescription',
              icon: _rxFileName != null
                  ? Icons.check_circle
                  : Icons.upload_file,
              variant: RButtonVariant.outline,
              onPressed: () async {
                final messenger =
                    ScaffoldMessenger.of(context);
                final files = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                );
                if (files.isEmpty) return;
                final file = files.first;
                if (!context.mounted) return;
                setState(() => _rxFileName = file.name);
                messenger.showSnackBar(
                  SnackBar(
                      content: Text(
                          'Prescription "${file.name}" attached.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final scheme = Theme.of(context).colorScheme;
    final state = AppStateScope.of(context);
    final pharmacies = state.activePharmacies
        .where((p) => p.id == state.cartPharmacyId);
    final pharmacy =
        pharmacies.isNotEmpty ? pharmacies.first : null;
    final codOn = pharmacy?.payInClinicEnabled ?? true;
    final upiOn = (pharmacy?.upiEnabled ?? true) &&
        (pharmacy?.upiId?.isNotEmpty ?? false);
    final methods = [
      if (codOn) 'Cash on Delivery',
      'Pay Online',
      if (upiOn) 'UPI',
    ];

    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: methods.map((m) {
              final selected = _payment == m;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: m == methods.last ? 0 : 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          setState(() => _payment = m),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : Theme.of(context)
                                    .dividerColor,
                            width: selected ? 2 : 1,
                          ),
                          color: selected
                              ? scheme.primary
                                  .withValues(alpha: 0.06)
                              : null,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(m,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _notesCard() {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes (optional)',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 10),
          RTextField(
            hint: 'Any special instructions…',
            controller: _notes,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _payCard(double total, AppState state) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('To Pay',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const Spacer(),
              Text(inr(total),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: RemedooTheme.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              '${state.cartCount} item${state.cartCount == 1 ? '' : 's'} • $_payment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant)),
          const SizedBox(height: 14),
          RButton(
            label: 'Place Order • ${inr(total)}',
            fullWidth: true,
            onPressed: () => _placeOrder(state),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, ColorScheme scheme,
      {Color? valueColor, bool valueBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: valueBold
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 12).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: 6,
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        );
      },
    );
  }
}

class _BackCircle extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? RemedooTheme.darkSecondary
          : RemedooTheme.mutedSurface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_back, size: 20),
        ),
      ),
    );
  }
}
