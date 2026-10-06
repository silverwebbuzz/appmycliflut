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

/// Listing / search / seller storefront — `store.php?action=listing`.
///
/// One screen for every scope. Chips are the server's sub-navigation (a tap
/// is a new listing); sort options come from `facets.sorts`. 24 per page,
/// with "Load more".
class ListingScreen extends ConsumerStatefulWidget {
  const ListingScreen({super.key, required this.query});

  final ListingQuery query;

  @override
  ConsumerState<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends ConsumerState<ListingScreen> {
  late ListingQuery _query = widget.query;
  ApiResult<ListingPage>? _result;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).listing(_query);
    if (mounted) setState(() => _result = r);
  }

  Future<void> _loadMore(ListingPage current) async {
    setState(() => _loadingMore = true);
    final r = await ref
        .read(storeRepositoryProvider)
        .listing(_query, page: current.page + 1);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (r case ApiSuccess(:final value)) _result = ApiSuccess(current.append(value));
    });
    if (r is ApiFailure<ListingPage>) showAppSnack(context, friendlyMessage(r));
  }

  void _requery(ListingQuery q) {
    setState(() {
      _query = q;
      _result = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final title = switch (r) {
      ApiSuccess(:final value) => value.title,
      _ => _query.q != null ? 'Search' : 'Shop',
    };
    return AppSubPage(
      title: title,
      fallbackRoute: '/shop',
      actions: const [CartButton()],
      onRefresh: _load,
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => _content(context, value),
      },
    );
  }

  List<Widget> _content(BuildContext context, ListingPage page) {
    final text = Theme.of(context).textTheme;
    final sortKey = _query.sort ?? (page.sorts.isEmpty ? null : page.sorts.first.key);

    return [
      if (page.seller != null) ...[
        _SellerHeader(seller: page.seller!),
        const SizedBox(height: 12),
      ] else if (page.intro != null) ...[
        Text(page.intro!, style: text.bodySmall),
        const SizedBox(height: 12),
      ],
      if (page.chips.isNotEmpty) ...[
        AppChoiceChips<ListingChip>(
          options: page.chips,
          selected: page.chips.where((c) => c.active).firstOrNull,
          scroll: true,
          labelOf: (c) => c.label,
          onSelected: (c) {
            if (c != null) _requery(c.query);
          },
        ),
        const SizedBox(height: 10),
      ],
      if (page.sorts.isNotEmpty)
        AppChoiceChips<SortOption>(
          options: page.sorts,
          selected: page.sorts.where((s) => s.key == sortKey).firstOrNull,
          scroll: true,
          labelOf: (s) => s.label,
          onSelected: (s) => _requery(_query.copyWith(sort: s?.key ?? 'relevance')),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              '${page.total} product${page.total == 1 ? '' : 's'}',
              style: text.bodySmall,
            ),
          ),
          if (page.brands.length > 1)
            _FilterButton(
              label: _query.brandId == null
                  ? 'Brand'
                  : page.brands
                          .where((b) => b.id == _query.brandId)
                          .firstOrNull
                          ?.name ??
                      'Brand',
              onTap: () => _pickBrand(page.brands),
            ),
          const SizedBox(width: 8),
          _FilterButton(
            label: _query.inStockOnly ? 'In stock ✓' : 'In stock',
            onTap: () => _requery(_query.copyWith(inStockOnly: !_query.inStockOnly)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (page.products.isEmpty)
        AppPlaceholder(
          icon: AppGlyph.search,
          title: 'Nothing found',
          message: _query.q != null
              ? 'No products match "${_query.q}". Try a different word.'
              : 'No products here yet.',
        )
      else
        for (final p in page.products) ProductRowCard(product: p),
      if (page.hasMore) ...[
        const SizedBox(height: 6),
        AppSoftButton(
          label: 'Load more',
          busy: _loadingMore,
          onTap: () => _loadMore(page),
        ),
      ],
    ];
  }

  Future<void> _pickBrand(List<FacetOption> brands) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All brands'),
              onTap: () => Navigator.of(c).pop(-1),
            ),
            for (final b in brands)
              ListTile(
                title: Text(b.name),
                trailing: Text('${b.count}'),
                onTap: () => Navigator.of(c).pop(b.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _requery(picked == -1
        ? _query.copyWith(clearBrand: true)
        : _query.copyWith(brandId: picked));
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: t.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kFontBody,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: t.ink,
          ),
        ),
      ),
    );
  }
}

class _SellerHeader extends StatelessWidget {
  const _SellerHeader({required this.seller});

  final SellerInfo seller;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final meta = [
      if (seller.location != null) seller.location!,
      if (seller.ratingAvg != null)
        '★ ${seller.ratingAvg!.toStringAsFixed(1)} (${seller.ratingCount})',
    ].join(' · ');
    return Container(
      decoration: t.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (seller.banner != null)
            AppNetImage(seller.banner, height: 110, width: double.infinity, radius: 0),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppNetImage(seller.logo, width: 44, height: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(seller.name, style: text.titleMedium),
                      if (meta.isNotEmpty) Text(meta, style: text.bodySmall),
                      if (seller.description != null) ...[
                        const SizedBox(height: 4),
                        Text(seller.description!, style: text.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// All departments → subcategories — `store.php?action=categories`.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  ApiResult<List<Department>>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(storeRepositoryProvider).categories();
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return AppSubPage(
      title: 'All categories',
      fallbackRoute: '/shop',
      children: switch (r) {
        null => const [AppLoadingView()],
        ApiFailure() => [AppFailureView(failure: r, onRetry: _load)],
        ApiSuccess(:final value) => [
            for (final d in value) ...[
              AppSectionLabel(
                d.name,
                trailing: GestureDetector(
                  onTap: () => context.push(
                    ListingQuery(scope: 'category', slug: d.slug).location,
                  ),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontFamily: kFontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.of(context).brand,
                    ),
                  ),
                ),
              ),
              AppChoiceChips<NamedRef>(
                options: d.subcategories,
                selected: null,
                labelOf: (s) => s.name,
                onSelected: (s) {
                  if (s != null) {
                    context.push(ListingQuery(
                      scope: 'category',
                      slug: d.slug,
                      sub: s.slug,
                    ).location);
                  }
                },
              ),
            ],
          ],
      },
    );
  }
}
