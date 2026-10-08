/// Models for the eClinicPro Store (document/12-store-api-reference.md).
///
/// Money is always integer paise and already includes GST. The app never
/// computes a total: every amount shown comes from the server.
library;

int? _int(Object? v) =>
    v == null ? null : (v is int ? v : (v is num ? v.toInt() : int.tryParse('$v')));

double? _double(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

String? _str(Object? v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Doc 12 says `description` is plain text, but the live store sends
/// seller HTML (`<p>`, `<ul><li>`…). Render it as readable text: blocks
/// become line breaks, list items become bullets, other tags are dropped.
String? _plainText(Object? v) {
  final raw = _str(v);
  if (raw == null || !raw.contains('<')) return raw;
  final text = raw
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</h\d>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) => v is List
    ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList()
    : <T>[];

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList() : const [];

/// Name + slug, used for brands, sellers, categories.
class NamedRef {
  const NamedRef({required this.name, this.slug, this.id});

  final String name;
  final String? slug;
  final int? id;

  static NamedRef? maybe(Object? v) {
    final m = _map(v);
    final name = _str(m['name']);
    return name == null ? null : NamedRef(name: name, slug: _str(m['slug']), id: _int(m['id']));
  }
}

/// The product card used by every list.
class ProductCard {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.name,
    this.brand,
    this.sellerName,
    this.image,
    required this.pricePaise,
    this.mrpPaise,
    this.offPct = 0,
    this.priceFrom = false,
    this.inStock = true,
    this.ratingAvg,
    this.ratingCount = 0,
    this.wishlisted = false,
  });

  final int id;
  final String slug;
  final String name;
  final String? brand;
  final String? sellerName;
  final String? image;
  final int pricePaise;

  /// Null when there is no discount.
  final int? mrpPaise;

  /// Already zeroed by the server for `no_promotion` items (IMS Act): never
  /// recompute it from the MRP.
  final int offPct;

  /// Several variants: render "From ₹199".
  final bool priceFrom;
  final bool inStock;
  final double? ratingAvg;
  final int ratingCount;

  /// Only accurate when the Bearer token was sent.
  final bool wishlisted;

  factory ProductCard.fromJson(Map<String, dynamic> j) => ProductCard(
        id: _int(j['id']) ?? 0,
        slug: _str(j['slug']) ?? '',
        name: _str(j['name']) ?? 'Product',
        brand: _str(j['brand']),
        sellerName: NamedRef.maybe(j['seller'])?.name,
        image: _str(j['image']),
        pricePaise: _int(j['price_paise']) ?? 0,
        mrpPaise: _int(j['mrp_paise']),
        offPct: _int(j['off_pct']) ?? 0,
        priceFrom: j['price_from'] == true,
        inStock: j['in_stock'] != false,
        ratingAvg: _double(j['rating_avg']),
        ratingCount: _int(j['rating_count']) ?? 0,
        wishlisted: j['wishlisted'] == true,
      );
}

/// A tile that opens a listing: needs, goals, sellers, brands.
class StoreTile {
  const StoreTile({
    required this.scope,
    required this.slug,
    required this.label,
    this.image,
    this.count,
  });

  /// Listing scope this tile opens: `need`, `goal`, `seller`, `brand`.
  final String scope;
  final String slug;
  final String label;
  final String? image;
  final int? count;
}

class StoreHome {
  const StoreHome({
    this.banners = const [],
    this.needs = const [],
    this.featured = const [],
    this.newArrivals = const [],
    this.goals = const [],
    this.sellers = const [],
    this.brands = const [],
  });

  final List<StoreBanner> banners;
  final List<StoreTile> needs;
  final List<ProductCard> featured;
  final List<ProductCard> newArrivals;
  final List<StoreTile> goals;
  final List<StoreTile> sellers;
  final List<StoreTile> brands;

  factory StoreHome.fromJson(Map<String, dynamic> j) => StoreHome(
        banners: _list(j['banners'], StoreBanner.fromJson),
        needs: _list(
          j['needs'],
          (m) => StoreTile(
            scope: 'need',
            slug: _str(m['slug']) ?? '',
            label: _str(m['label']) ?? '',
            image: _str(m['image']),
          ),
        ),
        featured: _list(j['featured'], ProductCard.fromJson),
        newArrivals: _list(j['new_arrivals'], ProductCard.fromJson),
        goals: _list(
          j['goals'],
          (m) => StoreTile(
            scope: 'goal',
            slug: _str(m['slug']) ?? '',
            label: _str(m['name']) ?? '',
            image: _str(m['image']),
          ),
        ),
        sellers: _list(
          j['sellers'],
          (m) => StoreTile(
            scope: 'seller',
            slug: _str(m['slug']) ?? '',
            label: _str(m['name']) ?? '',
            image: _str(m['logo']),
            count: _int(m['product_count']),
          ),
        ),
        brands: _list(
          j['brands'],
          (m) => StoreTile(
            scope: 'brand',
            slug: _str(m['slug']) ?? '',
            label: _str(m['name']) ?? '',
          ),
        ),
      );
}

class StoreBanner {
  const StoreBanner({this.title, this.image, this.link});

  final String? title;
  final String? image;

  /// A website path such as `/store/c/{dept}/{sub}` or `/store/p/{slug}`.
  final String? link;

  factory StoreBanner.fromJson(Map<String, dynamic> j) => StoreBanner(
        title: _str(j['title']),
        image: _str(j['image']),
        link: _str(j['link']),
      );
}

class Department {
  const Department({
    required this.slug,
    required this.name,
    this.description,
    this.subcategories = const [],
  });

  final String slug;
  final String name;
  final String? description;
  final List<NamedRef> subcategories;

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        slug: _str(j['slug']) ?? '',
        name: _str(j['name']) ?? '',
        description: _str(j['description']),
        subcategories: _list(
          j['subcategories'],
          (m) => NamedRef(name: _str(m['name']) ?? '', slug: _str(m['slug'])),
        ),
      );
}

/// What a listing call asks for. Also the route's query string.
class ListingQuery {
  const ListingQuery({
    required this.scope,
    this.slug,
    this.sub,
    this.q,
    this.sort,
    this.brandId,
    this.inStockOnly = false,
  });

  /// `category` · `need` · `goal` · `brand` · `seller` · `search`.
  final String scope;
  final String? slug;
  final String? sub;
  final String? q;
  final String? sort;
  final int? brandId;
  final bool inStockOnly;

  ListingQuery copyWith({String? sort, int? brandId, bool clearBrand = false, bool? inStockOnly}) =>
      ListingQuery(
        scope: scope,
        slug: slug,
        sub: sub,
        q: q,
        sort: sort ?? this.sort,
        brandId: clearBrand ? null : (brandId ?? this.brandId),
        inStockOnly: inStockOnly ?? this.inStockOnly,
      );

  Map<String, String> toParams() => {
        'scope': scope,
        'slug': ?slug,
        'sub': ?sub,
        'q': ?q,
        'sort': ?sort,
        if (brandId != null) 'brand_id': '$brandId',
        if (inStockOnly) 'in_stock': '1',
      };

  /// `/shop/list?scope=…` for the router.
  String get location => Uri(path: '/shop/list', queryParameters: toParams()).toString();

  factory ListingQuery.fromParams(Map<String, String> p) => ListingQuery(
        scope: p['scope'] ?? 'search',
        slug: p['slug'],
        sub: p['sub'],
        q: p['q'],
        sort: p['sort'],
        brandId: int.tryParse(p['brand_id'] ?? ''),
        inStockOnly: p['in_stock'] == '1',
      );
}

class ListingChip {
  const ListingChip({
    required this.label,
    required this.scope,
    this.slug,
    this.sub,
    this.active = false,
  });

  final String label;
  final String scope;
  final String? slug;
  final String? sub;
  final bool active;

  ListingQuery get query => ListingQuery(scope: scope, slug: slug, sub: sub);
}

class FacetOption {
  const FacetOption({required this.id, required this.name, this.count = 0});

  final int id;
  final String name;
  final int count;
}

class SortOption {
  const SortOption({required this.key, required this.label});

  final String key;
  final String label;
}

class SellerInfo {
  const SellerInfo({
    required this.name,
    this.description,
    this.logo,
    this.banner,
    this.location,
    this.ratingAvg,
    this.ratingCount = 0,
    this.since,
  });

  final String name;
  final String? description;
  final String? logo;
  final String? banner;
  final String? location;
  final double? ratingAvg;
  final int ratingCount;
  final String? since;

  static SellerInfo? maybe(Object? v) {
    final m = _map(v);
    final name = _str(m['name']);
    if (name == null) return null;
    return SellerInfo(
      name: name,
      description: _str(m['description']),
      logo: _str(m['logo']),
      banner: _str(m['banner']),
      location: _str(m['location']),
      ratingAvg: _double(m['rating_avg']),
      ratingCount: _int(m['rating_count']) ?? 0,
      since: _str(m['since']),
    );
  }
}

class ListingPage {
  const ListingPage({
    required this.title,
    this.eyebrow,
    this.intro,
    this.seller,
    this.chips = const [],
    this.products = const [],
    this.total = 0,
    this.page = 1,
    this.pages = 1,
    this.brands = const [],
    this.sorts = const [],
  });

  final String title;
  final String? eyebrow;
  final String? intro;

  /// Filled for `scope=seller`: the storefront header.
  final SellerInfo? seller;
  final List<ListingChip> chips;
  final List<ProductCard> products;
  final int total;
  final int page;
  final int pages;
  final List<FacetOption> brands;
  final List<SortOption> sorts;

  bool get hasMore => page < pages;

  /// Appends the next page's products to this one.
  ListingPage append(ListingPage next) => ListingPage(
        title: title,
        eyebrow: eyebrow,
        intro: intro,
        seller: seller,
        chips: chips,
        products: [...products, ...next.products],
        total: next.total,
        page: next.page,
        pages: next.pages,
        brands: brands,
        sorts: sorts,
      );

  factory ListingPage.fromJson(Map<String, dynamic> j) {
    final facets = _map(j['facets']);
    return ListingPage(
      title: _str(j['title']) ?? 'Shop',
      eyebrow: _str(j['eyebrow']),
      intro: _str(j['intro']),
      seller: SellerInfo.maybe(j['seller']),
      chips: _list(
        j['chips'],
        (m) => ListingChip(
          label: _str(m['label']) ?? '',
          scope: _str(m['scope']) ?? 'category',
          slug: _str(m['slug']),
          sub: _str(m['sub']),
          active: m['active'] == true,
        ),
      ),
      products: _list(j['products'], ProductCard.fromJson),
      total: _int(j['total']) ?? 0,
      page: _int(j['page']) ?? 1,
      pages: _int(j['pages']) ?? 1,
      brands: _list(
        facets['brands'],
        (m) => FacetOption(
          id: _int(m['id']) ?? 0,
          name: _str(m['name']) ?? '',
          count: _int(m['count']) ?? 0,
        ),
      ),
      sorts: _list(
        facets['sorts'],
        (m) => SortOption(key: _str(m['key']) ?? '', label: _str(m['label']) ?? ''),
      ),
    );
  }
}

class Variant {
  const Variant({
    required this.id,
    required this.title,
    required this.pricePaise,
    this.mrpPaise,
    this.offPct = 0,
    this.inStock = true,
    this.lowStock = false,
  });

  /// The id add-to-cart takes (not the product id).
  final int id;
  final String title;
  final int pricePaise;
  final int? mrpPaise;
  final int offPct;
  final bool inStock;
  final bool lowStock;

  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: _int(j['id']) ?? 0,
        title: _str(j['title']) ?? '',
        pricePaise: _int(j['price_paise']) ?? 0,
        mrpPaise: _int(j['mrp_paise']),
        offPct: _int(j['off_pct']) ?? 0,
        inStock: j['in_stock'] != false,
        lowStock: j['low_stock'] == true,
      );
}

class Review {
  const Review({
    required this.rating,
    this.title,
    this.body,
    this.author,
    this.sellerReply,
    this.createdAt,
  });

  final int rating;
  final String? title;
  final String? body;
  final String? author;
  final String? sellerReply;
  final String? createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        rating: _int(j['rating']) ?? 0,
        title: _str(j['title']),
        body: _str(j['body']),
        author: _str(j['author']),
        sellerReply: _str(j['seller_reply']),
        createdAt: _str(j['created_at']),
      );
}

class ProductDetail {
  const ProductDetail({
    required this.id,
    required this.slug,
    required this.name,
    this.shortDesc,
    this.description,
    this.brand,
    this.category,
    this.images = const [],
    this.variants = const [],
    this.noPromotion = false,
    this.ratingAvg,
    this.ratingCount = 0,
    this.wishlisted = false,
    this.seller,
    this.sellerShipsFrom,
    this.specs = const [],
    this.returnable = false,
    this.returnWindowDays,
    this.facts = const [],
    this.taxNote,
    this.webUrl,
    this.reviews = const [],
    this.related = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String? shortDesc;
  final String? description;
  final NamedRef? brand;
  final NamedRef? category;
  final List<String> images;
  final List<Variant> variants;
  final bool noPromotion;
  final double? ratingAvg;
  final int ratingCount;
  final bool wishlisted;
  final NamedRef? seller;
  final String? sellerShipsFrom;
  final List<(String, String)> specs;
  final bool returnable;
  final int? returnWindowDays;
  final List<String> facts;
  final String? taxNote;
  final String? webUrl;
  final List<Review> reviews;
  final List<ProductCard> related;

  factory ProductDetail.fromJson(Map<String, dynamic> root) {
    final j = _map(root['product']);
    final seller = _map(j['seller']);
    return ProductDetail(
      id: _int(j['id']) ?? 0,
      slug: _str(j['slug']) ?? '',
      name: _str(j['name']) ?? 'Product',
      shortDesc: _plainText(j['short_desc']),
      description: _plainText(j['description']),
      brand: NamedRef.maybe(j['brand']),
      category: NamedRef.maybe(j['category']),
      images: _strings(j['images']),
      variants: _list(j['variants'], Variant.fromJson),
      noPromotion: j['no_promotion'] == true,
      ratingAvg: _double(j['rating_avg']),
      ratingCount: _int(j['rating_count']) ?? 0,
      wishlisted: j['wishlisted'] == true,
      seller: NamedRef.maybe(seller),
      sellerShipsFrom: _str(seller['ships_from']),
      specs: _list(
        j['specs'],
        (m) => (_str(m['label']) ?? '', _str(m['value']) ?? ''),
      ),
      returnable: j['returnable'] == true,
      returnWindowDays: _int(j['return_window_days']),
      facts: _strings(j['facts']),
      taxNote: _str(j['tax_note']),
      webUrl: _str(j['web_url']),
      reviews: _list(root['reviews'], Review.fromJson),
      related: _list(root['related'], ProductCard.fromJson),
    );
  }
}

// ---------------------------------------------------------------------------
// Cart
// ---------------------------------------------------------------------------

class CartLine {
  const CartLine({
    required this.itemId,
    required this.productId,
    required this.variantId,
    required this.slug,
    required this.name,
    this.variantTitle,
    this.image,
    required this.qty,
    this.availableQty = 0,
    this.maxQty = 10,
    required this.pricePaise,
    this.mrpPaise,
    this.lineTotalPaise = 0,
    this.problem,
    this.priceChanged = false,
  });

  final int itemId;
  final int productId;
  final int variantId;
  final String slug;
  final String name;
  final String? variantTitle;
  final String? image;
  final int qty;
  final int availableQty;
  final int maxQty;
  final int pricePaise;
  final int? mrpPaise;
  final int lineTotalPaise;

  /// e.g. "Out of stock". This line is excluded from the totals and blocks
  /// checkout until fixed or removed.
  final String? problem;
  final bool priceChanged;

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        itemId: _int(j['item_id']) ?? 0,
        productId: _int(j['product_id']) ?? 0,
        variantId: _int(j['variant_id']) ?? 0,
        slug: _str(j['slug']) ?? '',
        name: _str(j['name']) ?? '',
        variantTitle: _str(j['variant_title']),
        image: _str(j['image']),
        qty: _int(j['qty']) ?? 1,
        availableQty: _int(j['available_qty']) ?? 0,
        maxQty: _int(j['max_qty']) ?? 10,
        pricePaise: _int(j['price_paise']) ?? 0,
        mrpPaise: _int(j['mrp_paise']),
        lineTotalPaise: _int(j['line_total_paise']) ?? 0,
        problem: _str(j['problem']),
        priceChanged: j['price_changed'] == true,
      );
}

class CartGroup {
  const CartGroup({required this.sellerName, this.lines = const []});

  final String sellerName;
  final List<CartLine> lines;

  factory CartGroup.fromJson(Map<String, dynamic> j) => CartGroup(
        sellerName: NamedRef.maybe(j['seller'])?.name ?? 'Seller',
        lines: _list(j['lines'], CartLine.fromJson),
      );
}

class CartSummary {
  const CartSummary({
    this.itemCount = 0,
    this.sellerCount = 0,
    this.subtotalPaise = 0,
    this.savingsPaise = 0,
    this.discountPaise = 0,
    this.pointsDiscountPaise = 0,
    this.shippingPaise = 0,
    this.freeShippingAbovePaise,
    this.addForFreeShippingPaise,
    this.taxIncludedPaise = 0,
    this.grandTotalPaise = 0,
  });

  final int itemCount;
  final int sellerCount;
  final int subtotalPaise;
  final int savingsPaise;
  final int discountPaise;

  /// Taken off by points. Already deducted from [grandTotalPaise]; 0 when
  /// no points apply (or the server has points off).
  final int pointsDiscountPaise;

  /// One delivery fee per order. Judged after points, so using points can
  /// bring it back: always shown as sent, never computed.
  final int shippingPaise;
  final int? freeShippingAbovePaise;

  /// Set → "Add ₹X more for free delivery".
  final int? addForFreeShippingPaise;
  final int taxIncludedPaise;
  final int grandTotalPaise;

  factory CartSummary.fromJson(Map<String, dynamic> j) => CartSummary(
        itemCount: _int(j['item_count']) ?? 0,
        sellerCount: _int(j['seller_count']) ?? 0,
        subtotalPaise: _int(j['subtotal_paise']) ?? 0,
        savingsPaise: _int(j['savings_paise']) ?? 0,
        discountPaise: _int(j['discount_paise']) ?? 0,
        pointsDiscountPaise: _int(j['points_discount_paise']) ?? 0,
        shippingPaise: _int(j['shipping_paise']) ?? 0,
        freeShippingAbovePaise: _int(j['free_shipping_above_paise']),
        addForFreeShippingPaise: _int(j['add_for_free_shipping_paise']),
        taxIncludedPaise: _int(j['tax_included_paise']) ?? 0,
        grandTotalPaise: _int(j['grand_total_paise']) ?? 0,
      );
}

class CartCoupon {
  const CartCoupon({required this.code, this.label, this.applied = false, this.note});

  final String code;
  final String? label;

  /// False + [note]: the code is saved but does not apply yet (e.g. a
  /// minimum order is not met).
  final bool applied;
  final String? note;
}

/// The cart's `points` object. Null for guests or while points are off.
/// Points are applied by the server; there is nothing to toggle.
class CartPoints {
  const CartPoints({
    this.kind,
    this.used = 0,
    this.available = 0,
    this.pending = 0,
    this.welcome = 0,
    this.welcomeAddPaise,
    this.earns = 0,
  });

  /// Which points this order uses: `welcome`, or another kind; null = none.
  final String? kind;

  /// Points used on this cart.
  final int used;
  final int available;
  final int pending;

  /// Welcome points the customer holds.
  final int welcome;

  /// Set → "Add ₹X more to use your welcome points".
  final int? welcomeAddPaise;

  /// Points this order earns after delivery.
  final int earns;

  static CartPoints? maybe(Object? v) {
    if (v is! Map) return null;
    final j = Map<String, dynamic>.from(v);
    return CartPoints(
      kind: _str(j['kind']),
      used: _int(j['used']) ?? 0,
      available: _int(j['available']) ?? 0,
      pending: _int(j['pending']) ?? 0,
      welcome: _int(j['welcome']) ?? 0,
      welcomeAddPaise: _int(j['welcome_add_paise']),
      earns: _int(j['earns']) ?? 0,
    );
  }
}

class Cart {
  const Cart({
    this.cartToken,
    this.count = 0,
    this.groups = const [],
    this.summary = const CartSummary(),
    this.coupon,
    this.couponError,
    this.points,
    this.hasProblems = false,
    this.pricesChanged = false,
    this.canCheckout = false,
    this.signedIn = false,
    this.maxQtyPerLine = 10,
  });

  /// Non-null for a new guest cart: store it and send it as `X-Cart-Token`.
  final String? cartToken;
  final int count;
  final List<CartGroup> groups;
  final CartSummary summary;
  final CartCoupon? coupon;

  /// Set when a saved coupon stopped being usable.
  final String? couponError;
  final CartPoints? points;
  final bool hasProblems;
  final bool pricesChanged;
  final bool canCheckout;
  final bool signedIn;
  final int maxQtyPerLine;

  static const empty = Cart();

  bool get isEmpty => groups.every((g) => g.lines.isEmpty);

  factory Cart.fromJson(Map<String, dynamic> j) {
    final c = _map(j['coupon']);
    return Cart(
      cartToken: _str(j['cart_token']),
      count: _int(j['count']) ?? 0,
      groups: _list(j['groups'], CartGroup.fromJson),
      summary: CartSummary.fromJson(_map(j['summary'])),
      coupon: _str(c['code']) == null
          ? null
          : CartCoupon(
              code: _str(c['code'])!,
              label: _str(c['label']),
              applied: c['applied'] == true,
              note: _str(c['note']),
            ),
      couponError: _str(j['coupon_error']),
      points: CartPoints.maybe(j['points']),
      hasProblems: j['has_problems'] == true,
      pricesChanged: j['prices_changed'] == true,
      canCheckout: j['can_checkout'] == true,
      signedIn: j['signed_in'] == true,
      maxQtyPerLine: _int(j['max_qty_per_line']) ?? 10,
    );
  }
}

// ---------------------------------------------------------------------------
// Checkout
// ---------------------------------------------------------------------------

class Address {
  const Address({
    required this.id,
    this.label,
    required this.name,
    required this.phone,
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
  });

  final int id;
  final String? label;
  final String name;
  final String phone;
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  /// One-line postal address.
  String get oneLine => [line1, line2, landmark, '$city, $state $pincode']
      .whereType<String>()
      .where((e) => e.isNotEmpty)
      .join(', ');

  static Address? maybe(Object? v) {
    final j = _map(v);
    if (j.isEmpty) return null;
    return Address.fromJson(j);
  }

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: _int(j['id']) ?? 0,
        label: _str(j['label']),
        name: _str(j['name']) ?? '',
        phone: _str(j['phone']) ?? '',
        line1: _str(j['line1']) ?? '',
        line2: _str(j['line2']),
        landmark: _str(j['landmark']),
        city: _str(j['city']) ?? '',
        state: _str(j['state']) ?? '',
        pincode: _str(j['pincode']) ?? '',
        isDefault: j['is_default'] == true,
      );
}

/// `store_checkout.php?action=pincode` — public lookup for the address form.
class PincodeInfo {
  const PincodeInfo({
    required this.pin,
    this.city,
    this.state,
    this.serviceable = true,
    this.etaDays,
  });

  final String pin;

  /// India Post district name: prefill, but let the customer change it.
  final String? city;

  /// Always one of the server's `states`, so it can preselect the dropdown.
  final String? state;

  /// False: no courier delivers there. True with a null [etaDays] means the
  /// server could not check, so show nothing.
  final bool serviceable;
  final int? etaDays;

  factory PincodeInfo.fromJson(Map<String, dynamic> j) => PincodeInfo(
        pin: _str(j['pin']) ?? '',
        city: _str(j['city']),
        state: _str(j['state']),
        serviceable: j['serviceable'] != false,
        etaDays: _int(j['eta_days']),
      );
}

class AddressBook {
  const AddressBook({this.addresses = const [], this.max = 10, this.states = const []});

  final List<Address> addresses;
  final int max;

  /// The only valid values for `state` — it decides the invoice's GST type.
  final List<String> states;

  factory AddressBook.fromJson(Map<String, dynamic> j) => AddressBook(
        addresses: _list(j['addresses'], Address.fromJson),
        max: _int(j['max_addresses']) ?? 10,
        states: _strings(j['states']),
      );
}

class CheckoutSummary {
  const CheckoutSummary({
    required this.cart,
    this.addresses = const [],
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    required this.checkoutKey,
    this.paymentWindowMinutes = 30,
    this.states = const [],
    this.termsUrl,
    this.refundPolicyUrl,
  });

  final Cart cart;
  final List<Address> addresses;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;

  /// Idempotency key: retrying `place` with it returns the same order.
  final String checkoutKey;
  final int paymentWindowMinutes;
  final List<String> states;
  final String? termsUrl;
  final String? refundPolicyUrl;

  factory CheckoutSummary.fromJson(Map<String, dynamic> j) {
    final contact = _map(j['contact']);
    return CheckoutSummary(
      cart: Cart.fromJson(_map(j['cart'])),
      addresses: _list(j['addresses'], Address.fromJson),
      contactName: _str(contact['name']),
      contactPhone: _str(contact['phone']),
      contactEmail: _str(contact['email']),
      checkoutKey: _str(j['checkout_key']) ?? '',
      paymentWindowMinutes: _int(j['payment_window_minutes']) ?? 30,
      states: _strings(j['states']),
      termsUrl: _str(j['terms_url']),
      refundPolicyUrl: _str(j['refund_policy_url']),
    );
  }
}

class PlacedOrder {
  const PlacedOrder({required this.orderNo, this.grandTotalPaise = 0, this.expiresAt});

  final String orderNo;
  final int grandTotalPaise;
  final String? expiresAt;

  factory PlacedOrder.fromJson(Map<String, dynamic> j) => PlacedOrder(
        orderNo: _str(j['order_no']) ?? '',
        grandTotalPaise: _int(j['grand_total_paise']) ?? 0,
        expiresAt: _str(j['expires_at']),
      );
}

/// `pay_verify` outcome. The server asks Razorpay; the app never decides.
class PayVerdict {
  const PayVerdict({required this.state, this.paid = false});

  /// `paid` · `pending` · `failed` · `unknown`.
  final String state;
  final bool paid;
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

class OrderListItem {
  const OrderListItem({
    required this.orderNo,
    required this.statusLabel,
    this.statusTone,
    this.grandTotalPaise = 0,
    this.placedAt,
    this.expiresAt,
    this.itemCount = 0,
    this.packages = 1,
    this.preview = const [],
    this.moreItems = 0,
    this.canPay = false,
  });

  final String orderNo;
  final String statusLabel;
  final String? statusTone;
  final int grandTotalPaise;
  final String? placedAt;
  final String? expiresAt;
  final int itemCount;
  final int packages;
  final List<(String, String?, int)> preview;
  final int moreItems;
  final bool canPay;

  factory OrderListItem.fromJson(Map<String, dynamic> j) => OrderListItem(
        orderNo: _str(j['order_no']) ?? '',
        statusLabel: _str(j['status_label']) ?? _str(j['status']) ?? '',
        statusTone: _str(j['status_tone']),
        grandTotalPaise: _int(j['grand_total_paise']) ?? 0,
        placedAt: _str(j['placed_at']),
        expiresAt: _str(j['expires_at']),
        itemCount: _int(j['item_count']) ?? 0,
        packages: _int(j['packages']) ?? 1,
        preview: _list(
          j['items_preview'],
          (m) => (_str(m['name']) ?? '', _str(m['image']), _int(m['qty']) ?? 1),
        ),
        moreItems: _int(j['more_items']) ?? 0,
        canPay: j['can_pay'] == true,
      );
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.name,
    this.variantTitle,
    this.image,
    this.qty = 1,
    this.qtyCancelled = 0,
    this.qtyReturned = 0,
    this.unitPricePaise = 0,
    this.lineTotalPaise = 0,
    this.canReview = false,
    this.cancellableQty = 0,
    this.returnableQty = 0,
  });

  final int id;
  final int productId;
  final String name;
  final String? variantTitle;
  final String? image;
  final int qty;
  final int qtyCancelled;
  final int qtyReturned;
  final int unitPricePaise;
  final int lineTotalPaise;
  final bool canReview;
  final int cancellableQty;
  final int returnableQty;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: _int(j['id']) ?? 0,
        productId: _int(j['product_id']) ?? 0,
        name: _str(j['name']) ?? '',
        variantTitle: _str(j['variant_title']),
        image: _str(j['image']),
        qty: _int(j['qty']) ?? 1,
        qtyCancelled: _int(j['qty_cancelled']) ?? 0,
        qtyReturned: _int(j['qty_returned']) ?? 0,
        unitPricePaise: _int(j['unit_price_paise']) ?? 0,
        lineTotalPaise: _int(j['line_total_paise']) ?? 0,
        canReview: j['can_review'] == true,
        cancellableQty: _int(j['cancellable_qty']) ?? 0,
        returnableQty: _int(j['returnable_qty']) ?? 0,
      );
}

class TrackingEvent {
  const TrackingEvent({this.at, this.status, this.location});

  final String? at;
  final String? status;
  final String? location;
}

class Tracking {
  const Tracking({
    this.statusLabel,
    this.courier,
    this.awb,
    this.url,
    this.events = const [],
  });

  final String? statusLabel;
  final String? courier;
  final String? awb;
  final String? url;
  final List<TrackingEvent> events;

  static Tracking? maybe(Object? v) {
    final j = _map(v);
    if (j.isEmpty) return null;
    return Tracking(
      statusLabel: _str(j['status_label']),
      courier: _str(j['courier']),
      awb: _str(j['awb']),
      url: _str(j['url']),
      events: _list(
        j['events'],
        (m) => TrackingEvent(
          at: _str(m['at']),
          status: _str(m['status']),
          location: _str(m['location']),
        ),
      ),
    );
  }
}

class OrderDocument {
  const OrderDocument({required this.type, this.docNo, this.issuedAt, required this.url});

  final String type;
  final String? docNo;
  final String? issuedAt;

  /// Authed HTML page: open in a WebView with the Bearer header.
  final String url;
}

class OrderReturn {
  const OrderReturn({required this.returnNo, this.statusLabel, this.refundPaise = 0});

  final String returnNo;
  final String? statusLabel;
  final int refundPaise;
}

class OrderPackage {
  const OrderPackage({
    required this.id,
    this.subOrderNo,
    this.sellerName,
    this.statusLabel,
    this.shippingPaise = 0,
    this.items = const [],
    this.tracking,
    this.documents = const [],
    this.returns = const [],
    this.canCancelItems = false,
    this.canReturn = false,
    this.returnUntil,
  });

  /// `vendor_order_id` for a return request.
  final int id;
  final String? subOrderNo;
  final String? sellerName;
  final String? statusLabel;
  final int shippingPaise;
  final List<OrderItem> items;
  final Tracking? tracking;
  final List<OrderDocument> documents;
  final List<OrderReturn> returns;
  final bool canCancelItems;
  final bool canReturn;
  final String? returnUntil;

  factory OrderPackage.fromJson(Map<String, dynamic> j) => OrderPackage(
        id: _int(j['id']) ?? 0,
        subOrderNo: _str(j['sub_order_no']),
        sellerName: NamedRef.maybe(j['seller'])?.name,
        statusLabel: _str(j['status_label']),
        shippingPaise: _int(j['shipping_paise']) ?? 0,
        items: _list(j['items'], OrderItem.fromJson),
        tracking: Tracking.maybe(j['tracking']),
        documents: _list(
          j['documents'],
          (m) => OrderDocument(
            type: _str(m['type']) ?? 'Invoice',
            docNo: _str(m['doc_no']),
            issuedAt: _str(m['issued_at']),
            url: _str(m['url']) ?? '',
          ),
        ),
        returns: _list(
          j['returns'],
          (m) => OrderReturn(
            returnNo: _str(m['return_no']) ?? '',
            statusLabel: _str(m['status_label']),
            refundPaise: _int(m['refund_paise']) ?? 0,
          ),
        ),
        canCancelItems: j['can_cancel_items'] == true,
        canReturn: j['can_return'] == true,
        returnUntil: _str(j['return_until']),
      );
}

class ReturnReason {
  const ReturnReason({required this.key, required this.label});

  final String key;
  final String label;
}

class OrderDetail {
  const OrderDetail({
    required this.orderNo,
    required this.statusLabel,
    this.statusTone,
    this.noticeTone,
    this.noticeText,
    this.placedAt,
    this.paidAt,
    this.canPay = false,
    this.canCancel = false,
    this.expiresAt,
    this.packages = const [],
    this.itemsPaise = 0,
    this.discountPaise = 0,
    this.couponCode,
    this.pointsUsed = 0,
    this.pointsDiscountPaise = 0,
    this.shippingPaise = 0,
    this.taxIncludedPaise = 0,
    this.grandTotalPaise = 0,
    this.refunds = const [],
    this.shipTo,
    this.cancelReasons = const [],
    this.returnReasons = const [],
    this.photoRequiredFor = const [],
  });

  final String orderNo;
  final String statusLabel;
  final String? statusTone;
  final String? noticeTone;
  final String? noticeText;
  final String? placedAt;
  final String? paidAt;
  final bool canPay;

  /// Unpaid order only.
  final bool canCancel;
  final String? expiresAt;
  final List<OrderPackage> packages;
  final int itemsPaise;
  final int discountPaise;
  final String? couponCode;
  final int pointsUsed;
  final int pointsDiscountPaise;
  final int shippingPaise;
  final int taxIncludedPaise;
  final int grandTotalPaise;
  final List<(String, int, bool)> refunds;
  final Address? shipTo;
  final List<String> cancelReasons;
  final List<ReturnReason> returnReasons;

  /// Return reasons that need at least one photo.
  final List<String> photoRequiredFor;

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final notice = _map(j['notice']);
    final totals = _map(j['totals']);
    final options = _map(j['options']);
    return OrderDetail(
      orderNo: _str(j['order_no']) ?? '',
      statusLabel: _str(j['status_label']) ?? _str(j['status']) ?? '',
      statusTone: _str(j['status_tone']),
      noticeTone: _str(notice['tone']),
      noticeText: _str(notice['text']),
      placedAt: _str(j['placed_at']),
      paidAt: _str(j['paid_at']),
      canPay: j['can_pay'] == true,
      canCancel: j['can_cancel'] == true,
      expiresAt: _str(j['expires_at']),
      packages: _list(j['packages'], OrderPackage.fromJson),
      itemsPaise: _int(totals['items_paise']) ?? 0,
      discountPaise: _int(totals['discount_paise']) ?? 0,
      couponCode: _str(totals['coupon_code']),
      pointsUsed: _int(totals['points_used']) ?? 0,
      pointsDiscountPaise: _int(totals['points_discount_paise']) ?? 0,
      shippingPaise: _int(totals['shipping_paise']) ?? 0,
      taxIncludedPaise: _int(totals['tax_included_paise']) ?? 0,
      grandTotalPaise: _int(totals['grand_total_paise']) ?? 0,
      refunds: _list(
        j['refunds'],
        (m) => (
          _str(m['refund_no']) ?? '',
          _int(m['amount_paise']) ?? 0,
          m['processed'] == true,
        ),
      ),
      shipTo: Address.maybe(j['ship_to']),
      cancelReasons: _strings(options['cancel_reasons']),
      returnReasons: _list(
        options['return_reasons'],
        (m) => ReturnReason(key: _str(m['key']) ?? '', label: _str(m['label']) ?? ''),
      ),
      photoRequiredFor: _strings(options['return_photo_required_for']),
    );
  }
}
