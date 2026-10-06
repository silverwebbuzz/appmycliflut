import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/cart_controller.dart';
import '../domain/store_models.dart';

/// Price, struck MRP and "% OFF", following the store's rules: "From" when
/// there are several variants, MRP only when set, and never a % badge when
/// the server zeroed `off_pct` (`no_promotion`, IMS Act).
class PriceLine extends StatelessWidget {
  const PriceLine({
    super.key,
    required this.pricePaise,
    this.mrpPaise,
    this.offPct = 0,
    this.from = false,
    this.size = 14,
    this.showOff = false,
  });

  final int pricePaise;
  final int? mrpPaise;
  final int offPct;
  final bool from;
  final double size;
  final bool showOff;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
        Text(
          '${from ? 'From ' : ''}${formatPaise(pricePaise)}',
          // Manrope: Sora has no ₹ glyph.
          style: TextStyle(
            fontFamily: kFontBody,
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
        if (mrpPaise != null && mrpPaise! > pricePaise)
          Text(
            formatPaise(mrpPaise!),
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: size * 0.75,
              fontWeight: FontWeight.w600,
              color: t.sub,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (showOff && offPct > 0) AppStatusPill('$offPct% off'),
      ],
    );
  }
}

/// "★ 4.3 · 18" — omitted when there are no ratings.
class RatingLine extends StatelessWidget {
  const RatingLine({super.key, this.avg, this.count = 0, this.suffix});

  final double? avg;
  final int count;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final style = TextStyle(
      fontFamily: kFontBody,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: t.sub,
    );
    if (avg == null || count == 0) {
      return suffix == null ? const SizedBox.shrink() : Text(suffix!, style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppGlyph.star, color: t.amber, size: 12),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            '${avg!.toStringAsFixed(1)} · $count${suffix == null ? '' : ' · $suffix'}',
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _brandLine(ProductCard p) => (p.brand ?? p.sellerName ?? '').toUpperCase();

TextStyle _brandStyle(AppTokens t) => TextStyle(
      fontFamily: kFontBody,
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.08 * 9.5,
      color: t.sub,
    );

/// Grid card (shop home, related products).
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({super.key, required this.product, this.width});

  final ProductCard product;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final p = product;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/shop/p/${p.slug}'),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Ink(
            decoration: t.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.25,
                      child: AppNetImage(
                        p.image,
                        radius: AppRadii.card - 1,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (p.offPct > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _OffBadge(p.offPct),
                      ),
                    if (!p.inStock)
                      const Positioned(
                        bottom: 8,
                        left: 8,
                        child: AppStatusPill('Out of stock', tone: AppTone.muted),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _brandLine(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _brandStyle(t),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontBody,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      RatingLine(avg: p.ratingAvg, count: p.ratingCount),
                      const SizedBox(height: 6),
                      PriceLine(
                        pricePaise: p.pricePaise,
                        mrpPaise: p.mrpPaise,
                        from: p.priceFrom,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row card (listings, wishlist).
class ProductRowCard extends StatelessWidget {
  const ProductRowCard({super.key, required this.product, this.trailing});

  final ProductCard product;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final p = product;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/shop/p/${p.slug}'),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Ink(
            decoration: t.cardDecoration,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppNetImage(p.image, width: 74, height: 74, fit: BoxFit.contain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_brandLine(p), style: _brandStyle(t), maxLines: 1),
                      const SizedBox(height: 2),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kFontBody,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      RatingLine(
                        avg: p.ratingAvg,
                        count: p.ratingCount,
                        suffix: p.inStock ? null : 'Out of stock',
                      ),
                      const SizedBox(height: 6),
                      PriceLine(
                        pricePaise: p.pricePaise,
                        mrpPaise: p.mrpPaise,
                        offPct: p.offPct,
                        from: p.priceFrom,
                        showOff: true,
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OffBadge extends StatelessWidget {
  const _OffBadge(this.pct);

  final int pct;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.brand,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$pct% OFF',
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: t.onAccent,
        ),
      ),
    );
  }
}

/// Square cart button with the item-count badge, as in the shop header.
class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final count = ref.watch(cartCountProvider);
    return GestureDetector(
      onTap: () => context.push('/shop/cart'),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: t.cardDecoration.copyWith(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: AppIcon(AppGlyph.cart, color: t.ink, size: 18),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: 0,
                child: CountBadge(count),
              ),
          ],
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.brand,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: t.onAccent,
        ),
      ),
    );
  }
}

/// − qty + on a chip track. [max] caps the + button.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.enabled = true,
  });

  final int qty;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    Widget btn(String s, bool on, int next) => GestureDetector(
          onTap: on && enabled ? () => onChanged(next) : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              s,
              style: TextStyle(
                fontFamily: kFontHeading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: on && enabled ? t.brand : t.sub.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn('−', qty > min, qty - 1),
          SizedBox(
            width: 22,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kFontHeading,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
          ),
          btn('+', qty < max, qty + 1),
        ],
      ),
    );
  }
}

/// The dark "3 items · ₹447 · View cart →" bar over shop screens.
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final cart = ref.watch(cartControllerProvider).cart;
    if (cart.count == 0) return const SizedBox.shrink();
    const onBrand = AppColorsLight.onBrand;
    final s = cart.summary;
    final note = s.addForFreeShippingPaise != null
        ? 'Add ${formatPaise(s.addForFreeShippingPaise!)} more for free delivery'
        : (s.shippingPaise == 0 ? 'Free delivery' : 'Delivery ${formatPaise(s.shippingPaise)}');

    return GestureDetector(
      onTap: () => context.push('/shop/cart'),
      child: Container(
        decoration: t.heroDecoration(radius: AppRadii.card),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.count} item${cart.count == 1 ? '' : 's'} · '
                    '${formatPaise(s.grandTotalPaise)}',
                    style: const TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: onBrand,
                    ),
                  ),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onBrand.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              'View cart →',
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: onBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strip of grid cards.
class ProductStrip extends StatelessWidget {
  const ProductStrip({super.key, required this.products});

  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => ProductGridCard(product: products[i], width: 156),
      ),
    );
  }
}

/// Two-column grid without a nested scrollable.
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.products});

  final List<ProductCard> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < products.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ProductGridCard(product: products[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < products.length
                        ? ProductGridCard(product: products[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Opens an admin-entered link (store banners) in the right screen.
///
/// Understands the website's store paths (`/store/p/{slug}`, `/store/c/{dept}`
/// `[/{sub}]`, `/store/need|goal|brand|seller/{slug}`, `/store/search?q=`,
/// `/store/cart|orders|wishlist|categories`), also given as full
/// `https://eclinicpro.com/…` URLs; plain app paths (`/doctors`, `/records`,
/// `/appointments`, …); and opens any other https link in the browser.
/// Unknown store paths fall back to the Shop tab rather than doing nothing.
void openPromoLink(BuildContext context, String? link) {
  final raw = link?.trim() ?? '';
  if (raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null) return;

  final external = uri.hasScheme && !uri.host.endsWith('eclinicpro.com');
  if (external) {
    launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (seg.isEmpty) return;

  if (seg.first != 'store') {
    // An in-app path such as /doctors or /records.
    const tabs = {'home', 'doctors', 'records', 'more', 'shop'};
    final path = '/${seg.join('/')}';
    tabs.contains(seg.first) ? context.go(path) : context.push(path);
    return;
  }

  final kind = seg.length > 1 ? seg[1] : '';
  final a = seg.length > 2 ? seg[2] : null;
  final b = seg.length > 3 ? seg[3] : null;
  final location = switch (kind) {
    'p' when a != null => '/shop/p/$a',
    'c' when a != null =>
      ListingQuery(scope: 'category', slug: a, sub: b).location,
    'need' || 'goal' || 'brand' || 'seller' when a != null =>
      ListingQuery(scope: kind, slug: a).location,
    'search' => ListingQuery(scope: 'search', q: uri.queryParameters['q']).location,
    'cart' => '/shop/cart',
    'orders' => '/shop/orders',
    'wishlist' => '/shop/wishlist',
    'categories' => '/shop/categories',
    _ => null,
  };
  location == null ? context.go('/shop') : context.push(location);
}

/// Admin-managed promo banners (`/admin/store/banners`): full-width images,
/// swipeable, auto-advancing every 5 s, with page dots. Hidden when empty.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key, required this.banners});

  final List<StoreBanner> banners;

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final next = (_index + 1) % widget.banners.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        AspectRatio(
          // Admin uploads are wide promo images; 2:1 keeps them legible.
          aspectRatio: 2,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final b = banners[i];
              return Semantics(
                button: b.link != null,
                label: b.title,
                child: GestureDetector(
                  onTap: () => openPromoLink(context, b.link),
                  child: AppNetImage(b.image, radius: AppRadii.xl),
                ),
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _index ? t.brand : t.line,
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
