// Points & Refer (document/12-store-api-reference.md, "Points & Refer").
import 'package:eclinicpro_patient/core/network/api_result.dart';
import 'package:eclinicpro_patient/core/theme/app_theme.dart';
import 'package:eclinicpro_patient/features/shop/data/points_providers.dart';
import 'package:eclinicpro_patient/features/shop/domain/points_models.dart';
import 'package:eclinicpro_patient/features/shop/domain/store_models.dart';
import 'package:eclinicpro_patient/features/shop/presentation/points_screen.dart';
import 'package:eclinicpro_patient/features/shop/presentation/shop_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The summary example from doc 12, verbatim.
const _summary = {
  'ok': true,
  'enabled': true,
  'balance': {'available': 150, 'pending': 200, 'welcome': 100, 'standard': 50},
  'lots': [
    {'kind': 'welcome', 'status': 'available', 'points': 100, 'note': 'Welcome points',
     'available_at': null, 'expires_at': '2027-04-05 10:12:00'},
    {'kind': 'referral', 'status': 'pending', 'points': 100,
     'note': "Waiting for Priya's first order to be delivered", 'available_at': null, 'expires_at': null},
    {'kind': 'loyalty', 'status': 'pending', 'points': 50,
     'note': 'Available after the return window', 'available_at': '2026-10-14 18:00:00', 'expires_at': null},
  ],
  'history': [
    {'type': 'spend', 'kind': 'welcome', 'points': -100, 'note': null,
     'order_no': 'ECS261006-7K3MQ', 'at': '2026-10-06 11:02:41'},
  ],
  'rules': {'welcome_points': 100, 'welcome_min_order_paise': 50000, 'referral_points': 100,
            'redeem_cap_pct': 10, 'loyalty_pct': 10, 'expiry_days': 180, 'return_window_days': 7},
  'referral': {'code': 'ECP-RAHUL7K', 'active': true, 'link': 'https://eclinicpro.com/r/ECP-RAHUL7K',
               'friends': [{'name': 'Priya', 'status': 'signed_up', 'joined_at': '2026-10-03 09:00:00'}],
               'rewarded': 0},
  'share_text': 'Join me on eClinicPro! Sign up with my code ECP-RAHUL7K and get 100 welcome points …',
};

Map<String, Object?> _cart({Map<String, Object?>? points, int pointsOff = 0}) => {
      'count': 3,
      'groups': [],
      'summary': {'subtotal_paise': 39800, 'discount_paise': 0,
                  'points_discount_paise': pointsOff, 'shipping_paise': 4900,
                  'grand_total_paise': 44700 - pointsOff},
      'coupon': null,
      'points': points,
      'can_checkout': true,
      'signed_in': true,
    };

void main() {
  group('PointsSummary', () {
    test('parses the doc 12 example', () {
      final s = PointsSummary.fromJson(_summary);
      expect(s.enabled, isTrue);
      expect(s.balance.available, 150);
      expect(s.balance.pending, 200);
      expect(s.lots.map((l) => l.kind), ['welcome', 'referral', 'loyalty']);
      expect(s.history.single.points, -100);
      expect(s.rules.welcomeMinOrderPaise, 50000);
      expect(s.referral.code, 'ECP-RAHUL7K');
      expect(s.referral.friends.single.status, 'signed_up');
      expect(s.shareText, startsWith('Join me'));
    });

    test('"enabled: false and nothing else" parses to a safe, hidden summary', () {
      final s = PointsSummary.fromJson({'ok': true, 'enabled': false});
      expect(s.enabled, isFalse);
      expect(s.lots, isEmpty);
      expect(s.referral.active, isFalse);
      expect(rulesText(s.rules), isEmpty);
    });

    test('rules text comes only from the server numbers', () {
      final text = rulesText(PointsSummary.fromJson(_summary).rules);
      expect(text, contains('₹500 or more'));
      expect(text, contains('up to 10% of an order'));
      expect(text, contains('7 days after delivery'));
      // Admin changes flow straight through.
      final changed = rulesText(const PointsRules(
          welcomeMinOrderPaise: 99900, redeemCapPct: 25, loyaltyPct: 5, returnWindowDays: 14));
      expect(changed, contains('₹999'));
      expect(changed, contains('25%'));
      expect(changed, contains('14 days'));
    });

    test('lot lines and labels follow doc 12', () {
      final lots = PointsSummary.fromJson(_summary).lots;
      expect(lotStatusLine(lots[0]), 'Ready to use · Expires 05 Apr 2027');
      expect(lotStatusLine(lots[1]), "Pending · Waiting for Priya's first order to be delivered");
      expect(lotStatusLine(lots[2]),
          'Pending · Available after the return window · from 14 Oct 2026');
      expect(lotKindLabel('admin'), 'Bonus');
      expect(friendStatusLabel('qualified'), 'Delivered · in return window');
      expect(historyTypeLabel('spend'), 'Used on order');
      expect(historyTypeLabel('reverse'), 'Cancelled');
    });
  });

  group('Cart points', () {
    test('points is null for guests / points off', () {
      final c = Cart.fromJson(_cart());
      expect(c.points, isNull);
      expect(c.summary.pointsDiscountPaise, 0);
      expect(pointsDiscountLabel(c), isNull);
    });

    test('parses the doc 12 cart points object', () {
      final c = Cart.fromJson(_cart(points: {
        'kind': null, 'used': 0, 'available': 0, 'pending': 0, 'welcome': 100,
        'welcome_add_paise': 10200, 'earns': 39,
      }));
      expect(c.points!.welcomeAddPaise, 10200);
      expect(c.points!.earns, 39);
      expect(pointsDiscountLabel(c), isNull, reason: 'no discount applied');
    });

    test('labels welcome vs other points from kind, amount from the server', () {
      final w = Cart.fromJson(_cart(
          pointsOff: 10000,
          points: {'kind': 'welcome', 'used': 100, 'welcome': 100, 'earns': 0}));
      expect(pointsDiscountLabel(w), 'Welcome points (100 pts)');
      expect(w.summary.grandTotalPaise, 34700, reason: 'taken as sent, not computed');
      final o = Cart.fromJson(_cart(
          pointsOff: 3900, points: {'kind': 'loyalty', 'used': 39}));
      expect(pointsDiscountLabel(o), 'eClinicPro Points (39 pts)');
    });

    test('order totals carry points used', () {
      final d = OrderDetail.fromJson({
        'order_no': 'ECS1',
        'totals': {'grand_total_paise': 34700, 'points_used': 100, 'points_discount_paise': 10000},
      });
      expect(d.pointsUsed, 100);
      expect(d.pointsDiscountPaise, 10000);
      expect(OrderDetail.fromJson({'order_no': 'X', 'totals': {}}).pointsUsed, 0);
    });
  });

  group('PointsScreen layout', () {
    // A long note, a long code and many friends to stress wrapping.
    final busy = PointsSummary.fromJson({
      ..._summary,
      'lots': [
        for (final l in _summary['lots'] as List) l,
        {'kind': 'admin', 'status': 'pending', 'points': 25,
         'note': 'A very long note from the clinic team explaining exactly why these '
             'bonus points are still pending and when they will be ready to use',
         'available_at': '2026-12-31 23:59:00', 'expires_at': null},
      ],
      'referral': {
        ...(_summary['referral'] as Map),
        'code': 'ECP-AVERYLONGCODE2026',
        'friends': [
          for (final s in ['signed_up', 'qualified', 'rewarded', 'rejected'])
            {'name': 'Friend with a fairly long name', 'status': s, 'joined_at': '2026-10-03 09:00:00'},
        ],
      },
    });

    for (final width in [360.0, 430.0, 800.0]) {
      testWidgets('lays out without overflow at ${width.toInt()}dp', (tester) async {
        tester.view.physicalSize = Size(width * 3, 2400 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            pointsSummaryProvider.overrideWith((ref) async => ApiSuccess(busy)),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const PointsScreen()),
        ));
        await tester.pumpAndSettle();
        expect(find.text('ECP-AVERYLONGCODE2026'), findsOneWidget);
        expect(find.text('points ready to use'), findsOneWidget);
        // Status pills render uppercase.
        expect(find.text('NOT ELIGIBLE'), findsOneWidget);
        // Expanding the history must not overflow either.
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        expect(find.text('Used on order'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('locked referral shows the unlock message, not a code', (tester) async {
      final locked = PointsSummary.fromJson({
        ..._summary,
        'referral': {'code': null, 'active': false, 'link': null, 'friends': [], 'rewarded': 0},
      });
      tester.view.physicalSize = const Size(430 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [pointsSummaryProvider.overrideWith((ref) async => ApiSuccess(locked))],
        child: MaterialApp(theme: AppTheme.light, home: const PointsScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('unlocks after your first store order'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
    });
  });
}
