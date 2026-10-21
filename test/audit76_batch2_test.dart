import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/services/supabase_repository.dart';
import 'package:remedoo_app/state/app_state.dart';

/// Form-pages audit Batch 2 — reviews persistence (M6), refunds
/// unification (M8 + Admin 2/4, Patient 6/15, Panelist 13) and
/// support vocabulary (M24, Admin 2, Patient 2).
void main() {
  group('refund status vocabulary (M8)', () {
    test('legacy admin values fold into processing', () {
      expect(AppState.normaliseRefundStatus('approved'), 'processing');
      expect(AppState.normaliseRefundStatus('processed'), 'processing');
    });

    test('schema values pass through', () {
      expect(AppState.normaliseRefundStatus('requested'), 'requested');
      expect(AppState.normaliseRefundStatus('processing'), 'processing');
      expect(AppState.normaliseRefundStatus('completed'), 'completed');
      expect(AppState.normaliseRefundStatus('rejected'), 'rejected');
    });

    test('unknown / empty falls back to requested', () {
      expect(AppState.normaliseRefundStatus(''), 'requested');
      expect(AppState.normaliseRefundStatus(null), 'requested');
      expect(AppState.normaliseRefundStatus('weird'), 'requested');
    });
  });

  group('support ticket vocabulary (M24)', () {
    test('stored opened normalises to open on read', () {
      final row = SupabaseRepository.normaliseTicketRow(
          {'id': '1', 'status': 'opened'});
      expect(row['status'], 'open');
    });

    test('other statuses are untouched', () {
      for (final s in ['open', 'in_progress', 'resolved', 'closed']) {
        final row =
            SupabaseRepository.normaliseTicketRow({'status': s});
        expect(row['status'], s);
      }
    });

    test('admin chat no longer writes the opened status', () {
      final src = File('lib/screens/admin/admin_support_chat_screen.dart')
          .readAsStringSync();
      expect(src.contains("'status': 'opened'"), isFalse);
      expect(src.contains("updateSupportTicket(_ticketId, {'status': 'opened'}"),
          isFalse);
    });

    test('patient query form uses the schema categories + urgent', () {
      final src =
          File('lib/screens/new_query_sheet.dart').readAsStringSync();
      for (final v in [
        "'appointment'",
        "'order'",
        "'payment'",
        "'technical'",
        "'general'",
        "'urgent'",
      ]) {
        expect(src.contains(v), isTrue, reason: 'missing $v');
      }
      expect(src.contains("('Refund',"), isFalse);
      expect(src.contains("('Account',"), isFalse);
    });
  });

  group('review + refund models carry the backend link (M6/M8)', () {
    test('Review holds row id, provider and admin notes', () {
      final r = Review(
        appointmentId: 'a1',
        stars: 5,
        comment: 'Great',
        id: 'row-1',
        providerId: 'doc-1',
        providerType: 'doctor',
        adminNotes: 'verified',
      );
      expect(r.id, 'row-1');
      expect(r.providerId, 'doc-1');
      expect(r.providerType, 'doctor');
      expect(r.adminNotes, 'verified');
      expect(r.hidden, isFalse);
    });

    test('RefundRequest can reference an appointment', () {
      final r = RefundRequest(
        id: 'RF1',
        orderId: '',
        appointmentId: 'appt-9',
        amount: 500,
        reason: 'cancelled',
        date: DateTime(2026, 1, 1),
      );
      expect(r.appointmentId, 'appt-9');
      expect(r.status, 'requested');
    });
  });

  group('admin refunds write the schema vocabulary (M8)', () {
    test('admin refunds screen approves into processing, never approved',
        () {
      final src = File('lib/screens/admin/admin_ops_screens.dart')
          .readAsStringSync();
      expect(src.contains("'processing'"), isTrue);
      // The old out-of-vocabulary write must be gone.
      expect(src.contains("id,\n                              'approved'"),
          isFalse);
    });
  });
}
