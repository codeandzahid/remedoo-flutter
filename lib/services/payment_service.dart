import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// In-app UPI/card payment via Razorpay.
/// API keys are configured in Admin Panel > Settings > Payments.
/// Keys are stored in app_config, never hardcoded.
///
/// Supports both mobile (razorpay_flutter plugin) and web
/// (Razorpay JS checkout via checkout.razorpay.com).
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
    if (kIsWeb) return; // Web uses JS checkout, no plugin needed
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

  Map<String, dynamic> _buildOptions({
    required double amount,
    required String description,
    String? contact,
    String? email,
  }) {
    return {
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

    final options = _buildOptions(
      amount: amount,
      description: description,
      contact: contact,
      email: email,
    );

    if (kIsWeb) {
      _openWebCheckout(options);
      return;
    }

    _ensureInitialized();
    try {
      _razorpay!.open(options);
    } catch (e) {
      onPaymentError('Could not open payment: $e');
    }
  }

  /// Opens Razorpay checkout on Flutter web using JS interop.
  void _openWebCheckout(Map<String, dynamic> options) {
    try {
      // Check if Razorpay JS is loaded
      final ctorProp = globalContext.getProperty('Razorpay'.toJS);
      if (ctorProp == null || ctorProp.isUndefinedOrNull) {
        onError?.call(
            'Razorpay checkout not loaded. Please refresh the page and try again. '
            'If it still fails, disable any ad blocker for this site.');
        return;
      }

      // Success handler
      options['handler'] = ((JSAny? response) {
        String paymentId = '';
        try {
          final r = response as JSObject;
          final id = r.getProperty('razorpay_payment_id'.toJS);
          if (id != null) paymentId = (id as JSString).toDart;
        } catch (_) {}
        onSuccess?.call(paymentId);
      }).toJS;

      // Modal dismiss handler (user closed without paying)
      options['modal'] = {
        'ondismiss': (() {
          onError?.call('Payment cancelled');
        }).toJS,
      };

      // new Razorpay(options)
      final jsOptions = _mapToJs(options);
      final ctor = ctorProp as JSFunction;
      final rzp = ctor.callAsConstructor(jsOptions) as JSObject;

      // payment.failed handler
      rzp.callMethod(
        'on'.toJS,
        'payment.failed'.toJS,
        ((JSAny? response) {
          String message = 'Payment failed';
          try {
            final r = response as JSObject;
            final error = r.getProperty('error'.toJS);
            if (error != null && error.isDefinedAndNotNull) {
              final desc = (error as JSObject)
                  .getProperty('description'.toJS);
              if (desc != null && desc.isDefinedAndNotNull) {
                message = (desc as JSString).toDart;
              }
            }
          } catch (_) {}
          onError?.call(message);
        }).toJS,
      );

      // Open the checkout
      rzp.callMethod('open'.toJS);
    } catch (e) {
      onError?.call('Could not open Razorpay: $e');
    }
  }

  /// Recursively converts a Dart map/list to a JS value.
  JSAny _mapToJs(dynamic value) {
    if (value is Map) {
      final obj = JSObject();
      value.forEach((k, v) {
        // Skip functions here; they're already JS via .toJS
        if (v is JSAny) {
          obj.setProperty(k.toString().toJS, v);
        } else {
          obj.setProperty(k.toString().toJS, _mapToJs(v));
        }
      });
      return obj;
    } else if (value is List) {
      final arr = JSArray();
      for (final item in value) {
        arr.add(_mapToJs(item));
      }
      return arr;
    } else if (value is String) {
      return value.toJS;
    } else if (value is num) {
      return value.toJS;
    } else if (value is bool) {
      return value.toJS;
    } else if (value is JSAny) {
      return value;
    }
    throw ArgumentError('Unsupported value in Razorpay options: $value');
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
