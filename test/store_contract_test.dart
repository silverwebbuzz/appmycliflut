// Parses Store payloads (document/12-store-api-reference.md). The product
// and cart shapes below were captured from the live store on 2026-10-05.
import 'package:eclinicpro_patient/core/format/format.dart';
import 'package:eclinicpro_patient/features/shop/domain/store_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPaise', () {
    test('drops .00 and groups the Indian way', () {
      expect(formatPaise(49900), '₹499');
      expect(formatPaise(1250), '₹12.50');
      expect(formatPaise(129900), '₹1,299');
      expect(formatPaise(12345600), '₹1,23,456');
      expect(formatPaise(0), '₹0');
    });
  });

  group('store.php', () {
    test('product card keeps the server off_pct for no_promotion items', () {
      final c = ProductCard.fromJson({
        'id': 42,
        'slug': 'baby-food',
        'name': 'Infant formula',
        'price_paise': 19900,
        'mrp_paise': 25000,
        'off_pct': 0,
        'no_promotion': true,
        'price_from': true,
        'in_stock': true,
        'seller': {'name': 'Wellness Mart', 'slug': 'wellness-mart'},
      });
      expect(c.offPct, 0, reason: 'never recompute % off from the MRP');
      expect(c.mrpPaise, 25000);
      expect(c.priceFrom, isTrue);
      expect(c.sellerName, 'Wellness Mart');
      expect(c.image, isNull);
    });

    test('product detail exposes variants by id for add-to-cart', () {
      final p = ProductDetail.fromJson({
        'ok': true,
        'product': {
          'id': 5,
          'slug': 'vit-d3',
          'name': 'Vitamin D3 2000 IU',
          'variants': [
            {'id': 7, 'title': '30 tablets', 'price_paise': 36000, 'mrp_paise': 40000, 'off_pct': 10, 'in_stock': true, 'low_stock': false},
            {'id': 8, 'title': '60 tablets', 'price_paise': 64800, 'mrp_paise': 72000, 'off_pct': 10, 'in_stock': true, 'low_stock': false},
          ],
          'specs': [
            {'label': 'Form', 'value': 'Tablet'},
          ],
          'facts': ['Usually dispatched within 2 days. Delivery across India.'],
          'seller': {'name': 'Test Wellness Pharma', 'slug': 'test-wellness-pharma', 'logo': null, 'rating_avg': 4, 'ships_from': 'Ahmedabad, Gujarat'},
        },
        'reviews': [],
        'related': [],
      });
      expect(p.variants.map((v) => v.id), [7, 8]);
      expect(p.specs.single, ('Form', 'Tablet'));
      expect(p.sellerShipsFrom, 'Ahmedabad, Gujarat');
    });

    test('flattens the live HTML description into text', () {
      final p = ProductDetail.fromJson({
        'product': {
          'id': 1,
          'slug': 's',
          'name': 'n',
          'description': '<p><strong>This is test data</strong> created by the '
              'store test seeder.</p><p>Vitamin D3.</p><ul><li>Quality '
              'checked</li><li>Ships in 2 days</li></ul>',
        },
      });
      expect(p.description,
          'This is test data created by the store test seeder.\nVitamin D3.\n\n• Quality checked\n• Ships in 2 days');
    });

    test('listing round-trips its query through the route', () {
      const q = ListingQuery(scope: 'category', slug: 'nutrition', sub: 'protein', sort: 'price_asc');
      final back = ListingQuery.fromParams(Uri.parse(q.location).queryParameters);
      expect(back.scope, 'category');
      expect(back.sub, 'protein');
      expect(back.sort, 'price_asc');
    });
  });

  group('store_cart.php', () {
    test('parses the documented cart, including problems and coupon', () {
      final cart = Cart.fromJson({
        'cart_token': 'abc',
        'count': 3,
        'groups': [
          {
            'seller': {'id': 4, 'name': 'Wellness Mart', 'slug': 'wellness-mart'},
            'lines': [
              {
                'item_id': 901, 'product_id': 42, 'variant_id': 77, 'slug': 'x', 'name': 'Vit D',
                'qty': 2, 'available_qty': 14, 'max_qty': 10, 'price_paise': 19900,
                'line_total_paise': 39800, 'problem': 'Only 2 left: reduce the quantity',
              },
            ],
          },
        ],
        'summary': {
          'item_count': 3, 'subtotal_paise': 39800, 'shipping_paise': 4900,
          'add_for_free_shipping_paise': 10100, 'tax_included_paise': 4264,
          'grand_total_paise': 44700,
        },
        'coupon': {'code': 'WELCOME10', 'label': '10% off', 'applied': false, 'note': 'Min order ₹999'},
        'can_checkout': false,
        'signed_in': false,
      });
      expect(cart.cartToken, 'abc');
      expect(cart.groups.single.lines.single.problem, isNotNull);
      expect(cart.summary.grandTotalPaise, 44700);
      expect(cart.summary.addForFreeShippingPaise, 10100);
      expect(cart.coupon!.applied, isFalse);
      expect(cart.coupon!.note, 'Min order ₹999');
      expect(cart.canCheckout, isFalse);
    });

    test('an empty live cart is empty', () {
      final cart = Cart.fromJson({
        'cart_token': null,
        'count': 0,
        'groups': [],
        'summary': {'free_shipping_above_paise': 49900, 'add_for_free_shipping_paise': null},
        'coupon': null,
      });
      expect(cart.isEmpty, isTrue);
      expect(cart.coupon, isNull);
    });
  });

  group('store_checkout.php pincode', () {
    test('parses the live lookup; null eta means "could not check"', () {
      final p = PincodeInfo.fromJson({
        'ok': true, 'pin': '500001', 'city': 'Hyderabad',
        'state': 'Telangana', 'serviceable': true, 'eta_days': null,
      });
      expect(p.state, 'Telangana');
      expect(p.serviceable, isTrue);
      expect(p.etaDays, isNull);
    });

    test('serviceable false is kept', () {
      final p = PincodeInfo.fromJson({'pin': '744101', 'serviceable': false, 'eta_days': null});
      expect(p.serviceable, isFalse);
    });
  });

  group('store_orders.php', () {
    test('detail drives actions from flags and options', () {
      final o = OrderDetail.fromJson({
        'order_no': 'ECS1',
        'status_label': 'Shipped',
        'status_tone': 'ok',
        'notice': {'tone': 'ok', 'text': 'Thank you, payment received.'},
        'can_pay': false,
        'packages': [
          {
            'id': 311,
            'seller': {'name': 'S'},
            'items': [
              {'id': 1201, 'name': 'Vit D', 'qty': 2, 'can_review': true, 'returnable_qty': 1},
            ],
            'tracking': {'courier': 'Delhivery', 'awb': '1234', 'url': 'https://x', 'events': [{'status': 'In Transit', 'location': 'Mumbai Hub'}]},
            'documents': [{'id': 88, 'type': 'Tax invoice', 'doc_no': 'I4', 'url': 'https://eclinicpro.com/api/mobile/v1/store_orders.php?action=invoice'}],
            'can_return': true,
          },
        ],
        'totals': {'grand_total_paise': 44700},
        'options': {
          'cancel_reasons': ['Changed my mind'],
          'return_reasons': [{'key': 'damaged', 'label': 'Arrived damaged'}],
          'return_photo_required_for': ['damaged'],
        },
      });
      final p = o.packages.single;
      expect(p.id, 311, reason: 'vendor_order_id for a return');
      expect(p.canReturn, isTrue);
      expect(p.items.single.canReview, isTrue);
      expect(p.tracking!.events.single.location, 'Mumbai Hub');
      expect(p.documents.single.type, 'Tax invoice');
      expect(o.photoRequiredFor, ['damaged']);
      expect(o.noticeText, startsWith('Thank you'));
    });
  });
}
