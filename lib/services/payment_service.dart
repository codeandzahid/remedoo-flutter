import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_config.dart';

/// In-app UPI/card payment via Razorpay.
/// API keys are configured in Admin Panel > Settings > Payments.
/// Keys are stored in app_config, never hardcoded.
///
/// Supports both mobile (razorpay_flutter plugin) and web
/// (Razorpay Payment Links — opens in browser, no JS SDK needed).
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
    if (kIsWeb) return; // Web uses Payment Links, no plugin needed
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
  /// Amount is in INR.
  ///
  /// On web: creates a Razorpay Payment Link via backend and opens it
  /// in a new browser tab. Polls for payment completion.
  /// On mobile: uses the razorpay_flutter plugin (native checkout).
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

    if (kIsWeb) {
      _payViaPaymentLink(
        amount: amount,
        orderId: orderId,
        description: description,
        contact: contact,
        email: email,
        customerName: customerName,
      );
      return;
    }

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
      onPaymentError('Could not open payment: $e');
    }
  }

  /// Web: create a Razorpay Payment Link via Edge Function, open it,
  /// and poll for payment completion.
  void _payViaPaymentLink({
    required double amount,
    required String orderId,
    required String description,
    String? contact,
    String? email,
    String? customerName,
  }) async {
    try {
      // 1. Create payment link via backend
      final functionUrl =
          '${SupabaseConfig.url}/functions/v1/razorpay-payment-link';

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
        String msg = 'Failed to create payment link';
        try {
          final body = jsonDecode(res.body);
          if (body['error'] != null) msg = body['error'].toString();
        } catch (_) {}
        onError?.call(msg);
        return;
      }

      final data = jsonDecode(res.body);
      final paymentUrl = data['payment_url'] as String?;
      final paymentLinkId = data['payment_link_id'] as String?;

      if (paymentUrl == null || paymentUrl.isEmpty) {
        onError?.call('Payment link not created. Please try again.');
        return;
      }

      // 2. Open payment link in new tab
      final uri = Uri.parse(paymentUrl);
      final launched = await launchUrl(
        uri,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        onError?.call('Could not open payment page. Please try again.');
        return;
      }

      // 3. Poll for payment status
      if (paymentLinkId != null) {
        _pollPaymentStatus(paymentLinkId);
      } else {
        // No link ID to poll — user must return manually.
        // We can't confirm payment; treat as pending.
        onError?.call(
            'Payment page opened in a new tab. Please complete the payment there and check your bookings.');
      }
    } catch (e) {
      onError?.call('Payment failed: $e');
    }
  }

  /// Polls the payment link status until paid, expired, or timeout.
  void _pollPaymentStatus(String paymentLinkId) async {
    const maxAttempts = 120; // 10 minutes (5s interval)
    var attempts = 0;

    final statusUrl =
        '${SupabaseConfig.url}/functions/v1/razorpay-payment-status';

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
              body: jsonEncode({'payment_link_id': paymentLinkId}),
            )
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final status = data['status'] as String?;

          if (status == 'paid') {
            final paymentId = data['payment_id'] as String? ?? paymentLinkId;
            onSuccess?.call(paymentId);
            return;
          } else if (status == 'cancelled' || status == 'expired') {
            onError?.call('Payment $status. Please try again.');
            return;
          }
          // else: created / partially_paid — keep polling
        }
      } catch (_) {
        // Network hiccup — keep polling
      }
    }

    onError?.call(
        'Payment timed out. If you completed the payment, it will be confirmed shortly. Check your bookings.');
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
