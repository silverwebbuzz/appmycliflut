import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/format.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/cart_controller.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';
import 'shop_widgets.dart';

/// Product — `store.php?action=product&slug=…`.
///
/// Add to cart uses the selected **variant** id. With one variant the picker
/// is hidden. The add button shows no computed line total: the cart is the
/// only place totals appear, and those come from the server.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  ApiResult<ProductDetail>? _result;
  Variant? _variant;
  int _qty = 1;
  bool? _wishlisted;
  bool _wishBusy = false;
  int _image = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).product(widget.slug);
    if (!mounted) return;
    setState(() {
      _result = r;
      if (r case ApiSuccess(:final value)) {
        _wishlisted = value.wishlisted;
        // Default to the first variant that can actually be bought.
        _variant = value.variants.where((v) => v.inStock).firstOrNull ??
            value.variants.firstOrNull;
      }
    });
  }

  Future<void> _add() async {
    final v = _variant;
    if (v == null) return;
    final r = await ref.read(cartControllerProvider.notifier).add(v.id, qty: _qty);
    if (!mounted) return;
    switch (r) {
      case ApiSuccess():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: const Text('Added to cart'),
            action: SnackBarAction(
              label: 'View cart',
              onPressed: () => context.push('/shop/cart'),
            ),
          ));
      case ApiFailure():
        showAppSnack(context, friendlyMessage(r));
    }
  }

  Future<void> _toggleWish(ProductDetail p) async {
    setState(() => _wishBusy = true);
    final r = await ref.read(storeRepositoryProvider).toggleWishlist(p.id);
    if (!mounted) return;
    setState(() => _wishBusy = false);
    switch (r) {
      case ApiSuccess(:final value):
        setState(() => _wishlisted = value);
        showAppSnack(context, value ? 'Saved to wishlist' : 'Removed from wishlist');
      case ApiFailure(:final isLoginRequired):
        if (isLoginRequired) {
          promptSignIn(context, reason: 'Sign in to save products to your wishlist.');
        } else {
          showAppSnack(context, friendlyMessage(r));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final r = _result;
    final busy = ref.watch(cartControllerProvider.select((s) => s.busy));
    final p = r is ApiSuccess<ProductDetail> ? r.value : null;
    final v = _variant;

    return AppSubPage(
      title: 'Product',
      fallbackRoute: '/shop',
      actions: [
        if (p != null)
          IconButton(
            onPressed: _wishBusy ? null : () => _toggleWish(p),
            icon: AppIcon(
              _wishlisted == true ? AppGlyph.heartFilled : AppGlyph.heart,
              color: t.ink,
              size: 21,
            ),
          ),
        const CartButton(),
      ],
      bottomBar: p == null || v == null
          ? null
          : Row(
              children: [
                QtyStepper(
                  qty: _qty,
                  max: 10,
                  enabled: v.inStock,
                  onChanged: (q) => setState(() => _qty = q),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppPrimaryButton(
                    label: v.inStock ? 'Add to cart' : 'Out of stock',
                    busy: busy,
                    onPressed: v.inStock ? _add : null,
                  ),
                ),
              ],
            ),
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _content(context, value),
      },
    );
  }

  List<Widget> _content(BuildContext context, ProductDetail p) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final v = _variant;

    return [
      _Gallery(
        images: p.images,
        index: _image,
        onChanged: (i) => setState(() => _image = i),
      ),
      const SizedBox(height: 14),
      if (p.brand != null)
        Text(
          p.brand!.name.toUpperCase(),
          style: TextStyle(
            fontFamily: kFontBody,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1 * 9.5,
            color: t.brand,
          ),
        ),
      const SizedBox(height: 4),
      Text(p.name, style: text.headlineSmall),
      const SizedBox(height: 5),
      RatingLine(
        avg: p.ratingAvg,
        count: p.ratingCount,
        suffix: p.ratingCount == 0 ? 'No reviews yet' : null,
      ),
      if (v != null) ...[
        const SizedBox(height: 10),
        PriceLine(
          pricePaise: v.pricePaise,
          mrpPaise: v.mrpPaise,
          offPct: v.offPct,
          size: 22,
          showOff: true,
        ),
        if (p.taxNote != null) Text(p.taxNote!, style: text.bodySmall),
        if (!v.inStock) ...[
          const SizedBox(height: 8),
          const AppNote('This option is out of stock.', tone: AppTone.err),
        ] else if (v.lowStock) ...[
          const SizedBox(height: 8),
          const AppNote('Only a few left'),
        ],
      ],
      if (p.variants.length > 1) ...[
        const AppSectionLabel('Choose an option'),
        AppChoiceChips<Variant>(
          options: p.variants,
          selected: v,
          labelOf: (x) => x.inStock ? x.title : '${x.title} · out of stock',
          onSelected: (x) {
            if (x != null) setState(() => _variant = x);
          },
        ),
      ],
      if (p.shortDesc != null) ...[
        const SizedBox(height: 14),
        Text(p.shortDesc!, style: text.bodyMedium),
      ],
      if (p.facts.isNotEmpty) ...[
        const AppSectionLabel('Good to know'),
        AppGroup(
          children: [
            for (final (i, f) in p.facts.indexed)
              AppGroupRow(
                label: f,
                last: i == p.facts.length - 1,
                leading: AppIcon(AppGlyph.check, color: t.brand, size: 16),
              ),
          ],
        ),
      ],
      if (p.description != null) ...[
        const AppSectionLabel('About this product'),
        Text(
          p.description!,
          style: text.bodyLarge?.copyWith(height: 1.7, fontSize: 13.5),
        ),
      ],
      if (p.specs.isNotEmpty) ...[
        const AppSectionLabel('Key details'),
        AppGroup(
          children: [
            for (final (i, (k, val)) in p.specs.indexed)
              AppGroupRow(
                label: k,
                last: i == p.specs.length - 1,
                trailing: Flexible(
                  child: Text(val, textAlign: TextAlign.right, style: text.bodyMedium),
                ),
              ),
          ],
        ),
      ],
      if (p.seller != null) ...[
        const AppSectionLabel('Sold by'),
        AppGroup(
          children: [
            AppGroupRow(
              label: p.seller!.name,
              sub: p.sellerShipsFrom == null ? null : 'Ships from ${p.sellerShipsFrom}',
              last: true,
              onTap: p.seller!.slug == null
                  ? null
                  : () => context.push(
                        ListingQuery(scope: 'seller', slug: p.seller!.slug).location,
                      ),
            ),
          ],
        ),
      ],
      if (p.reviews.isNotEmpty) ...[
        const AppSectionLabel('Reviews'),
        for (final rv in p.reviews.take(5)) _ReviewCard(review: rv),
      ],
      if (p.related.isNotEmpty) ...[
        const AppSectionLabel('You may also like'),
        ProductStrip(products: p.related),
      ],
    ];
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.images, required this.index, required this.onChanged});

  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (images.isEmpty) {
      return const AppNetImage(null, height: 220, width: double.infinity, radius: AppRadii.lg);
    }
    return Column(
      children: [
        Container(
          height: 240,
          decoration: t.cardDecoration.copyWith(color: Colors.white),
          clipBehavior: Clip.antiAlias,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: onChanged,
            itemBuilder: (_, i) => AppNetImage(images[i], fit: BoxFit.contain, radius: 0),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                Container(
                  width: i == index ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == index ? t.brand : t.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final r = review;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: t.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                AppIcon(AppGlyph.star, color: i < r.rating ? t.amber : t.line, size: 13),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [r.author, if (r.createdAt != null) formatDate(r.createdAt)]
                      .whereType<String>()
                      .join(' · '),
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
          if (r.title != null) ...[
            const SizedBox(height: 6),
            Text(r.title!, style: text.labelLarge),
          ],
          if (r.body != null) ...[
            const SizedBox(height: 4),
            Text(r.body!, style: text.bodyMedium),
          ],
          if (r.sellerReply != null) ...[
            const SizedBox(height: 8),
            AppNote('Seller: ${r.sellerReply}', tone: AppTone.muted),
          ],
        ],
      ),
    );
  }
}
