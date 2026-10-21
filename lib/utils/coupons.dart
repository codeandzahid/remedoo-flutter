/// Coupon validation + discount maths (audit-76 Batch 9,
/// Patient gap 18). Pure functions so both checkouts share one
/// rule set and it can be unit-tested without a backend.

/// Evaluates a coupons-table [coupon] row against a [subtotal].
/// [appliesTo] is the checkout kind ('pharmacy', 'lab', …) the
/// coupon's applicable_for is matched against ('all' matches
/// everything). Returns the discount in ₹ (0 when invalid).
({bool ok, String message, double discount}) evaluateCoupon(
  Map<String, dynamic> coupon,
  double subtotal, {
  String appliesTo = 'pharmacy',
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  if (coupon['is_active'] != true) {
    return (ok: false, message: 'This coupon is not active.', discount: 0);
  }
  final from = DateTime.tryParse('${coupon['valid_from'] ?? ''}');
  if (from != null && at.isBefore(from)) {
    return (ok: false, message: 'This coupon is not live yet.', discount: 0);
  }
  final until = DateTime.tryParse('${coupon['valid_until'] ?? ''}');
  if (until != null && at.isAfter(until)) {
    return (ok: false, message: 'This coupon has expired.', discount: 0);
  }
  final applicable = '${coupon['applicable_for'] ?? 'all'}';
  if (applicable != 'all' && applicable != appliesTo) {
    return (
      ok: false,
      message: 'This coupon does not apply to this order.',
      discount: 0
    );
  }
  final minOrder = (coupon['min_order_amount'] as num?)?.toDouble() ?? 0;
  if (subtotal < minOrder) {
    return (
      ok: false,
      message: 'Add ₹${(minOrder - subtotal).toStringAsFixed(0)} more to use this coupon.',
      discount: 0
    );
  }
  final limit = (coupon['usage_limit'] as num?)?.toInt();
  final used = (coupon['used_count'] as num?)?.toInt() ?? 0;
  if (limit != null && used >= limit) {
    return (
      ok: false,
      message: 'This coupon has reached its usage limit.',
      discount: 0
    );
  }
  final value = (coupon['discount_value'] as num?)?.toDouble() ?? 0;
  double discount;
  if ('${coupon['discount_type'] ?? 'percentage'}' == 'flat') {
    discount = value;
  } else {
    discount = subtotal * value / 100;
    final cap = (coupon['max_discount_amount'] as num?)?.toDouble();
    if (cap != null && discount > cap) discount = cap;
  }
  if (discount > subtotal) discount = subtotal;
  if (discount <= 0) {
    return (ok: false, message: 'This coupon gives no discount.', discount: 0);
  }
  return (ok: true, message: 'Coupon applied.', discount: discount);
}
