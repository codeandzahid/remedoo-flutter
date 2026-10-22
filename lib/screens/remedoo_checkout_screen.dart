import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
import 'payment_failure_screen.dart';
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
    _notes.dispose();
    _payerUpi.dispose();
    super.dispose();
  }

  /// Live coupon discount for a subtotal (Patient gap 18).
  double _couponDiscount(double subtotal) {
    if (_coupon == null) return 0;
    final v = evaluateCoupon(_coupon!, subtotal, appliesTo: 'pharmacy');
    return v.ok ? v.discount : 0;
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
    final total = subtotal + delivery - _couponDiscount(subtotal);
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
                          onChanged: (c) =>
                              setState(() => _coupon = c),
                        ),
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
    // Prescription-required items: the upload shown in this checkout
    // is mandatory for such carts (audit fix 2026-10-19) — the order
    // must not proceed without an attached prescription.
    final hasRx = state.cartLines.any((l) => l.medicine.rxRequired);
    if (hasRx && _rxFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please upload your prescription to place this order')),
      );
      return;
    }
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a delivery address')),
      );
      return;
    }
    // COD must actually be offered by the cart pharmacy
    // (full-check fix 2026-10-22: _payment defaulted to COD, so a
    // COD order was placed even when this pharmacy does not offer
    // COD and the method was never shown as selected).
    final pharm = state.activePharmacies
        .where((p) => p.id == state.cartPharmacyId);
    final codOn =
        pharm.isEmpty ? true : (pharm.first.payInClinicEnabled ?? true);
    if (_payment == 'Cash on Delivery' && !codOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cash on Delivery is not available for this pharmacy. Please pay online.')),
      );
      return;
    }
    // "Pay Online" runs the gateway checkout first — the order is
    // only placed after the payment succeeds (same rail as the cart
    // screen). The amount charged is exactly the summary total: the
    // delivery fee is 0 once the free-delivery threshold is reached
    // (audit fix 2026-10-19 — this used to add the raw delivery fee
    // on top even when delivery was free).
    String? paymentRef;
    if (_payment == 'Pay Online') {
      if (!PaymentService.instance.hasActiveGateway) {
        await PaymentService.showNoGatewayDialog(context,
            offlineLabel: 'Cash on Delivery');
        if (!mounted) return;
        setState(() => _payment = 'Cash on Delivery');
        return;
      }
      final subtotal = state.cartTotal;
      final delivery = subtotal >= state.freeDeliveryThreshold
          ? 0.0
          : state.deliveryFee;
      final total = subtotal + delivery - _couponDiscount(subtotal);
      paymentRef = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final paid = await _payOnline(state, total, paymentRef);
      if (!paid || !mounted) return;
    }
    // Upload the picked prescription for real (audit M3) — same
    // rule as the cart checkout: an Rx order whose upload fails
    // stops here instead of shipping a filename-only promise.
    String? prescriptionUrl;
    if (_rxFileName != null) {
      prescriptionUrl = await state.uploadOrderPrescription(
          _rxBytes, _rxPath, _rxFileName!);
      if (!mounted) return;
      if (prescriptionUrl == null && hasRx) {
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
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      couponCode: discount > 0 ? '${_coupon?['code'] ?? ''}' : null,
      couponDiscount: discount,
    );
    if (!mounted) return;
    if (placed == null) {
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

  /// Runs the hosted gateway payment for this checkout. Returns true
  /// only when the payment succeeds. The cart's pharmacy decides the
  /// recipient: a real provider pharmacy is paid on its own UPI (the
  /// gateway resolves it from the provider id); the in-house Remedoo
  /// Pharmacy storefront (cart id 'remedoo') is Remedoo itself, so no
  /// provider id is sent and the payment goes to Remedoo's central
  /// UPI — this checkout previously dead-ended for that cart because
  /// 'remedoo' is not a provider record with its own UPI.
  Future<bool> _payOnline(
      AppState state, double total, String orderRef) async {
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
          'Medicine order: ${state.cartPharmacyName ?? 'Remedoo Pharmacy'}',
      providerKind: 'pharmacy',
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
          pushPage(context, PaymentFailureScreen(amount: total));
        }
      },
    );
    return completer.future;
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
          if (_couponDiscount(subtotal) > 0)
            _row(
              'Coupon ${_coupon?['code'] ?? ''}',
              '−${inr(_couponDiscount(subtotal))}',
              scheme,
              valueColor: RemedooTheme.success,
              valueBold: true,
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
          // Saved-address chips, same as the pharmacy cart
          // checkout (audit fix 2026-10-19 — this checkout
          // previously made patients retype a saved address).
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

  Widget _paymentCard() {
    final scheme = Theme.of(context).colorScheme;
    final state = AppStateScope.of(context);
    final pharmacies = state.activePharmacies
        .where((p) => p.id == state.cartPharmacyId);
    final pharmacy =
        pharmacies.isNotEmpty ? pharmacies.first : null;
    final codOn = pharmacy?.payInClinicEnabled ?? true;
    // Pay Online is offered only while a payment gateway is active
    // (same rule as the cart screen) — otherwise the only honest
    // option is Cash on Delivery, with a note saying so.
    final onlineAvailable = PaymentService.instance.hasActiveGateway;
    if (!onlineAvailable && _payment == 'Pay Online') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _payment = 'Cash on Delivery');
      });
    }
    if (!codOn && _payment == 'Cash on Delivery' && onlineAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _payment = 'Pay Online');
      });
    }
    final methods = [
      if (codOn) 'Cash on Delivery',
      if (onlineAvailable) 'Pay Online',
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
                                ? RFormBrand.blue
                                : Theme.of(context)
                                    .dividerColor,
                            width: selected ? 2 : 1,
                          ),
                          color: selected
                              ? RFormBrand.blue
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
                                    ? RFormBrand.blue
                                    : scheme.onSurfaceVariant)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (!onlineAvailable) ...[
            const SizedBox(height: 10),
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
          RKitField(
            label: 'Notes',
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
