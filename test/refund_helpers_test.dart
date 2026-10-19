import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/utils/refunds.dart';

void main() {
  group('refundStatusMessage', () {
    test('requested shows amount and the 48h / 3 working days line', () {
      final msg = refundStatusMessage(refundStatus: 'requested', amount: 500);
      expect(msg, contains('₹500'));
      expect(msg, contains('48 hours to 3 working days'));
      expect(msg, contains('Refund requested'));
    });

    test('refunded shows amount, UTR and date as proof', () {
      final msg = refundStatusMessage(
        refundStatus: 'refunded',
        amount: 1000,
        refundAt: DateTime(2026, 10, 21),
        refundUtr: '123456789012',
      );
      expect(msg, 'Refunded ₹1,000 · UTR 123456789012 · 21/10/2026');
    });

    test('no refund state means no message', () {
      expect(refundStatusMessage(refundStatus: null, amount: 10), isNull);
      expect(refundStatusMessage(refundStatus: '', amount: 10), isNull);
    });
  });

  group('isValidRefundUtr', () {
    test('accepts 9 to 22 digits', () {
      expect(isValidRefundUtr('123456789'), isTrue);
      expect(isValidRefundUtr('123456789012'), isTrue);
      expect(isValidRefundUtr('1' * 22), isTrue);
    });

    test('rejects short, long and non-numeric values', () {
      expect(isValidRefundUtr('12345678'), isFalse);
      expect(isValidRefundUtr('1' * 23), isFalse);
      expect(isValidRefundUtr('UTR123456789'), isFalse);
      expect(isValidRefundUtr(''), isFalse);
    });
  });

  group('Remedoo Pay totals', () {
    final sessions = <Map<String, dynamic>>[
      {'status': 'SUCCESS', 'amount_paise': 50000},
      {'status': 'SUCCESS', 'amount_paise': 100000},
      {'status': 'ACTIVE', 'amount_paise': 25000},
      {'status': 'EXPIRED', 'amount_paise': 99900},
    ];

    test('total received sums SUCCESS sessions only', () {
      expect(totalReceivedPaise(sessions), 150000);
      expect(receivedCount(sessions), 2);
    });
  });

  group('sessionCustomerUpi', () {
    test('prefers the payer_vpa column', () {
      expect(
        sessionCustomerUpi({
          'payer_vpa': 'cust@okhdfc',
          'customer': {'upi': 'other@okicici'},
        }),
        'cust@okhdfc',
      );
    });

    test('falls back to the customer json upi, else null', () {
      expect(
        sessionCustomerUpi({
          'customer': {'upi': 'cust@okicici'},
        }),
        'cust@okicici',
      );
      expect(
        sessionCustomerUpi({
          'customer': {'name': 'Asha'},
        }),
        isNull,
      );
      expect(sessionCustomerUpi(const {}), isNull);
    });
  });

  group('refundUpiLink', () {
    test('prefills customer UPI, amount and refund note', () {
      final link = refundUpiLink(
        customerUpi: 'cust@okhdfc',
        customerName: 'Asha Khan',
        amount: 500,
        ref: 'ORD123',
      );
      expect(link, startsWith('upi://pay?'));
      expect(link, contains('pa=cust%40okhdfc'));
      expect(link, contains('am=500.00'));
      expect(link, contains('tn=Refund%20ORD123'));
    });
  });

  group('isRefundOverdue', () {
    final now = DateTime(2026, 10, 22, 12);

    test('requested for more than 48 hours is overdue', () {
      expect(
        isRefundOverdue(
          refundStatus: 'requested',
          requestedAt: DateTime(2026, 10, 20, 11),
          now: now,
        ),
        isTrue,
      );
    });

    test('recent requests and finished refunds are not overdue', () {
      expect(
        isRefundOverdue(
          refundStatus: 'requested',
          requestedAt: DateTime(2026, 10, 21, 12),
          now: now,
        ),
        isFalse,
      );
      expect(
        isRefundOverdue(
          refundStatus: 'refunded',
          requestedAt: DateTime(2026, 10, 1),
          now: now,
        ),
        isFalse,
      );
    });

    test('falls back to created_at when requested_at is missing', () {
      expect(
        isRefundOverdue(
          refundStatus: 'requested',
          createdAt: DateTime(2026, 10, 19),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('isPaidOnline helpers', () {
    MedOrder order({String? method, String payment = 'cod'}) => MedOrder(
      id: 'o1',
      pharmacyName: 'Pharmacy',
      items: const [],
      subtotal: 0,
      deliveryFee: 0,
      total: 0,
      address: '',
      payment: payment,
      placedAt: DateTime(2026),
      paymentMethod: method,
    );

    test('backend payment_method wins over legacy text', () {
      expect(order(method: 'online').isPaidOnline, isTrue);
      expect(order(method: 'cod', payment: 'Pay Online').isPaidOnline, isFalse);
    });

    test('legacy text is the fallback', () {
      expect(order(payment: 'Pay Online').isPaidOnline, isTrue);
      expect(order(payment: 'Cash on Delivery').isPaidOnline, isFalse);
    });

    test('appointment payment label decides', () {
      Appointment appt(String payment) => Appointment(
        id: 'a1',
        doctorName: 'Dr',
        specialty: '',
        place: '',
        date: DateTime(2026),
        timeLabel: '10:00',
        fee: 100,
        payment: payment,
      );
      expect(appt('Pay Online').isPaidOnline, isTrue);
      expect(appt('At Clinic').isPaidOnline, isFalse);
    });
  });
}
