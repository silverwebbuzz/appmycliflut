import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../domain/store_models.dart';
import 'store_repository.dart';

/// The one cart every Shop surface reads (tab badge, floating cart bar,
/// product page, cart screen), so a change anywhere shows everywhere.
///
/// Every cart action returns the whole cart, which replaces [CartState.cart]
/// as-is — the app re-renders from the server and never recomputes totals.
class CartState {
  const CartState({this.cart = Cart.empty, this.loaded = false, this.busy = false});

  final Cart cart;

  /// False until the first `get` has answered.
  final bool loaded;

  /// An add/set/coupon call is in flight.
  final bool busy;

  CartState copyWith({Cart? cart, bool? loaded, bool? busy}) => CartState(
        cart: cart ?? this.cart,
        loaded: loaded ?? this.loaded,
        busy: busy ?? this.busy,
      );
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    Future.microtask(refresh);
    return const CartState();
  }

  StoreRepository get _repo => ref.read(storeRepositoryProvider);

  /// Re-reads the cart. Also what merges a guest cart after sign-in.
  Future<ApiResult<Cart>> refresh() => _run(_repo.cart(), quiet: true);

  Future<ApiResult<Cart>> add(int variantId, {int qty = 1}) =>
      _run(_repo.add(variantId, qty: qty));

  Future<ApiResult<Cart>> setQty(int itemId, int qty) =>
      _run(_repo.setQty(itemId, qty));

  Future<ApiResult<Cart>> applyCoupon(String code) => _run(_repo.coupon(code));

  /// Adopts a cart that arrived with another response (checkout's
  /// `cart_needs_attention`, a failed `place`).
  void adopt(Cart cart) => state = state.copyWith(cart: cart, loaded: true);

  Future<ApiResult<Cart>> _run(Future<ApiResult<Cart>> call, {bool quiet = false}) async {
    if (!quiet) state = state.copyWith(busy: true);
    final r = await call;
    state = switch (r) {
      ApiSuccess(:final value) => state.copyWith(cart: value, loaded: true, busy: false),
      ApiFailure() => state.copyWith(loaded: true, busy: false),
    };
    return r;
  }
}

final cartControllerProvider =
    NotifierProvider<CartController, CartState>(CartController.new);

/// Item count for badges.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartControllerProvider.select((s) => s.cart.count)),
);
