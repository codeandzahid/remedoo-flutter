import '../theme.dart';

/// Pure helpers for the cancel-refund flow (owner order 2026-10-19).
/// Kept free of widgets so they can be unit-tested directly.

/// The refund-timing line shown wherever a paid-online order or
/// appointment is cancelled, in the owner's own terms.
const String kRefundTimingLine =
    'If you cancel, the provider will refund your payment. '
    'Refunds take 48 hours or 3 working days.';

/// Patient-facing message for a refund state on an order/appointment.
/// Returns null when there is no refund to talk about. A completed
/// refund shows its UTR as proof (owner order 2026-10-19).
String? refundStatusMessage({
  required String? refundStatus,
  required double amount,
  DateTime? refundAt,
  String? refundUtr,
}) {
  switch (refundStatus) {
    case 'requested':
      return 'Refund requested — the provider will refund '
          '${inr(amount)} to your UPI. '
          'Refunds take 48 hours to 3 working days.';
    case 'refunded':
      final when = refundAt == null
          ? ''
          : '${refundAt.day}/${refundAt.month}/${refundAt.year}';
      final utr = (refundUtr ?? '').trim();
      if (utr.isNotEmpty && when.isNotEmpty) {
        return 'Refunded ${inr(amount)} · UTR $utr · $when';
      }
      if (utr.isNotEmpty) return 'Refunded ${inr(amount)} · UTR $utr';
      return when.isEmpty
          ? 'Refunded ${inr(amount)}.'
          : 'Refunded ${inr(amount)} on $when.';
    default:
      return null;
  }
}

/// A refund UTR / UPI reference number is 9–22 digits (the same
/// range the Remedoo Pay bank-SMS parser accepts). "Mark refunded"
/// stays blocked until the panelist enters a valid one.
bool isValidRefundUtr(String value) =>
    RegExp(r'^\d{9,22}$').hasMatch(value.trim());

/// Builds the UPI deep link that opens the panelist's UPI app
/// prefilled for a refund to the customer. Same shape as the
/// OnlinePaymentScreen payment link.
String refundUpiLink({
  required String customerUpi,
  required String customerName,
  required double amount,
  required String ref,
}) {
  final params = {
    'pa': customerUpi,
    'pn': customerName.isNotEmpty ? customerName : 'Customer',
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    'tn': 'Refund $ref',
  };
  final query = params.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
  return 'upi://pay?$query';
}

/// True when a requested refund has been waiting more than 48
/// hours (admin "Overdue refund" flag). The wait is measured from
/// [requestedAt], falling back to the session's creation time.
bool isRefundOverdue({
  required String? refundStatus,
  DateTime? requestedAt,
  DateTime? createdAt,
  DateTime? now,
}) {
  if (refundStatus != 'requested') return false;
  final from = requestedAt ?? createdAt;
  if (from == null) return false;
  return (now ?? DateTime.now()).difference(from).inHours >= 48;
}

/// Total money received through Remedoo Pay: the sum of the amounts
/// of all SUCCESS sessions, in paise.
int totalReceivedPaise(List<Map<String, dynamic>> sessions) {
  var sum = 0;
  for (final s in sessions) {
    if ('${s['status'] ?? ''}' == 'SUCCESS') {
      sum += (s['amount_paise'] as num?)?.toInt() ?? 0;
    }
  }
  return sum;
}

/// How many Remedoo Pay sessions actually landed (status SUCCESS).
int receivedCount(List<Map<String, dynamic>> sessions) =>
    sessions.where((s) => '${s['status'] ?? ''}' == 'SUCCESS').length;

/// The customer's UPI for a Remedoo Pay session row: the dedicated
/// payer column first, then the UPI stashed in the customer json at
/// checkout. Null when it was never captured.
String? sessionCustomerUpi(Map<String, dynamic> session) {
  final payer = '${session['payer_vpa'] ?? ''}'.trim();
  if (payer.isNotEmpty) return payer;
  final cust = session['customer'];
  if (cust is Map) {
    final upi = '${cust['upi'] ?? ''}'.trim();
    if (upi.isNotEmpty) return upi;
  }
  return null;
}
