import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/store_repository.dart';
import '../domain/store_models.dart';
import 'shop_widgets.dart';

/// Shop tab — `store.php?action=home`.
///
/// Every home section can come back empty; empty ones are hidden. Tiles
/// open listings by scope (need, goal, brand, seller) exactly as the
/// website's store does.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  ApiResult<StoreHome>? _result;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).home();
    if (mounted) setState(() => _result = r);
  }

  void _runSearch(String q) {
    final text = q.trim();
    if (text.isEmpty) return;
    context.push(ListingQuery(scope: 'search', q: text).location);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final bottom = 96 + MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: AppTabPage(
            title: 'Wellness shop',
            actions: const [CartButton()],
            children: [
              _SearchField(controller: _search, onSubmitted: _runSearch),
              const SizedBox(height: 14),
              ...switch (r) {
                null => const [AppLoadingView()],
                ApiFailure(:final error) when error == 'store_unavailable' => [
                    const AppPlaceholder(
                      icon: AppGlyph.cart,
                      title: 'The shop is closed for now',
                      message: 'Please check back soon.',
                    ),
                  ],
                ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
                ApiSuccess(:final value) => _sections(context, value),
              },
              // Clearance for the floating cart bar.
              const SizedBox(height: 70),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: const FloatingCartBar(),
        ),
      ],
    );
  }

  List<Widget> _sections(BuildContext context, StoreHome h) {
    return [
      if (h.banners.isNotEmpty) ...[
        PromoBannerCarousel(banners: h.banners),
        const SizedBox(height: 4),
      ],
      if (h.needs.isNotEmpty) ...[
        AppSectionLabel(
          'Shop by need',
          trailing: _LinkText(
            'All categories',
            onTap: () => context.push('/shop/categories'),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: h.needs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _NeedTile(tile: h.needs[i]),
          ),
        ),
      ] else
        Align(
          alignment: Alignment.centerLeft,
          child: _LinkText(
            'Browse all categories →',
            onTap: () => context.push('/shop/categories'),
          ),
        ),
      if (h.featured.isNotEmpty) ...[
        const AppSectionLabel('Featured'),
        ProductGrid(products: h.featured),
      ],
      if (h.newArrivals.isNotEmpty) ...[
        const AppSectionLabel('New arrivals'),
        ProductStrip(products: h.newArrivals),
      ],
      if (h.goals.isNotEmpty) ...[
        const AppSectionLabel('Health goals'),
        _TileChips(tiles: h.goals),
      ],
      if (h.brands.isNotEmpty) ...[
        const AppSectionLabel('Brands'),
        _TileChips(tiles: h.brands),
      ],
      if (h.sellers.isNotEmpty) ...[
        const AppSectionLabel('Sellers'),
        AppGroup(
          children: [
            for (final (i, s) in h.sellers.indexed)
              AppGroupRow(
                label: s.label,
                sub: s.count == null ? null : '${s.count} products',
                leading: AppNetImage(s.image, width: 34, height: 34),
                last: i == h.sellers.length - 1,
                onTap: () => context.push(
                  ListingQuery(scope: 'seller', slug: s.slug).location,
                ),
              ),
          ],
        ),
      ],
      const AppSectionLabel('Your shopping'),
      AppGroup(
        children: [
          AppGroupRow(
            label: 'My orders',
            onTap: () => context.push('/shop/orders'),
          ),
          AppGroupRow(
            label: 'Wishlist',
            last: true,
            onTap: () => context.push('/shop/wishlist'),
          ),
        ],
      ),
    ];
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search vitamins, devices, care',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: AppIcon(AppGlyph.search, color: t.sub, size: 16),
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText(this.text, {required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kFontBody,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTokens.of(context).brand,
        ),
      ),
    );
  }
}

class _NeedTile extends StatelessWidget {
  const _NeedTile({required this.tile});

  final StoreTile tile;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: () => context.push(
        ListingQuery(scope: tile.scope, slug: tile.slug).location,
      ),
      child: Container(
        width: 100,
        decoration: t.cardDecoration,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            AppNetImage(tile.image, height: 58, width: double.infinity),
            const SizedBox(height: 8),
            Text(
              tile.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kFontBody,
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileChips extends StatelessWidget {
  const _TileChips({required this.tiles});

  final List<StoreTile> tiles;

  @override
  Widget build(BuildContext context) {
    return AppChoiceChips<StoreTile>(
      options: tiles,
      selected: null,
      scroll: true,
      labelOf: (s) => s.label,
      onSelected: (s) {
        if (s != null) {
          context.push(ListingQuery(scope: s.scope, slug: s.slug).location);
        }
      },
    );
  }
}
