import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import '../utils/coupons.dart';
import 'widgets.dart';

/// Coupon code entry for the patient checkouts (audit-76
/// Batch 9, Patient gap 18). Validates against the real
/// `coupons` table and reports the applied coupon row through
/// [onChanged] (null when removed / never applied); the parent
/// computes the live discount with [evaluateCoupon] so a cart
/// change re-prices the discount immediately.
class CouponField extends StatefulWidget {
  final double subtotal;
  final String appliesTo;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const CouponField({
    super.key,
    required this.subtotal,
    this.appliesTo = 'pharmacy',
    required this.onChanged,
  });

  @override
  State<CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<CouponField> {
  final _code = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _applied;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res =
        await SupabaseRepository.instance.fetchCouponByCode(code);
    if (!mounted) return;
    if (res['ok'] != true) {
      setState(() {
        _busy = false;
        _error = '${res['message'] ?? 'Coupon not found.'}';
      });
      return;
    }
    final coupon = res['coupon'] as Map<String, dynamic>;
    final verdict = evaluateCoupon(coupon, widget.subtotal,
        appliesTo: widget.appliesTo);
    setState(() {
      _busy = false;
      if (verdict.ok) {
        _applied = coupon;
        _error = null;
      } else {
        _error = verdict.message;
      }
    });
    if (verdict.ok) widget.onChanged(coupon);
  }

  void _remove() {
    setState(() {
      _applied = null;
      _code.clear();
      _error = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_applied != null) {
      final verdict = evaluateCoupon(_applied!, widget.subtotal,
          appliesTo: widget.appliesTo);
      return RCard(
        child: Row(
          children: [
            Icon(Icons.local_offer, color: scheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_applied!['code']} applied',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                    verdict.ok
                        ? 'You save ₹${verdict.discount.toStringAsFixed(0)} on this order.'
                        : verdict.message,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: _remove, child: const Text('Remove')),
          ],
        ),
      );
    }
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RTextField(
                  label: 'Coupon code',
                  hint: 'e.g. SAVE10',
                  controller: _code,
                ),
              ),
              const SizedBox(width: 10),
              RButton(
                label: _busy ? 'Checking…' : 'Apply',
                small: true,
                onPressed: _busy ? null : _apply,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: scheme.error)),
          ],
        ],
      ),
    );
  }
}
