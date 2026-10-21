// Audit-76 Batch 9 tests: admin config on real tables (M15/M16,
// Admin gaps 1 + 5) and patient coupons (Patient gap 18).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/utils/coupons.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('Tables with no admin UI now have CRUD specs (gap 1)', () {
    final crud = _src('lib/screens/admin/admin_crud_screen.dart');

    test('specs exist for all six tables', () {
      for (final t in [
        'coupons',
        'faqs',
        'legal_pages',
        'slider_media',
        'ads',
        'platform_settings',
      ]) {
        expect(crud.contains("case '$t':"), isTrue, reason: t);
      }
    });

    test('coupon spec carries the full schema shape', () {
      for (final k in [
        'discount_type',
        'discount_value',
        'min_order_amount',
        'max_discount_amount',
        'usage_limit',
        'applicable_for',
        'valid_until',
      ]) {
        expect(crud.contains(k), isTrue, reason: k);
      }
    });

    test('nav + permission keys + team options were added', () {
      final shell = _src('lib/screens/admin/admin_shell.dart');
      for (final t in [
        "'coupons'",
        "'legal_pages'",
        "'slider_media'",
        "'broadcasts'",
      ]) {
        expect(shell.contains(t), isTrue, reason: t);
      }
      final team = _src('lib/screens/admin/admin_team_screen.dart');
      expect(team.contains("('coupons', 'Coupons')"), isTrue);
      expect(team.contains("('broadcasts', 'Broadcasts')"), isTrue);
    });
  });

  group('Broadcasts (gap 1)', () {
    test('repo records broadcasts with the sender', () {
      final repo = _src('lib/services/supabase_repository.dart');
      expect(repo.contains('sendBroadcast'), isTrue);
      expect(repo.contains("'sent_by': _uid"), isTrue);
    });

    test('screen delivers via announcements and logs the row', () {
      final s = _src('lib/screens/admin/admin_config_screens.dart');
      expect(s.contains('class BroadcastsScreen'), isTrue);
      expect(s.contains('createAnnouncement'), isTrue);
      expect(s.contains('sendBroadcast'), isTrue);
    });
  });

  group('Config screens write their real tables (gap 5 / M16)', () {
    final s = _src('lib/screens/admin/admin_config_screens.dart');

    test('commission uses platform_commission_config', () {
      expect(s.contains("loadAdminTable('platform_commission_config')"),
          isTrue);
      expect(s.contains("'flat_fee'"), isTrue);
      expect(s.contains("'service_type'"), isTrue);
    });

    test('subscriptions use subscription_plans with all fields', () {
      expect(s.contains("loadAdminTable('subscription_plans')"), isTrue);
      for (final k in [
        "'description'",
        "'provider_type'",
        "'duration_days'",
        "'features'",
        "'is_active'",
      ]) {
        expect(s.contains(k), isTrue, reason: k);
      }
    });

    test('service areas use the service_areas table', () {
      expect(s.contains("loadAdminTable('service_areas')"), isTrue);
      expect(s.contains("'parent_id'"), isTrue);
      expect(s.contains("'radius_km'"), isTrue);
    });

    test('corporate + healthcare keep the app_config plan list', () {
      expect(s.contains("configKey: 'corporate_plans'"), isTrue);
      expect(s.contains("configKey: 'healthcare_packages'"), isTrue);
    });
  });

  group('Coupon evaluation (pure rules)', () {
    Map<String, dynamic> base() => {
          'code': 'SAVE10',
          'is_active': true,
          'discount_type': 'percentage',
          'discount_value': 10,
          'min_order_amount': 0,
          'applicable_for': 'all',
          'used_count': 0,
        };

    test('percentage discount', () {
      final v = evaluateCoupon(base(), 1000);
      expect(v.ok, isTrue);
      expect(v.discount, 100);
    });

    test('percentage is capped by max_discount_amount', () {
      final v =
          evaluateCoupon({...base(), 'max_discount_amount': 60}, 1000);
      expect(v.discount, 60);
    });

    test('flat discount cannot exceed the subtotal', () {
      final v = evaluateCoupon(
          {...base(), 'discount_type': 'flat', 'discount_value': 500},
          300);
      expect(v.discount, 300);
    });

    test('inactive, expired, wrong-surface and min-order all fail',
        () {
      expect(evaluateCoupon({...base(), 'is_active': false}, 1000).ok,
          isFalse);
      expect(
          evaluateCoupon({...base(), 'valid_until': '2020-01-01'}, 1000)
              .ok,
          isFalse);
      expect(
          evaluateCoupon({...base(), 'applicable_for': 'lab'}, 1000,
                  appliesTo: 'pharmacy')
              .ok,
          isFalse);
      expect(
          evaluateCoupon({...base(), 'min_order_amount': 2000}, 1000)
              .ok,
          isFalse);
    });

    test('usage limit is honoured', () {
      final v = evaluateCoupon(
          {...base(), 'usage_limit': 5, 'used_count': 5}, 1000);
      expect(v.ok, isFalse);
    });
  });

  group('Coupon checkout wiring (Patient gap 18)', () {
    test('both checkouts carry the coupon field + discounted totals',
        () {
      for (final f in [
        'lib/screens/cart_screen.dart',
        'lib/screens/remedoo_checkout_screen.dart',
      ]) {
        final s = _src(f);
        expect(s.contains('CouponField('), isTrue, reason: f);
        expect(s.contains('couponDiscount: discount'), isTrue,
            reason: f);
        expect(s.contains('recordCouponUsage'), isTrue, reason: f);
      }
    });

    test('repo + state + model carry the coupon end-to-end', () {
      final repo = _src('lib/services/supabase_repository.dart');
      expect(repo.contains('fetchCouponByCode'), isTrue);
      expect(repo.contains("'discount_amount': discountAmount"), isTrue);
      expect(repo.contains('coupon_usage'), isTrue);
      final state = _src('lib/state/app_state.dart');
      expect(state.contains('couponDiscount'), isTrue);
      final models = _src('lib/models.dart');
      expect(models.contains('discountAmount'), isTrue);
      expect(
          File('supabase/migration/orders_coupon.sql').existsSync(),
          isTrue);
    });

    test('export covers the remaining datasets', () {
      final s = _src('lib/screens/admin/admin_export_screen.dart');
      for (final t in [
        'legal_pages',
        'slider_media',
        'ads',
        'app_config',
        'support_ticket_messages',
      ]) {
        expect(s.contains(t), isTrue, reason: t);
      }
    });
  });
}
