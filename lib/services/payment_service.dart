import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_config.dart';

/// Online payment via the admin-selected gateway.
///
/// Gateways are configured in Admin > Settings > Payment Gateways and
/// can be switched anytime. Supported: Razorpay, Cashfree, Instamojo,
/// PayU. All use hosted checkout pages created by the backend
/// (Supabase Edge Function `payment-create`), so no fragile in-page
/// JS SDK is needed. Payment completion is detected by polling
/// `payment-status`.
class PaymentService {
  static final PaymentService instance = PaymentService._();
  PaymentService._();

  Razorpay? _razorpay;
  void Function(String paymentId)? onSuccess;
  void Function(String error)? onError;

  String _activeGateway = 'razorpay';
  String _keyId = '';
  bool _enabled = false;

  /// Configure from admin settings (call on app start and when
  /// settings change). [gateway] is the active gateway id.
  void configure({
    required String keyId,
    required bool enabled,
    String gateway = 'razorpay',
  }) {
    _keyId = keyId;
    _enabled = enabled;
    _activeGateway = gateway;
  }

  String get activeGateway => _activeGateway;

  /// True only when a gateway is ACTIVE and ready for customers:
  /// enabled in Admin AND a key is saved. When false, customers must
  /// only be offered offline options (Cash on Delivery / At Clinic).
  bool get isConfigured => _enabled && _keyId.isNotEmpty;

  /// Alias used by checkout UIs deciding whether to show "Pay Online".
  bool get hasActiveGateway => isConfigured;

  /// Human-readable name of the active gateway.
  String get gatewayDisplayName {
    switch (_activeGateway) {
      case 'cashfree':
        return 'Cashfree';
      case 'instamojo':
        return 'Instamojo';
      case 'payu':
        return 'PayU';
      case 'razorpay':
      default:
        return 'Razorpay';
    }
  }

  void _ensureInitialized() {
    if (kIsWeb) return; // Web uses hosted checkout links
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

  /// Start a payment. Amount is in INR.
  ///
  /// Web + mobile: creates a hosted checkout via the backend for the
  /// admin-selected gateway, opens it in the browser, and polls for
  /// completion. (Mobile Razorpay uses the native plugin when Razorpay
  /// is the active gateway, for a smoother in-app flow.)
  void pay({
    required double amount,
    required String orderId,
    required String description,
    String? contact,
    String? email,
    String? customerName,
    required void Function(String paymentId) onPaymentSuccess,
    required void Function(String error) onPaymentError,
  }) {
    if (!isConfigured) {
      onPaymentError('Payment gateway not configured. Contact admin.');
      return;
    }

    onSuccess = onPaymentSuccess;
    onError = onPaymentError;

    // Native in-app checkout only for Razorpay on mobile
    if (!kIsWeb && _activeGateway == 'razorpay' && _keyId.isNotEmpty) {
      _payWithRazorpayPlugin(
        amount: amount,
        description: description,
        contact: contact,
        email: email,
      );
      return;
    }

    _payViaHostedCheckout(
      amount: amount,
      orderId: orderId,
      description: description,
      contact: contact,
      email: email,
      customerName: customerName,
    );
  }

  void _payWithRazorpayPlugin({
    required double amount,
    required String description,
    String? contact,
    String? email,
  }) {
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
      onError?.call('Could not open payment: $e');
    }
  }

  /// Hosted checkout via backend for the active gateway.
  void _payViaHostedCheckout({
    required double amount,
    required String orderId,
    required String description,
    String? contact,
    String? email,
    String? customerName,
  }) async {
    try {
      final functionUrl =
          '${SupabaseConfig.url}/functions/v1/payment-create';

      final res = await http
          .post(
            Uri.parse(functionUrl),
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConfig.anonKey,
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
            },
            body: jsonEncode({
              'amount': amount,
              'description': description,
              'customer_name': customerName,
              'customer_contact': contact,
              'customer_email': email,
              'reference_id': orderId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        String msg = 'Failed to start payment';
        try {
          final body = jsonDecode(res.body);
          if (body['error'] != null) msg = body['error'].toString();
        } catch (_) {}
        onError?.call(msg);
        return;
      }

      final data = jsonDecode(res.body);
      final paymentUrl = data['payment_url'] as String?;
      final gateway = (data['gateway'] as String?) ?? _activeGateway;
      final reference = data['reference'] as String?;

      if (paymentUrl == null || paymentUrl.isEmpty) {
        onError?.call('Payment page not created. Please try again.');
        return;
      }

      final uri = Uri.parse(paymentUrl);
      final launched = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        onError?.call('Could not open payment page. Please try again.');
        return;
      }

      if (reference != null) {
        _pollPaymentStatus(gateway, reference);
      } else {
        onError?.call(
            'Payment page opened. Please complete the payment there.');
      }
    } catch (e) {
      onError?.call('Payment failed: $e');
    }
  }

  /// Polls payment status until paid, failed, or timeout (10 min).
  void _pollPaymentStatus(String gateway, String reference) async {
    const maxAttempts = 120; // 10 minutes at 5s interval
    var attempts = 0;

    final statusUrl =
        '${SupabaseConfig.url}/functions/v1/payment-status';

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 5));
      attempts++;

      try {
        final res = await http
            .post(
              Uri.parse(statusUrl),
              headers: {
                'Content-Type': 'application/json',
                'apikey': SupabaseConfig.anonKey,
                'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
              },
              body: jsonEncode({
                'gateway': gateway,
                'reference': reference,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final status = data['status'] as String?;

          if (status == 'paid') {
            final paymentId =
                (data['payment_id'] as String?) ?? reference;
            onSuccess?.call(paymentId);
            return;
          } else if (status == 'failed' || status == 'expired') {
            onError?.call(
                'Payment $status. Please try booking again.');
            return;
          }
          // pending/unknown — keep polling
        }
      } catch (_) {
        // Network hiccup — keep polling
      }
    }

    onError?.call(
        'Payment timed out. If you completed the payment, your booking '
        'will be confirmed once verified. Please check your bookings.');
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Popup shown to customers when no payment gateway is active:
  /// online payment is unavailable and only the offline option
  /// ([offlineLabel], e.g. "Cash on Delivery" / "Pay at Clinic")
  /// can be used.
  static Future<void> showNoGatewayDialog(
    BuildContext context, {
    String offlineLabel = 'Cash on Delivery',
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.payments_outlined, size: 36),
        title: const Text('Online payment not available'),
        content: Text(
          'No payment gateway is active right now, so online payment '
          'is not available. You can continue with $offlineLabel.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Use $offlineLabel'),
          ),
        ],
      ),
    );
  }
}
