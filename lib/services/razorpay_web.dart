// Stub for non-web platforms. The real implementation is in
// razorpay_web_impl.dart, used when dart.library.html is available.

/// Opens Razorpay checkout on web. No-op on non-web platforms.
void openRazorpayWeb(
  Map<String, dynamic> options, {
  required void Function(String paymentId) onPaymentSuccess,
  required void Function(String error) onPaymentError,
}) {
  onPaymentError('Web checkout not available on this platform.');
}
