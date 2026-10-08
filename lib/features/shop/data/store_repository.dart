import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/points_models.dart';
import '../domain/store_models.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  return StoreRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  );
});

/// Every Store route (doc 12): catalog, cart, checkout, orders, wishlist.
///
/// Also owns the guest-cart token lifecycle, so screens never touch it: a
/// non-null `cart_token` in any cart response is stored, and once a response
/// says `signed_in` the server has merged the guest cart and the stored
/// token is dropped.
class StoreRepository {
  StoreRepository(this._api, this._session);

  final ApiClient _api;
  final SessionStorage _session;

  ApiResult<T> _map<T>(
    ApiResult<Map<String, dynamic>> r,
    T Function(Map<String, dynamic>) parse,
  ) =>
      switch (r) {
        ApiSuccess(:final value) => ApiSuccess(parse(value)),
        ApiFailure(:final error, :final statusCode, :final message) =>
          ApiFailure(error: error, statusCode: statusCode, message: message),
      };

  // ----- catalog ----------------------------------------------------------

  Future<ApiResult<StoreHome>> home() async =>
      _map(await _api.get('/store.php', queryParameters: {'action': 'home'}),
          StoreHome.fromJson);

  Future<ApiResult<List<Department>>> categories() async => _map(
        await _api.get('/store.php', queryParameters: {'action': 'categories'}),
        (j) => (j['departments'] is List ? j['departments'] as List : const [])
            .whereType<Map>()
            .map((e) => Department.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  Future<ApiResult<ListingPage>> listing(ListingQuery q, {int page = 1}) async =>
      _map(
        await _api.get('/store.php', queryParameters: {
          'action': 'listing',
          ...q.toParams(),
          'page': page,
        }),
        ListingPage.fromJson,
      );

  Future<ApiResult<ProductDetail>> product(String slug) async => _map(
        await _api.get('/store.php',
            queryParameters: {'action': 'product', 'slug': slug}),
        ProductDetail.fromJson,
      );

  // ----- cart -------------------------------------------------------------

  Future<ApiResult<Cart>> _cart(ApiResult<Map<String, dynamic>> r) async {
    final mapped = _map(r, (j) => Cart.fromJson(
          j['cart'] is Map ? Map<String, dynamic>.from(j['cart'] as Map) : const {},
        ));
    if (mapped case ApiSuccess(:final value)) await _syncCartToken(value);
    return mapped;
  }

  Future<void> _syncCartToken(Cart cart) async {
    if (cart.cartToken != null) {
      await _session.saveCartToken(cart.cartToken!);
    } else if (cart.signedIn) {
      // Sent alongside the Bearer token, so the server has merged it.
      await _session.clearCartToken();
    }
  }

  Future<ApiResult<Cart>> cart() async =>
      _cart(await _api.get('/store_cart.php', queryParameters: {'action': 'get'}));

  /// Adds by **variant** id. Adding again increases the quantity.
  Future<ApiResult<Cart>> add(int variantId, {int qty = 1}) async => _cart(
        await _api.post('/store_cart.php',
            queryParameters: {'action': 'add'},
            data: {'variant_id': variantId, 'qty': qty}),
      );

  /// `qty: 0` removes the line.
  Future<ApiResult<Cart>> setQty(int itemId, int qty) async => _cart(
        await _api.post('/store_cart.php',
            queryParameters: {'action': 'set'},
            data: {'item_id': itemId, 'qty': qty}),
      );

  /// `""` removes the coupon.
  Future<ApiResult<Cart>> coupon(String code) async => _cart(
        await _api.post('/store_cart.php',
            queryParameters: {'action': 'coupon'}, data: {'code': code}),
      );

  // ----- checkout ---------------------------------------------------------

  /// `409 cart_empty` / `cart_needs_attention` → back to the cart.
  Future<ApiResult<CheckoutSummary>> checkoutSummary() async {
    final r = _map(
      await _api.get('/store_checkout.php', queryParameters: {'action': 'summary'}),
      CheckoutSummary.fromJson,
    );
    if (r case ApiSuccess(:final value)) await _syncCartToken(value.cart);
    return r;
  }

  Future<ApiResult<AddressBook>> addresses() async => _map(
        await _api.get('/store_checkout.php',
            queryParameters: {'action': 'addresses'}),
        AddressBook.fromJson,
      );

  /// `422 invalid_address` + `message`. A new address becomes the default.
  Future<ApiResult<Address>> addAddress(Map<String, String> fields) async => _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'address_add'}, data: fields),
        (j) => Address.fromJson(
          j['address'] is Map ? Map<String, dynamic>.from(j['address'] as Map) : const {},
        ),
      );

  /// Fields not sent keep their saved value; `""` clears an optional one.
  /// Does not change which address is the default.
  Future<ApiResult<Address>> updateAddress(int id, Map<String, String> fields) async =>
      _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'address_update'},
            data: {'address_id': id, ...fields}),
        (j) => Address.fromJson(
          j['address'] is Map ? Map<String, dynamic>.from(j['address'] as Map) : const {},
        ),
      );

  /// Returns the whole list, default first.
  Future<ApiResult<List<Address>>> setDefaultAddress(int id) async => _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'address_set_default'},
            data: {'address_id': id}),
        (j) => AddressBook.fromJson(j).addresses,
      );

  /// Public. `404 pin_not_found` must not block the form: the customer then
  /// types city and state themselves.
  Future<ApiResult<PincodeInfo>> pincode(String pin) async => _map(
        await _api.get('/store_checkout.php',
            queryParameters: {'action': 'pincode', 'pin': pin}),
        PincodeInfo.fromJson,
      );

  Future<ApiResult<void>> removeAddress(int id) async => _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'address_remove'},
            data: {'address_id': id}),
        (_) {},
      );

  /// Reserves stock and creates an *Awaiting payment* order. Retrying with
  /// the same [checkoutKey] returns the same order, never a second one.
  Future<ApiResult<PlacedOrder>> place({
    required String checkoutKey,
    required int addressId,
    required String contactName,
    required String contactPhone,
    String? contactEmail,
    required int clientTotalPaise,
  }) async =>
      _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'place'},
            data: {
              'checkout_key': checkoutKey,
              'address_id': addressId,
              'contact_name': contactName,
              'contact_phone': contactPhone,
              if (contactEmail != null && contactEmail.isNotEmpty)
                'contact_email': contactEmail,
              'client_total_paise': clientTotalPaise,
            }),
        PlacedOrder.fromJson,
      );

  /// Razorpay options to pass straight to the SDK's `open()`.
  Future<ApiResult<Map<String, dynamic>>> payStart(String orderNo) async => _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'pay_start'},
            data: {'order_no': orderNo}),
        (j) => j['checkout'] is Map
            ? Map<String, dynamic>.from(j['checkout'] as Map)
            : const <String, dynamic>{},
      );

  Future<ApiResult<PayVerdict>> payVerify({
    required String orderNo,
    required String? razorpayOrderId,
    required String? paymentId,
    required String? signature,
  }) async =>
      _map(
        await _api.post('/store_checkout.php',
            queryParameters: {'action': 'pay_verify'},
            data: {
              'order_no': orderNo,
              'razorpay_order_id': razorpayOrderId,
              'razorpay_payment_id': paymentId,
              'razorpay_signature': signature,
            }),
        (j) => PayVerdict(
          state: (j['state'] ?? 'unknown').toString(),
          paid: j['paid'] == true,
        ),
      );

  // ----- orders -----------------------------------------------------------

  Future<ApiResult<List<OrderListItem>>> orders() async => _map(
        await _api.get('/store_orders.php', queryParameters: {'action': 'list'}),
        (j) => (j['orders'] is List ? j['orders'] as List : const [])
            .whereType<Map>()
            .map((e) => OrderListItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  OrderDetail _order(Map<String, dynamic> j) => OrderDetail.fromJson(
        j['order'] is Map ? Map<String, dynamic>.from(j['order'] as Map) : const {},
      );

  Future<ApiResult<OrderDetail>> order(String orderNo) async => _map(
        await _api.get('/store_orders.php',
            queryParameters: {'action': 'detail', 'order_no': orderNo}),
        _order,
      );

  /// Cancels an unpaid order (releases the reserved stock).
  Future<ApiResult<OrderDetail>> cancelOrder(String orderNo) async => _map(
        await _api.post('/store_orders.php',
            queryParameters: {'action': 'cancel'}, data: {'order_no': orderNo}),
        _order,
      );

  /// Returns the server's customer-facing message.
  Future<ApiResult<String>> cancelItems({
    required String orderNo,
    required Map<int, int> items,
    required String reason,
  }) async =>
      _map(
        await _api.post('/store_orders.php',
            queryParameters: {'action': 'cancel_items'},
            data: {
              'order_no': orderNo,
              'items': {for (final e in items.entries) '${e.key}': e.value},
              'reason': reason,
            }),
        (j) => (j['message'] ?? 'Items cancelled.').toString(),
      );

  Future<ApiResult<String>> review({
    required int orderItemId,
    required int rating,
    String? title,
    String? body,
  }) async =>
      _map(
        await _api.post('/store_orders.php',
            queryParameters: {'action': 'review'},
            data: {
              'order_item_id': orderItemId,
              'rating': rating,
              'title': title ?? '',
              'body': body ?? '',
            }),
        (j) => (j['message'] ?? 'Thanks for your review!').toString(),
      );

  /// Multipart: photo parts are `photos[]` (up to 3).
  Future<ApiResult<String>> requestReturn({
    required int vendorOrderId,
    required Map<int, int> items,
    required String reason,
    String? note,
    List<String> photoPaths = const [],
  }) async {
    final form = FormData();
    form.fields
      ..add(MapEntry('vendor_order_id', '$vendorOrderId'))
      ..add(MapEntry('reason', reason))
      ..add(MapEntry('note', note ?? ''))
      ..add(MapEntry(
        'items',
        jsonEncode({for (final e in items.entries) '${e.key}': e.value}),
      ));
    try {
      for (final p in photoPaths) {
        form.files.add(MapEntry('photos[]', await MultipartFile.fromFile(p)));
      }
    } on Exception {
      return const ApiFailure(
        error: 'file_unreadable',
        message: 'Could not read one of the photos. Please pick it again.',
      );
    }
    return _map(
      await _api.postForm('/store_orders.php', form,
          queryParameters: {'action': 'return'}),
      (j) => (j['message'] ?? 'Return requested.').toString(),
    );
  }

  // ----- points & refer ---------------------------------------------------

  /// `store_points.php?action=summary` (Bearer). `enabled: false` means
  /// points are off: hide every points surface.
  Future<ApiResult<PointsSummary>> pointsSummary() async => _map(
        await _api.get('/store_points.php', queryParameters: {'action': 'summary'}),
        PointsSummary.fromJson,
      );

  // ----- wishlist ---------------------------------------------------------

  Future<ApiResult<List<ProductCard>>> wishlist() async => _map(
        await _api.get('/store_wishlist.php', queryParameters: {'action': 'list'}),
        (j) => (j['products'] is List ? j['products'] as List : const [])
            .whereType<Map>()
            .map((e) => ProductCard.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Returns the new saved state.
  Future<ApiResult<bool>> toggleWishlist(int productId) async => _map(
        await _api.post('/store_wishlist.php',
            queryParameters: {'action': 'toggle'},
            data: {'product_id': productId}),
        (j) => j['saved'] == true,
      );
}
