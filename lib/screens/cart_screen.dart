import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'remedoo_pharmacy_screen.dart';

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
  String _payment = 'Cash on Delivery';
  bool _rxUploaded = false;

  @override
  void dispose() {
    _address.dispose();
    _instructions.dispose();
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
                    onTap: () => Navigator.maybePop(context)),
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

  Widget _cartBody(AppState state) {
    final subtotal = state.cartTotal;
    // Matches React Cart.tsx: free delivery above ₹500.
    final delivery = subtotal > 500 ? 0.0 : 30.0;
    final total = subtotal + delivery;
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

  void _placeOrder(AppState state, double total) {
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a delivery address')),
      );
      return;
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

  Widget _itemsCard(AppState state) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items (${state.cartLines.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
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
          () => state.removeFromCart(l.medicine.id),
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
    return Material(
      color: scheme.surfaceContainerHighest
          .withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon,
              size: 15,
              color: destructive
                  ? RemedooTheme.destructive
                  : scheme.onSurface),
        ),
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
              label: _rxUploaded
                  ? 'Prescription Uploaded'
                  : 'Upload Prescription',
              icon: _rxUploaded
                  ? Icons.check_circle
                  : Icons.upload_file,
              variant: RButtonVariant.outline,
              onPressed: () {
                setState(() => _rxUploaded = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Prescription uploaded! (demo)')),
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
                label: 'Use GPS',
                icon: Icons.my_location,
                small: true,
                variant: RButtonVariant.outline,
                onPressed: () {
                  _address.text =
                      '12, Residency Road, Srinagar';
                  setState(() {});
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                        content:
                            Text('Location detected! (demo)')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          RTextField(
            hint: 'Enter your full delivery address…',
            controller: _address,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          RTextField(
            hint: 'Any special instructions? (optional)',
            controller: _instructions,
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Method',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          ...[
            ('Cash on Delivery', '💵'),
            ('Pay Online', '💳'),
          ].map((p) {
            final selected = _payment == p.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.06)
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
                            ? scheme.primary
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
                                  ? scheme.primary
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
                                      color: scheme.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text('${p.$2} ${p.$1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
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
                  'Free delivery on orders above ₹500',
                  style: TextStyle(
                      fontSize: 11,
                      color: RemedooTheme.success)),
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
    final delivery = subtotal > 500 ? 0.0 : 30.0;
    final total = subtotal + delivery;
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
