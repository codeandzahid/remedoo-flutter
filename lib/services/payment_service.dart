import 'package:razorpay_flutter/razorpay_flutter.dart';

/// In-app UPI/card payment via Razorpay.
/// API keys are configured in Admin Panel > Settings > Payments.
/// Keys are stored in app_config, never hardcoded.
class PaymentService {
  static final PaymentService instance = PaymentService._();
  PaymentService._();

  Razorpay? _razorpay;
  void Function(String paymentId)? onSuccess;
  void Function(String error)? onError;

  String _keyId = '';
  bool _enabled = false;

  /// Configure from admin settings (call on app start and when settings change)
  void configure({required String keyId, required bool enabled}) {
    _keyId = keyId;
    _enabled = enabled;
  }

  /// Check if Razorpay is configured and enabled
  bool get isConfigured =>
      _enabled && _keyId.isNotEmpty && _keyId.startsWith('rzp_');

  void _ensureInitialized() {
    _razorpay ??= Razorpay();
    _razorpay!.clear();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) {
      onSuccess?.call(response.paymentId ?? '');
    });
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
      onError?.call(response.message ?? 'Payment failed');
    });
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse response) {
      // External wallet selected, treat as pending
    });
  }

  /// Open Razorpay checkout for in-app UPI/card payment.
  /// Amount is in INR (will be converted to paise).
  void pay({
    required double amount,
    required String orderId,
    required String description,
    String? contact,
    String? email,
    required void Function(String paymentId) onPaymentSuccess,
    required void Function(String error) onPaymentError,
  }) {
    if (!isConfigured) {
      onPaymentError('Payment gateway not configured. Contact admin.');
      return;
    }

    onSuccess = onPaymentSuccess;
    onError = onPaymentError;
    _ensureInitialized();

    final options = {
      'key': _keyId,
      'amount': (amount * 100).toInt(), // paise
      'currency': 'INR',
      'name': 'Remedoo',
      'description': description,
      'prefill': {
        if (contact != null) 'contact': contact,
        if (email != null) 'email': email,
      },
      'theme': {'color': '#2196F3'},
      // Enable UPI, cards, netbanking, wallets
      'method': {
        'upi': true,
        'card': true,
        'netbanking': true,
        'wallet': true,
      },
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      onPaymentError('Could not open payment: $e');
    }
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
