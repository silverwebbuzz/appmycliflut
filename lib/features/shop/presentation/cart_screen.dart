import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/network/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/cart_controller.dart';
import '../domain/store_models.dart';
import 'shop_widgets.dart';

/// Cart — `store_cart.php`. Renders exactly what the server returns.
///
/// Lines are grouped per seller (one package each). A line with a
/// `problem` is excluded from the totals and blocks checkout until it is
/// fixed or removed. Signed out, the CTA becomes "Sign in to check out";
/// the guest cart is merged into the account on the next cart call.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _coupon = TextEditingController();
  String? _couponError;

  @override
  void initState() {
    super.initState();
    // Fresh prices and stock every time the cart opens.
    Future.microtask(() => ref.read(cartControllerProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _coupon.dispose();
    super.dispose();
  }

  Future<void> _setQty(CartLine l, int qty) async {
    final r = await ref.read(cartControllerProvider.notifier).setQty(l.itemId, qty);
    if (r is ApiFailure<Cart> && mounted) showAppSnack(context, friendlyMessage(r));
  }

  Future<void> _applyCoupon(String code) async {
    setState(() => _couponError = null);
    final r = await ref.read(cartControllerProvider.notifier).applyCoupon(code.trim());
    if (!mounted) return;
    if (r is ApiFailure<Cart>) {
      setState(() => _couponError = friendlyMessage(r));
    } else {
      _coupon.clear();
    }
  }

  Future<void> _checkout(Cart cart) async {
    final signedIn =
        cart.signedIn || await ref.read(sessionStorageProvider).hasToken();
    if (!mounted) return;
    if (!signedIn) {
      await promptSignIn(
        context,
        reason: 'Your cart is saved. Sign in to check out — it will be '
            'moved to your account.',
      );
      return;
    }
    context.push('/shop/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartControllerProvider);
    final cart = state.cart;

    return AppSubPage(
      title: 'Cart',
      fallbackRoute: '/shop',
      onRefresh: () => ref.read(cartControllerProvider.notifier).refresh(),
      bottomBar: cart.isEmpty
          ? null
          : AppPrimaryButton(
              label: cart.signedIn
                  ? (cart.canCheckout
                      ? 'Checkout · ${formatPaise(cart.summary.grandTotalPaise)}'
                      : 'Fix the items above to continue')
                  : 'Sign in to check out',
              onPressed: cart.signedIn && !cart.canCheckout ? null : () => _checkout(cart),
            ),
      children: !state.loaded
          ? const [AppLoadingView()]
          : cart.isEmpty
              ? [
                  AppPlaceholder(
                    icon: AppGlyph.cart,
                    title: 'Your cart is empty',
                    message: 'Add supplements, devices and everyday care from '
                        'the shop.',
                    action: FilledButton(
                      onPressed: () => context.go('/shop'),
                      child: const Text('Browse the shop'),
                    ),
                  ),
                ]
              : _content(context, cart, state.busy),
    );
  }

  List<Widget> _content(BuildContext context, Cart cart, bool busy) {
    final t = AppTokens.of(context);
    final s = cart.summary;
    final multiSeller = cart.groups.length > 1;

    return [
      if (busy) const LinearProgressIndicator(minHeight: 2),
      if (cart.pricesChanged) ...[
        const AppNote('Some prices changed since you added them.'),
        const SizedBox(height: 10),
      ],
      if (s.addForFreeShippingPaise != null) ...[
        AppNote(
          'Add ${formatPaise(s.addForFreeShippingPaise!)} more for free delivery',
          tone: AppTone.brand,
        ),
        const SizedBox(height: 4),
      ],
      for (final g in cart.groups) ...[
        AppSectionLabel(
          'Sold by ${g.sellerName}',
          trailing: multiSeller
              ? Text('Ships separately', style: Theme.of(context).textTheme.bodySmall)
              : null,
        ),
        for (final l in g.lines)
          _CartLineCard(
            line: l,
            enabled: !busy,
            onQty: (q) => _setQty(l, q),
          ),
      ],

      const AppSectionLabel('Coupon'),
      if (cart.coupon != null)
        Container(
          decoration: t.cardDecoration,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cart.coupon!.code,
                        style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      cart.coupon!.applied
                          ? (cart.coupon!.label ?? 'Applied')
                          : (cart.coupon!.note ?? 'Not applied yet'),
                      style: TextStyle(
                        fontFamily: kFontBody,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cart.coupon!.applied ? t.sub : t.amber,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => _applyCoupon(''),
                child: const Text('Remove'),
              ),
            ],
          ),
        )
      else
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _coupon,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Enter coupon code'),
                onSubmitted: _applyCoupon,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: AppSoftButton(
                label: 'Apply',
                onTap: busy ? null : () => _applyCoupon(_coupon.text),
              ),
            ),
          ],
        ),
      if (_couponError != null || cart.couponError != null) ...[
        const SizedBox(height: 8),
        AppNote(_couponError ?? cart.couponError!, tone: AppTone.err),
      ],

      const AppSectionLabel('Bill details'),
      Container(
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            AppKeyValue('Items (${s.itemCount})', formatPaise(s.subtotalPaise)),
            if (s.savingsPaise > 0)
              AppKeyValue('You save', '− ${formatPaise(s.savingsPaise)}',
                  valueColor: t.brand),
            if (s.discountPaise > 0)
              AppKeyValue('Coupon discount', '− ${formatPaise(s.discountPaise)}',
                  valueColor: t.brand),
            if (pointsDiscountLabel(cart) != null)
              AppKeyValue(pointsDiscountLabel(cart)!,
                  '− ${formatPaise(s.pointsDiscountPaise)}',
                  valueColor: t.brand),
            AppKeyValue(
              'Delivery',
              s.shippingPaise == 0 ? 'Free' : formatPaise(s.shippingPaise),
            ),
            Divider(color: t.line, height: 16),
            AppKeyValue('To pay', formatPaise(s.grandTotalPaise), strong: true),
            if (s.taxIncludedPaise > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Includes ${formatPaise(s.taxIncludedPaise)} GST',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      // Applied automatically by the server: no toggle.
      CartPointsNotes(cart: cart),
    ];
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.line, required this.onQty, required this.enabled});

  final CartLine line;
  final ValueChanged<int> onQty;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = line;
    // Qty picker: 1…max_qty, and never above what is in stock.
    final maxQty = l.availableQty > 0
        ? (l.maxQty < l.availableQty ? l.maxQty : l.availableQty)
        : l.qty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/shop/p/${l.slug}'),
            child: AppNetImage(l.image, width: 62, height: 62, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(fontSize: 12.5),
                ),
                if (l.variantTitle != null)
                  Text(l.variantTitle!, style: text.bodySmall),
                if (l.problem != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.problem!,
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.red,
                    ),
                  ),
                ] else if (l.priceChanged)
                  Text(
                    'Price updated',
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: t.amber,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatPaise(l.lineTotalPaise),
                        style: TextStyle(
                          fontFamily: kFontBody,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: l.problem == null ? t.ink : t.sub,
                          decoration:
                              l.problem == null ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: enabled ? () => onQty(0) : null,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: AppIcon(AppGlyph.trash, color: t.sub, size: 17),
                      ),
                    ),
                    const SizedBox(width: 6),
                    QtyStepper(
                      qty: l.qty,
                      max: maxQty < l.qty ? l.qty : maxQty,
                      enabled: enabled,
                      onChanged: onQty,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
