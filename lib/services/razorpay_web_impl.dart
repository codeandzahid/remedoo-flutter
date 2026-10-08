// Web implementation of Razorpay checkout using the official
// Razorpay JS SDK (https://checkout.razorpay.com/v1/checkout.js).
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// Loads the Razorpay checkout.js script if not already loaded.
Future<void> _ensureCheckoutJs() async {
  // Check if Razorpay is already available on window
  if (globalContext.has('Razorpay')) return;

  final completer = Completer<void>();
  final script = web.HTMLScriptElement()
    ..src = 'https://checkout.razorpay.com/v1/checkout.js'
    ..async = true
    ..onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete();
    })
    ..onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError('Failed to load Razorpay checkout.js');
      }
    });
  web.document.head!.append(script);

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () =>
        throw 'Razorpay checkout.js load timed out. Check internet connection.',
  );
}

/// Opens Razorpay checkout on Flutter web using JS interop.
void openRazorpayWeb(
  Map<String, dynamic> options, {
  required void Function(String paymentId) onPaymentSuccess,
  required void Function(String error) onPaymentError,
}) async {
  try {
    await _ensureCheckoutJs();

    // Success handler
    options['handler'] = ((JSAny? response) {
      String paymentId = '';
      try {
        final r = response as JSObject;
        final id = r.getProperty('razorpay_payment_id'.toJS);
        if (id != null) paymentId = (id as JSString).toDart;
      } catch (_) {}
      onPaymentSuccess(paymentId);
    }).toJS;

    // Modal dismiss handler (user closed without paying)
    options['modal'] = {
      'ondismiss': (() {
        onPaymentError('Payment cancelled');
      }).toJS,
    };

    // Convert options to JS object
    final jsOptions = _mapToJsObject(options);

    // new Razorpay(options)
    final razorpayCtor =
        globalContext.getProperty('Razorpay'.toJS) as JSFunction;
    final rzp = razorpayCtor
        .callAsConstructor(jsOptions) as JSObject;

    // payment.failed handler
    rzp.callMethod('on'.toJS, 'payment.failed'.toJS,
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
      onPaymentError(message);
    }).toJS);

    // Open the checkout
    rzp.callMethod('open'.toJS);
  } catch (e) {
    onPaymentError('Could not open Razorpay: $e');
  }
}

/// Recursively converts a Dart map/list to a JS object.
JSAny _mapToJsObject(dynamic value) {
  if (value is Map) {
    final obj = JSObject();
    value.forEach((k, v) {
      obj.setProperty(k.toString().toJS, _mapToJsObject(v));
    });
    return obj;
  } else if (value is List) {
    final arr = JSArray();
    for (final item in value) {
      arr.add(_mapToJsObject(item));
    }
    return arr;
  } else if (value is String) {
    return value.toJS;
  } else if (value is num) {
    return value.toJS;
  } else if (value is bool) {
    return value.toJS;
  } else if (value == null) {
    // Should not happen (options map filters nulls), but return
    // undefined-equivalent via an empty JS object property skip.
    throw ArgumentError('Null value in Razorpay options');
  }
  // Already a JS value (e.g. function from .toJS)
  return value as JSAny;
}
