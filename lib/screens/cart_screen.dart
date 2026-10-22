import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../services/payment_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/coupons.dart';
import '../utils/device_actions.dart';
import '../widgets/coupon_field.dart';
import '../widgets/widgets.dart';
import '../widgets/form_kit.dart';
import 'remedoo_pharmacy_screen.dart';
import 'payment_failure_screen.dart';
import '../app_navigator.dart';

/// Your Cart — matches Cart.tsx: gradient header, item rows with steppers,
/// Rx prescription card, address + GPS, payment radio rows, bill summary,
/// fixed bottom "Place Order" CTA. Cart logic kept exactly as before.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _address = TextEditingController();
  final _instructions = TextEditingController();
  final _payerUpi = TextEditingController();
  String _payment = 'Cash on Delivery';
  Map<String, dynamic>? _coupon;
  String? _rxFileName;
  Uint8List? _rxBytes;
  String? _rxPath;
  bool _locating = false;
  bool _addressPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start with the patient's saved address filled in instead of
    // blank (sweep fix 2026-10-20). One-time only: the chips, GPS
    // and manual typing keep working exactly as before.
    if (!_addressPrefilled) {
      _addressPrefilled = true;
      final saved = AppStateScope.of(context).defaultDeliveryAddress;
      if (saved != null && _address.text.isEmpty) {
        _address.text = saved;
      }
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _instructions.dispose();
    _payerUpi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      body: Column(
        children: [
          RGradientHeader(
            child: Row(
              children: [
                _HeaderBack(
                    onTap: () => goBack(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Your Cart',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      if ((state.cartPharmacyName ?? '').isNotEmpty)
                        Text(state.cartPharmacyName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.75),
                                fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.cartLines.isEmpty
                ? _emptyBody()
                : _cartBody(state),
          ),
        ],
      ),
      bottomNavigationBar:
          state.cartLines.isEmpty ? null : _bottomCta(state),
    );
  }

  Widget _emptyBody() {
    return MaxWidthBox(
      child: REmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Your cart is empty',
        subtitle: 'Add medicines from any pharmacy to get started.',
        actionLabel: 'Browse Pharmacies',
        onAction: () =>
            pushPage(context, const RemedooPharmacyScreen()),
      ),
    );
  }

  /// Live coupon discount for a subtotal (Patient gap 18):
  /// re-evaluated on every build so cart changes re-price it.
  double _couponDiscount(double subtotal) {
    if (_coupon == null) return 0;
    final v = evaluateCoupon(_coupon!, subtotal, appliesTo: 'pharmacy');
    return v.ok ? v.discount : 0;
  }

  Widget _cartBody(AppState state) {
    final subtotal = state.cartTotal;
    // Same admin-configured delivery rule as the other checkout
    // (audit Patient 25 — this screen hardcoded ₹30 / ₹500).
    final delivery =
        subtotal >= state.freeDeliveryThreshold ? 0.0 : state.deliveryFee;
    final total = subtotal + delivery - _couponDiscount(subtotal);
    final requiresRx =
        state.cartLines.any((l) => l.medicine.rxRequired);
    return MaxWidthBox(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          DetailSplit(
            main: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _itemsCard(state),
                const SizedBox(height: 12),
                if (requiresRx) ...[
                  _prescriptionCard(),
                  const SizedBox(height: 12),
                ],
                _addressCard(),
                const SizedBox(height: 12),
                _paymentCard(),
                if (_payment == 'Pay Online') ...[
                  const SizedBox(height: 12),
                  RKitField(
                    controller: _payerUpi,
                    label: 'Your UPI ID (for refunds, optional)',
                    icon: Icons.account_balance_wallet_outlined,
                    hint: 'name@bank',
                  ),
                ],
                const SizedBox(height: 12),
                CouponField(
                  subtotal: subtotal,
                  onChanged: (c) => setState(() => _coupon = c),
                ),
                if (context.isCompact) ...[
                  const SizedBox(height: 12),
                  _billCard(subtotal, delivery, total),
                ],
              ],
            ),
            side: context.isCompact
                ? const SizedBox.shrink()
                : _billCard(subtotal, delivery, total),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _placeOrder(AppState state, double total) async {
    if (!checkLogin(context)) return;
    // Prescription-required items: the upload shown in this screen is
    // mandatory for such carts (audit fix 2026-10-19) — the order must
    // not proceed without an attached prescription.
    final requiresRx =
        state.cartLines.any((l) => l.medicine.rxRequired);
    if (requiresRx && _rxFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please upload your prescription to place this order')),
      );
      return;
    }
    // No active gateway: popup explains online payment is unavailable
    // and the order continues as Cash on Delivery only.
    if (_payment == 'Pay Online' &&
        !PaymentService.instance.hasActiveGateway) {
      await PaymentService.showNoGatewayDialog(context,
          offlineLabel: 'Cash on Delivery');
      if (!mounted) return;
      setState(() => _payment = 'Cash on Delivery');
      return;
    }
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a delivery address')),
      );
      return;
    }
    // Pay Online really pays now: run the gateway checkout first
    // (money goes to the cart pharmacy's own UPI, like bookings)
    // and only place the order when the payment succeeds.
    String? paymentRef;
    if (_payment == 'Pay Online') {
      paymentRef = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final paid = await _payOnline(state, total, paymentRef);
      if (!paid || !mounted) return;
    }
    // Upload the picked prescription for real (audit M3): the
    // order must carry the file URL, not just a file name. An Rx
    // order whose upload fails stops here — no false assurance.
    String? prescriptionUrl;
    if (_rxFileName != null) {
      prescriptionUrl = await state.uploadOrderPrescription(
          _rxBytes, _rxPath, _rxFileName!);
      if (!mounted) return;
      if (prescriptionUrl == null && requiresRx) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Prescription upload failed. Check your connection and try again.')),
        );
        return;
      }
    }
    final discount = _couponDiscount(state.cartTotal);
    final placed = await state.placeOrder(
      address: _address.text.trim(),
      payment: _payment,
      paymentRef: paymentRef,
      prescriptionUrl: prescriptionUrl,
      customerUpi: _payerUpi.text.trim().isEmpty
          ? null
          : _payerUpi.text.trim(),
      notes: _instructions.text.trim().isEmpty
          ? null
          : _instructions.text.trim(),
      couponCode: discount > 0 ? '${_coupon?['code'] ?? ''}' : null,
      couponDiscount: discount,
    );
    if (!mounted) return;
    if (placed == null) {
      // Backend rejected the order (or the cart has no real
      // pharmacy) — the cart is untouched; say so (full-check fix
      // 2026-10-22: success used to show unconditionally and the
      // coupon was recorded for an order that never existed).
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not place the order. Please try again.')),
      );
      return;
    }
    if (discount > 0 && _coupon != null) {
      unawaited(state.supabaseRepository.recordCouponUsage(
        couponId: '${_coupon!['id']}',
        discountApplied: discount,
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order placed successfully!')),
    );
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  /// Runs the hosted payment for a medicine order. Returns true
  /// only when the payment succeeds.
  Future<bool> _payOnline(AppState state, double total, String orderRef) async {
    final completer = Completer<bool>();
    PaymentService.instance.onPaymentBusy = () async {
      if (!mounted) return false;
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, size: 36),
          title: const Text('A payment is pending'),
          content: const Text(
            'Another payment is being completed right now. It will '
            'finish, or auto-expire within 5 minutes.\n\n'
            'You can wait and try again — or tap Pay New to cancel '
            'the pending payment and start yours now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Wait'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pay New'),
            ),
          ],
        ),
      );
      return choice ?? false;
    };
    PaymentService.instance.pay(
      amount: total,
      orderId: orderRef,
      description:
          'Medicine order: ${state.cartPharmacyName ?? 'Pharmacy'}',
      providerKind: 'pharmacy',
      // The in-house Remedoo Pharmacy storefront ('remedoo') is not a
      // provider record: its payments go to Remedoo's central UPI, so
      // no provider id is sent (the gateway resolves the central VPA).
      providerId:
          state.cartPharmacyId == 'remedoo' ? null : state.cartPharmacyId,
      payerUpi: _payerUpi.text.trim().isEmpty
          ? null
          : _payerUpi.text.trim(),
      contact: state.phone.isNotEmpty ? state.phone : null,
      email: state.email.isNotEmpty ? state.email : null,
      customerName: state.userName.isNotEmpty ? state.userName : null,
      onPaymentSuccess: (paymentId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment successful: $paymentId')),
          );
        }
        if (!completer.isCompleted) completer.complete(true);
      },
      onPaymentError: (error) {
        if (!completer.isCompleted) completer.complete(false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed: $error')),
          );
          // Real failure flow (audit fix): show the payment-failure
          // screen with retry / different-method options.
          pushPage(context, PaymentFailureScreen(amount: total));
        }
      },
    );
    return completer.future;
  }

  Widget _itemsCard(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Items (${state.cartLines.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              // Clear Cart (audit fix 2026-10-19 — emptying the
              // cart previously meant removing every line by hand).
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Clear cart?',
                    message: 'All items will be removed from your cart.',
                    confirmLabel: 'Clear cart',
                  );
                  if (ok) state.clearCart();
                },
                icon: Icon(Icons.delete_sweep_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                label: Text('Clear',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...state.cartLines.map((l) {
            final price = state.priceOf(l.medicine);
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                          l.medicine.rxRequired ? '📋' : '💊',
                          style:
                              const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(l.medicine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5)),
                        Text(
                            '${inr(price)} × ${l.qty}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme
                                    .onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _miniStepper(l, state),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 58,
                    child: Text(inr(price * l.qty),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// React-style stepper: trash at qty 1, minus/plus otherwise.
  Widget _miniStepper(CartLine l, AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepBtn(
          l.qty == 1 ? Icons.delete_outline : Icons.remove,
          // Full-check fix 2026-10-22: minus used to delete the
          // whole line at ANY quantity; it now steps down by one
          // (changeQty existed but was never called). Trash at
          // qty 1 still removes the line.
          l.qty == 1
              ? () => state.removeCartLine(l)
              : () => state.changeQty(l.medicine.id, -1),
          scheme,
          destructive: l.qty == 1,
        ),
        SizedBox(
          width: 26,
          child: Text('${l.qty}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5)),
        ),
        _stepBtn(
          Icons.add,
          () => state.addToCart(l.medicine,
              pharmacyId: state.cartPharmacyId ?? '',
              pharmacyName: state.cartPharmacyName ?? ''),
          scheme,
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap,
      ColorScheme scheme,
      {bool destructive = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest
              .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 15,
            color: destructive
                ? RemedooTheme.destructive
                : scheme.onSurface),
      ),
    );
  }

  Widget _prescriptionCard() {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Prescription Required',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Some items in your cart require a valid prescription.',
            style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant),
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
                Uint8List? data;
                try {
                  data = await file.readAsBytes();
                } catch (_) {}
                if (!context.mounted) return;
                setState(() {
                  _rxFileName = file.name;
                  _rxBytes = data;
                  _rxPath = file.path;
                });
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

  Widget _addressCard() {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Text('Delivery Address',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
              const Spacer(),
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
                        final address =
                            await fetchCurrentAddress();
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
                              content:
                                  Text('Location detected!')),
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (AppStateScope.of(context).savedAddresses.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a
                    in AppStateScope.of(context).savedAddresses)
                  ActionChip(
                    avatar: const Icon(Icons.location_on, size: 15),
                    label: Text(a.label),
                    onPressed: () {
                      _address.text = a.address;
                      setState(() {});
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          RKitField(
            label: 'Delivery Address',
            hint: 'Enter your full delivery address…',
            controller: _address,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          RKitField(
            label: 'Special instructions (optional)',
            hint: 'Any special instructions? (optional)',
            controller: _instructions,
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final scheme = Theme.of(context).colorScheme;
    final onlineAvailable = PaymentService.instance.hasActiveGateway;
    // With no active gateway, customers only get Cash on Delivery.
    if (!onlineAvailable && _payment == 'Pay Online') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _payment = 'Cash on Delivery');
      });
    }
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ...[
            ('Cash on Delivery', '💵', 'Pay when your order arrives'),
            if (onlineAvailable)
              (
                'Pay Online',
                '💳',
                'UPI, Cards & Netbanking via '
                    '${PaymentService.instance.gatewayDisplayName} · Secure'
              ),
          ].map((p) {
            final selected = _payment == p.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? RFormBrand.blue.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () =>
                      setState(() => _payment = p.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected
                            ? RFormBrand.blue
                            : Theme.of(context).dividerColor,
                        width: selected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? RFormBrand.blue
                                  : scheme.onSurfaceVariant,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: RFormBrand.blue,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p.$2} ${p.$1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              const SizedBox(height: 1),
                              Text(p.$3,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (!onlineAvailable)
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 15, color: RemedooTheme.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Online payment is not available right now — Cash on Delivery only.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _billCard(
      double subtotal, double delivery, double total) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bill Summary',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          _billRow('Subtotal', inr(subtotal), scheme),
          _billRow(
            'Delivery fee',
            delivery == 0 ? 'FREE' : inr(delivery),
            scheme,
            valueColor:
                delivery == 0 ? RemedooTheme.success : null,
            valueBold: delivery == 0,
          ),
          if (delivery == 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                  'Free delivery on orders above '
                  '${inr(AppStateScope.of(context).freeDeliveryThreshold)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: RemedooTheme.success)),
            ),
          if (_couponDiscount(subtotal) > 0)
            _billRow(
              'Coupon ${_coupon?['code'] ?? ''}',
              '−${inr(_couponDiscount(subtotal))}',
              scheme,
              valueColor: RemedooTheme.success,
              valueBold: true,
            ),
          Divider(height: 16, color: Theme.of(context).dividerColor),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
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

  Widget _billRow(String label, String value, ColorScheme scheme,
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

  Widget _bottomCta(AppState state) {
    final subtotal = state.cartTotal;
    final delivery =
        subtotal >= state.freeDeliveryThreshold ? 0.0 : state.deliveryFee;
    final total = subtotal + delivery - _couponDiscount(subtotal);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
                color: Theme.of(context).dividerColor),
          ),
        ),
        child: RButton(
          label: 'Place Order • ${inr(total)}',
          fullWidth: true,
          onPressed: () => _placeOrder(state, total),
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
