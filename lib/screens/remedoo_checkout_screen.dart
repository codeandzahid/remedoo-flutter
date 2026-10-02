import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Checkout for the Remedoo Pharmacy store.
class RemedooCheckoutScreen extends StatefulWidget {
  const RemedooCheckoutScreen({super.key});

  @override
  State<RemedooCheckoutScreen> createState() =>
      _RemedooCheckoutScreenState();
}

class _RemedooCheckoutScreenState extends State<RemedooCheckoutScreen> {
  final _address = TextEditingController();
  String _payment = 'Cash on Delivery';
  bool _rxUploaded = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final subtotal = state.cartTotal;
    const delivery = 30.0;
    final total = subtotal + delivery;
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  const Text('Prescription',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
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
                  const Text('Payment Method',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  RadioGroup<String>(
                    groupValue: _payment,
                    onChanged: (v) =>
                        setState(() => _payment = v!),
                    child: Column(
                      children: [
                        for (final m in [
                          'Cash on Delivery',
                          'Pay Online',
                          'UPI'
                        ])
                          RadioListTile<String>(
                            value: m,
                            title: Text(m),
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
                  _row('Items (${state.cartCount})',
                      inr(subtotal)),
                  _row('Delivery', inr(delivery)),
                  const Divider(),
                  _row('To Pay', inr(total), bold: true),
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

  Widget _row(String label, String value, {bool bold = false}) {
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
