import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

/// Your Cart: steppers, prescription upload, address, payment, bill.
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
    if (state.cartLines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Cart')),
        body: const EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          subtitle: 'Add medicines from any pharmacy to get started.',
        ),
      );
    }
    final subtotal = state.cartTotal;
    const delivery = 30.0;
    final total = subtotal + delivery;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Cart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...state.cartLines.map((l) => _line(l, state)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prescription Required',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  const Text(
                    'Some items in your cart need a valid prescription.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _rxUploaded = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Prescription uploaded! (demo)')),
                      );
                    },
                    icon: Icon(_rxUploaded
                        ? Icons.check_circle
                        : Icons.upload_file),
                    label: Text(_rxUploaded
                        ? 'Prescription Uploaded'
                        : 'Upload Prescription'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Delivery Address',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _address,
                    decoration: InputDecoration(
                      hintText: 'House no, street, area…',
                      suffixIcon: TextButton(
                        onPressed: () {
                          _address.text =
                              '12, Residency Road, Srinagar';
                          setState(() {});
                        },
                        child: const Text('Use GPS'),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _instructions,
                    decoration: const InputDecoration(
                      hintText: 'Delivery instructions (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  RadioGroup<String>(
                    groupValue: _payment,
                    onChanged: (v) =>
                        setState(() => _payment = v!),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          value: 'Cash on Delivery',
                          title: Text('Cash on Delivery'),
                          activeColor:
                              RemedooTheme.primary,
                          contentPadding:
                              EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          value: 'Pay Online',
                          title: Text('Pay Online'),
                          activeColor:
                              RemedooTheme.primary,
                          contentPadding:
                              EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bill Summary',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  _billRow('Subtotal', inr(subtotal)),
                  _billRow('Delivery', inr(delivery)),
                  const Divider(),
                  _billRow('Total', inr(total), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (_address.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Please enter a delivery address')),
                );
                return;
              }
              state.placeOrder(
                address: _address.text.trim(),
                payment: _payment,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Order placed successfully!')),
              );
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: Text('Place Order • ${inr(total)}'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _line(CartLine l, AppState state) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    RemedooTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication,
                  color: RemedooTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.medicine.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                  Text(l.medicine.pack,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  Text(inr(state.priceOf(l.medicine)),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: RemedooTheme.primary)),
                ],
              ),
            ),
            QtyStepper(
              qty: l.qty,
              onMinus: () => state.removeFromCart(l.medicine.id),
              onPlus: () => state.addToCart(l.medicine, pharmacyId: state.cartPharmacyId ?? '', pharmacyName: state.cartPharmacyName ?? ''),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}
