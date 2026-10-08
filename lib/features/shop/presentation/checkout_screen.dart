import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/cart_controller.dart';
import '../data/payment_flow.dart';
import '../data/points_providers.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';
import 'address_screens.dart';
import 'shop_widgets.dart';

/// Checkout — `summary` → `place` → `pay_start` → Razorpay → `pay_verify`.
///
/// The `checkout_key` from `summary` is kept for the life of this screen, so
/// a retried or double-tapped `place` returns the same order instead of a
/// second one. Placing reserves stock as *Awaiting payment*; if the payment
/// sheet is closed, the order stays payable from its detail page.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  ApiResult<CheckoutSummary>? _result;
  List<Address> _addresses = const [];
  int? _addressId;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).checkoutSummary();
    if (!mounted) return;
    setState(() {
      _result = r;
      if (r case ApiSuccess(:final value)) {
        _addresses = value.addresses;
        _addressId ??= (value.addresses.where((a) => a.isDefault).firstOrNull ??
                value.addresses.firstOrNull)
            ?.id;
        if (_name.text.isEmpty) _name.text = value.contactName ?? '';
        if (_phone.text.isEmpty) _phone.text = value.contactPhone ?? '';
        if (_email.text.isEmpty) _email.text = value.contactEmail ?? '';
        ref.read(cartControllerProvider.notifier).adopt(value.cart);
      }
    });
  }

  Future<void> _addAddress() async {
    final a = await context.push<Address>('/shop/addresses/new');
    if (a == null || !mounted) return;
    setState(() {
      _addresses = [a, ..._addresses.where((x) => x.id != a.id)];
      _addressId = a.id;
    });
  }

  Future<void> _placeAndPay(CheckoutSummary s) async {
    if (_addressId == null) {
      setState(() => _error = 'Please add a delivery address.');
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().length < 10) {
      setState(() => _error = 'Please enter your name and a 10-digit phone.');
      return;
    }
    setState(() {
      _placing = true;
      _error = null;
    });

    final repo = ref.read(storeRepositoryProvider);
    final placed = await repo.place(
      checkoutKey: s.checkoutKey,
      addressId: _addressId!,
      contactName: _name.text.trim(),
      contactPhone: _phone.text.trim(),
      contactEmail: _email.text.trim(),
      clientTotalPaise: s.cart.summary.grandTotalPaise,
    );
    if (!mounted) return;

    final PlacedOrder order;
    switch (placed) {
      case ApiSuccess(:final value):
        order = value;
      case ApiFailure(:final error):
        setState(() {
          _placing = false;
          _error = friendlyMessage(placed);
        });
        // Something sold out or a price moved: show the fresh numbers.
        if (error == 'cannot_place' || error == 'cart_needs_attention') _load();
        return;
    }

    // The order now holds the items; the cart is empty server-side.
    ref.read(cartControllerProvider.notifier).refresh();

    final outcome = await payForOrder(repo, order.orderNo);
    if (!mounted) return;
    // Placing and paying spends points; show the new balance next time.
    ref.invalidate(pointsSummaryProvider);
    setState(() => _placing = false);
    if (outcome.message != null) showAppSnack(context, outcome.message!);
    // The order page shows the server's notice and, while unpaid, Pay again.
    context.pushReplacement(
      '/shop/orders/${order.orderNo}?pay=${outcome.result.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final s = r is ApiSuccess<CheckoutSummary> ? r.value : null;
    return AppSubPage(
      title: 'Checkout',
      fallbackRoute: '/shop/cart',
      bottomBar: s == null
          ? null
          : AppPrimaryButton(
              label: 'Pay ${formatPaise(s.cart.summary.grandTotalPaise)}',
              busy: _placing,
              onPressed: () => _placeAndPay(s),
            ),
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure(:final error)
            when error == 'cart_empty' || error == 'cart_needs_attention' =>
          [
            AppNote(
              error == 'cart_empty'
                  ? 'Your cart is empty.'
                  : 'Some items in your cart need attention before you can '
                      'check out.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back to cart'),
            ),
          ],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _content(context, value),
      },
    );
  }

  List<Widget> _content(BuildContext context, CheckoutSummary s) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final sum = s.cart.summary;

    return [
      const AppSectionLabel('Delivery address'),
      for (final a in _addresses)
        AddressCard(
          address: a,
          selected: a.id == _addressId,
          onTap: () => setState(() => _addressId = a.id),
        ),
      AppSoftButton(label: '+ Add new address', onTap: _addAddress),

      const AppSectionLabel('Contact'),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Name'),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: 'Phone', prefixText: '+91  '),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(hintText: 'Email for the invoice · optional'),
      ),

      const AppSectionLabel('Order summary'),
      Container(
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final g in s.cart.groups)
              for (final l in g.lines)
                AppKeyValue(
                  '${l.qty} × ${l.name}${l.variantTitle == null ? '' : ' (${l.variantTitle})'}',
                  formatPaise(l.lineTotalPaise),
                ),
            Divider(color: t.line, height: 16),
            AppKeyValue('Items', formatPaise(sum.subtotalPaise)),
            if (sum.discountPaise > 0)
              AppKeyValue('Coupon discount', '− ${formatPaise(sum.discountPaise)}',
                  valueColor: t.brand),
            if (pointsDiscountLabel(s.cart) != null)
              AppKeyValue(pointsDiscountLabel(s.cart)!,
                  '− ${formatPaise(sum.pointsDiscountPaise)}',
                  valueColor: t.brand),
            AppKeyValue(
              'Delivery',
              sum.shippingPaise == 0 ? 'Free' : formatPaise(sum.shippingPaise),
            ),
            Divider(color: t.line, height: 16),
            AppKeyValue('To pay', formatPaise(sum.grandTotalPaise), strong: true),
            if (sum.taxIncludedPaise > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Includes ${formatPaise(sum.taxIncludedPaise)} GST',
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
      CartPointsNotes(cart: s.cart),
      const SizedBox(height: 12),
      AppNote(
        'Items are reserved for ${s.paymentWindowMinutes} minutes while you '
        'pay. Paid securely with Razorpay.',
        tone: AppTone.brand,
      ),
      if (s.groups > 1) ...[
        const SizedBox(height: 8),
        Text(
          'Your order ships in ${s.groups} packages, one per seller.',
          style: text.bodySmall,
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        AppNote(_error!, tone: AppTone.err),
      ],
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        children: [
          if (s.termsUrl != null)
            _Link('Terms', s.termsUrl!),
          if (s.refundPolicyUrl != null)
            _Link('Refund policy', s.refundPolicyUrl!),
        ],
      ),
    ];
  }
}

extension on CheckoutSummary {
  int get groups => cart.groups.length;
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTokens.of(context).brand,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
