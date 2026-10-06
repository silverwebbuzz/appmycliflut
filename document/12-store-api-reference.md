# 12 — Store (Marketplace) API Reference (v1, as built)

The app's **Shop** tab talks to the eClinicPro Store (`eclinicpro.com/store`)
through five files under the same base URL as doc 11:

`https://eclinicpro.com/api/mobile/v1`

| File | What it does | Auth |
|------|--------------|------|
| `store.php` | Catalog: home, categories, listings/search, product, reviews | Public (Bearer optional) |
| `store_cart.php` | Cart: get / add / change qty / coupon | Guest **or** Bearer |
| `store_checkout.php` | Addresses, pincode lookup, place order, Razorpay start/verify | Bearer (pincode lookup: public) |
| `store_orders.php` | My orders, detail, cancel, review, return, invoice | Bearer |
| `store_wishlist.php` | Saved products | Bearer |

Same rules as doc 11: **thin client.** Each route calls the same PHP the
website's store runs (`store/_lib.php` for catalog reads,
`App\Services\Store\*` for cart, pricing, stock, orders and payments). Prices,
shipping, coupons, stock limits and order rules therefore match the website.
The app should **never compute a total itself**. It displays what the server
returns.

> **Status (2026-09-30), tested live on eclinicpro.com (store is live, no preview header needed):**
> - ✅ Catalog: `home`, `categories`, `listing` (search), `product` (variants, images). All return correct data in about 0.5s.
> - ✅ Guest cart: `add` returns a `cart_token`; `get` with `X-Cart-Token` returns the same cart; `set qty 0`
>   removes the item; an invalid `coupon` returns `422 coupon_invalid` + `message`. Totals match the website
>   (₹60 item + ₹49 delivery = ₹109).
> - ✅ Every sign-in-only route (`store_checkout`, `store_orders`, `store_wishlist`) returns `401 login_required` without a token.
> - ⏳ **Not yet run with a real login:** checkout `summary` / `place`, `pay_start` / `pay_verify` (Razorpay),
>   order detail / cancel / return / review / invoice, wishlist `toggle`, and the guest-cart merge after login.
>   These need a Bearer token from a real OTP login; run steps 3–6 of the curl tests at the end first.
>   Razorpay itself can only be tested from the app (sandbox mode).

> **Added 2026-10-05 (code written, ⏳ not yet run on the server):** pincode lookup,
> address edit / set default, and customer order updates on WhatsApp. Run the
> SQL patch `app/database/patches/2026_10_05_store_whatsapp.sql` first, then
> step 7 of the curl tests.

---

## Conventions (in addition to doc 11)

- **Envelope:** `{ "ok": true, … }` / `{ "ok": false, "error": "code", … }`.
  Store errors that the customer should read also carry **`message`**
  (e.g. `"Sorry, this is out of stock."`). Show `message` when present,
  otherwise map `error` to your own text.
- **Money is always integer paise** in fields ending `_paise`. Prices include GST.
  Format: `₹` + rupees; drop `.00` for whole rupees (`₹499`, `₹12.50`), as the website does.
- **Images** are absolute URLs (seller uploads live on `app.eclinicpro.com`) and
  public, so `Image.network` / `CachedNetworkImage` works. They can be `null`:
  show a placeholder.
- **Dates** are server-local `YYYY-MM-DD HH:MM:SS` strings (IST).

### Store headers

| Header | When |
|--------|------|
| `Authorization: Bearer <token>` | Signed in (same token as doc 11). |
| `X-Cart-Token: <64 hex>` | Guest cart. See "Guest cart" below. |
| `X-Store-Preview: <key>` | Only while the store is hidden (`store_enabled = 0`), to test on live. The key is `store_preview_key` in Store settings. Remove it for release builds. |

If the store is hidden and no valid preview key is sent, **every store route
returns `404 store_unavailable`**. Hide the Shop tab in that case.

### Guest cart

A logged-out user can browse **and build a cart**:

1. Call `store_cart.php?action=add` with no token.
2. If the response's `cart.cart_token` is **non-null**, save it in secure storage.
3. Send it as `X-Cart-Token` on every store call from then on.
4. After OTP login, keep sending **both** `Authorization` and `X-Cart-Token` on
   the next cart call. The server merges the guest cart into the patient's cart,
   exactly like the website. You can then delete the stored cart token.

Checkout, orders and the wishlist require sign-in (`401 login_required` → open
the OTP flow, then retry).

---

## Catalog — `store.php` (GET only)

### Product card (used in every list)
```json
{
  "id": 42, "slug": "vitamin-d3-60k", "name": "Vitamin D3 60K (4 caps)",
  "brand": "HealthKart", "seller": { "name": "Wellness Mart", "slug": "wellness-mart" },
  "image": "https://app.eclinicpro.com/uploads/store/…jpg",
  "price_paise": 19900, "mrp_paise": 25000, "off_pct": 20,
  "no_promotion": false, "price_from": true,
  "in_stock": true, "rating_avg": 4.3, "rating_count": 18, "wishlisted": false
}
```
- `price_from: true` → render "From ₹199" (the product has several variants).
- `mrp_paise` is `null` when there is no discount. When it's set, show MRP struck through.
- `off_pct` is **0 when `no_promotion` is true** (infant food/feeding under the
  IMS Act). You may show the struck MRP, but never a "% off" badge. The server
  already zeroes it; don't recompute it.
- `wishlisted` is only accurate when the Bearer token is sent.

### `GET ?action=home`
```json
{ "ok": true,
  "banners": [ { "title": "…", "image": "https://…", "link": "/store/c/…" } ],
  "needs":   [ { "slug": "nutrition-supplements", "label": "Nutrition & supplements", "image": "https://…" } ],
  "featured": [card…], "new_arrivals": [card…],
  "goals":   [ { "id": 3, "slug": "immunity", "name": "Immunity", "description": "…", "image": null } ],
  "sellers": [ { "slug": "…", "name": "…", "logo": "https://…|null", "product_count": 12 } ],
  "brands":  [ { "slug": "…", "name": "…" } ] }
```
Every section can be empty, so hide a section when its array is empty. Tap targets:
need → listing `scope=need&slug=`, goal → `scope=goal&slug=`, seller →
`scope=seller&slug=`, brand → `scope=brand&slug=`. Banner `link` is a website
path; map `/store/c/{dept}/{sub}`, `/store/p/{slug}`, etc. to screens, or ignore
unknown links.

### `GET ?action=categories`
`{ departments:[{ id, slug, name, description, subcategories:[{id,slug,name}] }], needs:[{slug,label}], goals:[…] }`

### `GET ?action=listing`
| Param | Values |
|-------|--------|
| `scope` | `category` · `need` · `goal` · `brand` · `seller` · `search` |
| `slug` | department / need / goal / brand / seller slug |
| `sub` | subcategory slug (scope=category only; omit for the whole department) |
| `q` | search text (scope=search) |
| `brand_id`, `seller_id` | facet filters (ids from `facets`) |
| `min`, `max` | price in **whole rupees** |
| `in_stock=1`, `sort` | `relevance` (default) · `price_asc` · `price_desc` · `newest` · `rating` |
| `page` | 1-based; **24 per page** |

```json
{ "ok": true, "title": "Vitamins & minerals", "eyebrow": "Nutrition", "intro": null,
  "seller": null,
  "chips": [ { "label": "Protein", "scope": "category", "slug": "nutrition", "sub": "protein", "active": false } ],
  "products": [card…], "total": 131, "page": 1, "pages": 6, "per_page": 24,
  "facets": { "brands": [ {"id":5,"name":"…","count":12} ], "sellers": [ … ],
              "sorts": [ {"key":"relevance","label":"Recommended"}, … ] } }
```
- `chips` = the horizontal sub-navigation (subcategories, or other goals). Tapping
  one = a new listing call with that chip's `scope/slug/sub`.
- `scope=seller` also fills `seller` (logo, banner, location, rating, since…),
  which is the seller storefront header.
- Unknown slug → `404 not_found`.

### `GET ?action=product&slug=…` (or `&id=…`)
```json
{ "ok": true,
  "product": {
    "id": 42, "slug": "…", "name": "…", "short_desc": "…", "description": "plain text\nwith line breaks",
    "brand": { "name": "…", "slug": "…" },
    "category": { "name": "…", "slug": "…", "dept": { "name": "…", "slug": "…" } },
    "images": ["https://…"],
    "variants": [ { "id": 77, "title": "60 caps", "price_paise": 19900, "mrp_paise": 25000,
                    "off_pct": 20, "in_stock": true, "low_stock": false } ],
    "no_promotion": false, "rating_avg": 4.3, "rating_count": 18, "wishlisted": false,
    "seller": { "name": "…", "slug": "…", "logo": null, "rating_avg": 4.6, "ships_from": "Pune, Maharashtra" },
    "specs": [ { "label": "Manufacturer", "value": "…" } ],
    "returnable": true, "return_window_days": 7,
    "facts": [ "Usually dispatched within 2 days. Delivery across India.", "7-day returns if …", "Genuine product …" ],
    "tax_note": "Inclusive of all taxes",
    "web_url": "https://eclinicpro.com/store/p/…" },
  "reviews": [ { "rating": 5, "title": "…", "body": "…", "author": "Ravi S.", "seller_reply": null, "created_at": "…" } ],
  "related": [card…] }
```
- **Add to cart uses the variant `id`**, not the product id. With one variant,
  hide the picker. `low_stock` → "Only a few left".
- `web_url` is for the share sheet.

### `GET ?action=reviews&product_id=42`
`{ reviews:[…] }` (up to 50, newest first).

---

## Cart — `store_cart.php`

Every action returns the **whole cart** in the same shape, so re-render from it.

```json
{ "ok": true, "cart": {
  "cart_token": null,
  "count": 3,
  "groups": [ {
    "seller": { "id": 4, "name": "Wellness Mart", "slug": "wellness-mart" },
    "subtotal_paise": 39800, "shipping_paise": 0,
    "free_shipping_above_paise": null, "add_for_free_shipping_paise": null,
    "lines": [ { "item_id": 901, "product_id": 42, "variant_id": 77, "slug": "…", "name": "…",
                 "variant_title": "60 caps", "image": "https://…", "qty": 2,
                 "available_qty": 14, "max_qty": 10, "price_paise": 19900, "mrp_paise": 25000,
                 "off_pct": 20, "line_total_paise": 39800, "problem": null, "price_changed": false } ] } ],
  "summary": { "item_count": 3, "seller_count": 1, "subtotal_paise": 39800, "savings_paise": 10200,
               "discount_paise": 0, "shipping_paise": 4900,
               "free_shipping_above_paise": 49900, "add_for_free_shipping_paise": 10100,
               "tax_included_paise": 4264, "grand_total_paise": 44700 },
  "coupon": null, "coupon_error": null,
  "has_problems": false, "prices_changed": false, "can_checkout": true,
  "signed_in": true, "max_qty_per_line": 10 } }
```
- **One package per seller.** Show lines grouped under "Sold by …" (add "Ships
  separately" when there is more than one seller).
- **Delivery is one fee per order**, in `summary.shipping_paise` (show it as
  "Delivery"). If `summary.add_for_free_shipping_paise` is set, show "Add ₹X more
  for free delivery". The per-group `shipping_paise` / `free_shipping_above_paise` /
  `add_for_free_shipping_paise` are always `0` / `null` / `null` (kept for older builds).
- `problem` non-null (e.g. "Out of stock", "Only 2 left: reduce the quantity")
  → show it in red. That line is **excluded from the totals** and
  `can_checkout` is false until it's fixed or removed.
- `prices_changed: true` → show once: "Some prices changed since you added them."
- Qty picker: 1…`max_qty`; values above `available_qty` disabled.
- `coupon.applied: false` + `coupon.note` → the code is saved but doesn't apply
  (for example, a minimum order isn't met). Show the note.
- Checkout button: signed out → "Sign in to check out" (OTP flow); signed in and
  `can_checkout` → go to Checkout.

| Action | Body | Notes |
|--------|------|-------|
| `GET ?action=get` | — | Doesn't create a cart. |
| `POST ?action=add` | `{ "variant_id": 77, "qty": 1 }` | Returns `added_qty` + `cart`. `422 cannot_add` + `message` (out of stock, cart full…). Adding again increases qty. |
| `POST ?action=set` | `{ "item_id": 901, "qty": 3 }` | `qty: 0` removes. `404 item_not_found`. |
| `POST ?action=coupon` | `{ "code": "WELCOME10" }` | `""` removes. `422 coupon_invalid` + `message`. `429 too_many_attempts` (10 tries / 10 min). |

---

## Checkout & payment — `store_checkout.php` (Bearer; `pincode` is public)

### Flow
```
summary ──► place ──► pay_start ──► Razorpay SDK ──► pay_verify ──► order detail
```

### `GET ?action=summary`
```json
{ "ok": true, "cart": {…cart shape…},
  "addresses": [ { "id": 5, "label": "Home", "name": "…", "phone": "+9198…", "line1": "…", "line2": null,
                   "landmark": null, "city": "Pune", "state": "Maharashtra", "pincode": "411001", "is_default": true } ],
  "contact": { "name": "…", "phone": "98xxxxxxxx", "email": null },
  "checkout_key": "3f2c…-uuid",
  "payment_window_minutes": 30,
  "states": ["Jammu and Kashmir", "…"],
  "terms_url": "https://eclinicpro.com/terms", "refund_policy_url": "https://eclinicpro.com/refund-policy" }
```
- `409 cart_empty` / `409 cart_needs_attention` (both include `cart`) → send the user back to the cart.
- **State must be one of `states`** (use a dropdown). It decides GST type on the invoice.
- Keep `checkout_key` for this screen. Send it with `place`. Retrying `place` with
  the same key (after a timeout or double tap) returns the **same** order, never a second one.
- Show `summary.tax_included_paise` as "Includes ₹X GST", and "Items are reserved
  for `payment_window_minutes` minutes while you pay".

### Addresses
| Action | Body |
|--------|------|
| `GET ?action=addresses` | → `{ addresses, max_addresses, states }` |
| `POST ?action=address_add` | `{ name, phone, line1, line2?, landmark?, pincode, city, state, label? }` → `{ address }` · `422 invalid_address` + `message` |
| `POST ?action=address_update` | `{ "address_id": 5, …any address_add fields… }` → `{ address }` · `404 not_found` · `422 invalid_address` + `message` |
| `POST ?action=address_set_default` | `{ "address_id": 5 }` → `{ addresses }` (whole list, default first) · `404 not_found` |
| `POST ?action=address_remove` | `{ "address_id": 5 }` |

A new address becomes the default. The limit is 10.

`address_update`: fields you don't send keep their saved value (send `""` to clear
`line2`, `landmark` or `label`). The result is checked exactly like `address_add`:
`state` must be one of `states`, `phone` a 10-digit Indian mobile, `pincode` 6 digits.
It does not change which address is the default. Orders already placed keep their
own copy of the address, so editing never changes a past order.

An `address_id` that isn't one of the signed-in customer's saved addresses
(someone else's, removed, or made up) always gives `404 not_found`.

### `GET ?action=pincode&pin=380001` (public, no token needed)
Call it when the customer finishes typing a 6-digit pincode in the address form.
```json
{ "ok": true, "pin": "380001", "city": "Ahmedabad", "state": "Gujarat",
  "serviceable": true, "eta_days": 3 }
```
- `city` is the district name from India Post. Prefill the City box but let the
  customer change it.
- `state` is always one of `summary.states` / `addresses.states`, so you can
  preselect it in the dropdown.
- `serviceable` / `eta_days` come from Shiprocket (fastest courier, prepaid). Show
  "Delivery in about 3 days" when `eta_days` is a number. `serviceable:false` means
  no courier delivers there: show a warning. **`serviceable:true` + `eta_days:null`
  means we couldn't check** (Shiprocket off or slow): show nothing and carry on.
  `place` does not check serviceability.
- Answers are cached for 24 h per pincode on the server.
- Errors: `400 invalid_pin` + `message` (not 6 digits, or starts with 0) ·
  `404 pin_not_found` + `message` (not in our list: let the customer type city and
  state themselves) · `429 too_many_attempts` (60 lookups / 10 min per IP).
- The pincode list is India Post's directory (about 19,100 pincodes). Pincodes
  created recently may be missing; that's why `pin_not_found` must not block the form.

### `POST ?action=place`
```json
{ "checkout_key": "3f2c…", "address_id": 5,
  "contact_name": "Ravi Sharma", "contact_phone": "9876543210", "contact_email": "ravi@example.com",
  "client_total_paise": 44700 }
```
Instead of `address_id` you may send `"address": { …new address fields… }`. It
is saved, then used.
→ `{ "ok": true, "order_no": "ECS290926-7K2QF", "grand_total_paise": 44700, "expires_at": "2026-09-29 14:35:00" }`

Errors: `409 cart_empty` · `422 address_required` · `422 invalid_contact` +
`message` · `422 cannot_place` + `message` + fresh `cart` (something sold out
or a price changed: show the message and re-render the cart).

Placing an order **reserves stock** and creates the order as *Awaiting payment*.
A customer has only one unpaid order at a time: placing another cancels the
previous unpaid one. Unpaid orders expire at `expires_at`.

### `POST ?action=pay_start` — `{ "order_no": "ECS…" }`
```json
{ "ok": true, "checkout": {
  "key": "rzp_live_…", "order_id": "order_N…", "amount": 44700, "currency": "INR",
  "name": "eClinicPro Store", "description": "Order ECS…",
  "prefill": { "name": "…", "contact": "98…", "email": "…" },
  "notes": { "order_no": "ECS…" }, "theme": { "color": "#059669" }, "mode": "production" } }
```
Pass these straight into **`razorpay_flutter`**:
```dart
_razorpay.open({
  'key': c['key'], 'order_id': c['order_id'], 'amount': c['amount'], 'currency': c['currency'],
  'name': c['name'], 'description': c['description'], 'prefill': c['prefill'],
  'notes': c['notes'], 'theme': c['theme'],
});
```
`422 cannot_pay` + `message` (window closed, already paid…). `429 too_many_attempts`.
Calling `pay_start` again for the same order reuses the same Razorpay order.

### `POST ?action=pay_verify`
On `EVENT_PAYMENT_SUCCESS`, send the SDK's response:
```json
{ "order_no": "ECS…", "razorpay_order_id": "order_N…", "razorpay_payment_id": "pay_…", "razorpay_signature": "…" }
```
(`orderId` / `paymentId` / `signature`, the SDK's own names, are accepted too.)
→ `{ "ok": true, "state": "paid|pending|failed|unknown", "paid": true, "order_no": "ECS…" }`

| `state` | App does |
|---------|----------|
| `paid` | Success screen → order detail. |
| `pending` / `unknown` | "Confirming your payment…" → re-fetch order detail after ~3 s (repeat a few times). The Razorpay webhook completes the order even if this call never arrives. |
| `failed` | "Payment failed. You can try again" → `pay_start` again. |

On `EVENT_PAYMENT_ERROR` or when the user closes the sheet, just stay on the
order: it's still payable (`can_pay`) until `expires_at`. The decision is always
made by Razorpay's API on the server, never by the app.

`500 server_error` during pay → show: "If money was deducted, it will reflect
on your order within a few minutes."

---

## Orders — `store_orders.php` (Bearer)

### `GET ?action=list`
```json
{ "ok": true, "orders": [ {
  "order_no": "ECS…", "status": "paid", "status_label": "Order confirmed", "status_tone": "ok",
  "payment_status": "paid", "grand_total_paise": 44700, "placed_at": "…", "expires_at": null,
  "packages": 2, "item_count": 3,
  "items_preview": [ { "name": "…", "image": "https://…", "qty": 2 } ], "more_items": 0,
  "can_pay": false } ] }
```
`status_tone`: `ok` (green) · `warn` (amber) · `err` (red) · `muted` (grey).
Bind `status_label`; don't build your own label table.

### `GET ?action=detail&order_no=ECS…`
```json
{ "ok": true, "order": {
  "order_no": "…", "status": "shipped", "status_label": "Shipped", "status_tone": "ok",
  "payment_status": "paid",
  "notice": { "tone": "ok", "text": "Thank you, payment received. …" },
  "placed_at": "…", "paid_at": "…",
  "can_pay": false, "can_cancel": false, "expires_at": null,
  "packages": [ {
    "id": 311, "sub_order_no": "ECS…-A", "seller": { "name": "…", "slug": "…" },
    "status": "shipped", "status_label": "Shipped", "shipping_paise": 0,
    "items": [ { "id": 1201, "product_id": 42, "name": "…", "variant_title": "…", "image": "…",
                 "qty": 2, "qty_cancelled": 0, "qty_returned": 0,
                 "unit_price_paise": 19900, "line_total_paise": 39800,
                 "can_review": false, "cancellable_qty": 0, "returnable_qty": 0 } ],
    "tracking": { "status": "in_transit", "status_label": "In transit", "courier": "Delhivery",
                  "awb": "1234…", "url": "https://shiprocket.co/tracking/1234…",
                  "events": [ { "at": "…", "status": "In Transit", "location": "Mumbai Hub" } ] },
    "documents": [ { "id": 88, "type": "Tax invoice", "doc_no": "I4-2627-12", "issued_at": "…",
                     "url": "https://eclinicpro.com/api/mobile/v1/store_orders.php?action=invoice&order_no=…&doc=88" } ],
    "returns": [ { "return_no": "RT…", "status": "requested", "status_label": "Waiting for the seller", "refund_paise": 0 } ],
    "can_cancel_items": false, "can_return": false, "return_until": null } ],
  "totals": { "items_paise": 39800, "discount_paise": 0, "coupon_code": null, "shipping_paise": 4900,
              "tax_included_paise": 4264, "grand_total_paise": 44700 },
  "refunds": [ { "refund_no": "…", "amount_paise": 19900, "status": "processed", "processed": true } ],
  "ship_to": { "name": "…", "phone": "…", "line1": "…", "line2": null, "landmark": null,
               "city": "…", "state": "…", "pincode": "…" },
  "options": { "cancel_reasons": ["Changed my mind", "…"],
               "return_reasons": [ { "key": "damaged", "label": "Arrived damaged" }, … ],
               "return_photo_required_for": ["damaged", "wrong_item", "expired", "defective"] } } }
```
Foreign or unknown `order_no` → `404 not_found`.

UI driven purely by flags:
- `can_pay` → "Pay ₹X" (pay_start flow) + "Cancel order" (`cancel`). Show a countdown to `expires_at`.
- Package `can_cancel_items` → "Cancel items" sheet: per item, 0…`cancellable_qty`, plus a reason from `options.cancel_reasons`.
- Package `can_return` → "Return items (until `return_until`)": per item, 0…`returnable_qty`, a reason, and photos.
- Item `can_review` → "★ Rate this product".
- `tracking` non-null → tracking card. `url` opens the courier page.
- `documents` → invoice links. See `invoice` below.

### Actions
| Action | Body | Result |
|--------|------|--------|
| `POST ?action=cancel` | `{ "order_no": "…" }` | Unpaid orders only. → `{ order }` · `409 cannot_cancel` |
| `POST ?action=cancel_items` | `{ "order_no": "…", "items": { "1201": 1 }, "reason": "Changed my mind" }` | → `{ refunded_paise, refund_no, message, order }` · `422 cannot_cancel` + `message`. Refund goes to the original payment method (5–7 working days). |
| `POST ?action=review` | `{ "order_item_id": 1201, "rating": 5, "title": "…", "body": "…" }` | → `{ message }`. Reviews are moderated before they appear. `422 cannot_review` + `message`. Ask for product experience, not medical claims. |
| `POST ?action=return` | **multipart/form-data** (below) | → `{ return_no, message }` · `422 cannot_return` + `message` |
| `GET ?action=invoice&order_no=…&doc=88` | — | **HTML page** (not JSON). |

**Return upload (multipart):**
```dart
FormData.fromMap({
  'vendor_order_id': 311,
  'reason': 'damaged',
  'note': 'Seal was broken',
  'items[1201]': 1,                       // or 'items': jsonEncode({'1201': 1})
  'photos[]': [await MultipartFile.fromFile(p1), await MultipartFile.fromFile(p2)],
});
```
The file part is `photos[]` (up to 3, jpg/png/webp). A photo is **required** for
the reasons in `options.return_photo_required_for`.

**Invoice:** open `documents[].url` in a **WebView with the
`Authorization: Bearer` header** on the initial request (e.g.
`webview_flutter`'s `loadRequest(uri, headers: {...})`). It's a printable GST
invoice or credit note. Do not open it in the external browser: it has no token there.

---

## Wishlist — `store_wishlist.php` (Bearer)

| Action | Body | Result |
|--------|------|--------|
| `GET ?action=list` | — | `{ products:[card…], count }` (products no longer sold drop out) |
| `POST ?action=toggle` | `{ "product_id": 42 }` | `{ saved: true/false, count }` · `404 product_not_found` |

Heart tap while signed out → OTP flow, then toggle.

---

## Order updates on WhatsApp (server-side, nothing for the app to call)

The customer gets these on the order's **contact phone** (`contact_phone` sent with
`place`) as well as by email when they gave one. Email is optional at checkout, so
for most app customers WhatsApp is the only message they get.

| When | Template |
|------|----------|
| Payment received (once per order) | `store_order_confirmed` |
| A package ships (at most once per order per day) | `store_order_shipped` |
| Courier is out for delivery (at most once per order per day) | `store_order_out_for_delivery` |
| The **last** package of the order is delivered (once per order) | `store_order_delivered` |
| Items cancelled + refunded (by the customer, seller, admin or auto-cancel) | `store_order_cancelled` |
| Return approved / pickup booked / not accepted | `store_return_update` |
| Return refunded | `store_refund_processed` |
| Unpaid order expired | `store_order_expired` |

A message is sent only if **all** of these are true. Otherwise it is skipped and
logged on `/admin/store/email` (email is unaffected, and an order never fails
because a message failed):
- Store switch on (Store email → Customer WhatsApp updates) and the template is on.
- Platform messaging is on and the template is **approved** in `/admin/messaging`.
- The number has a recorded opt-in. OTP login records one, so the customer's own
  login number qualifies; a different contact number does not.
- The number hasn't turned WhatsApp off (doc 11 → profile `wa_opt_in`) or replied STOP.

Updates raised during quiet hours (default 21:00 to 07:00) are sent at 07:00.
They are never re-sent by SMS.

**Keeping it short for multi-seller orders.** One order from 5 sellers is 5
packages, each shipped and tracked separately. WhatsApp doesn't announce every
package step (email still does, and the app's order screen shows every package):

| Order | WhatsApp messages (normal case) |
|-------|---------------------------------|
| 1 seller | Confirmed · Shipped · Out for delivery · Delivered = **4** |
| 5 sellers, all ship the same day, arrive the same day | Confirmed · Shipped · Out for delivery · Delivered = **4** |
| 5 sellers, ship on 3 different days, arrive on 3 different days | 1 + 3 + 3 + 1 = **8** (worst case 1 + 5 + 5 + 1 = 12, previously 16) |

Cancellations, refunds and return updates are still sent each time they happen.
The "shipped" / "out for delivery" message names the package that triggered it;
the other packages' tracking numbers are in the app and the emails.

### Template texts to submit to Meta (category UTILITY, language English `en`)
Template names = the keys below. `{{n}}` order = the `variables` column in
`wa_templates` (seeded by the patch). Submit exactly this text, then mark each one
**approved** in `/admin/messaging` once Meta approves it.

**`store_order_confirmed`** — {{1}} first name · {{2}} order number · {{3}} amount paid · {{4}} number of packages · {{5}} order link
```
Hi {{1}}, thank you for shopping on eClinicPro Store.

Your order {{2}} is confirmed and we have received your payment of {{3}}. It will reach you in {{4}} package(s), and we will message you as each one ships.

View your order: {{5}}

Team eClinicPro Store
```
Sample: Priya · ECS260929-7K3MQ · ₹1,249 · 2 · https://eclinicpro.com/store/order/ECS260929-7K3MQ

**`store_order_shipped`** — {{1}} first name · {{2}} seller · {{3}} order number · {{4}} courier · {{5}} tracking number (AWB) · {{6}} tracking link
```
Hi {{1}}, your package from {{2}} for order {{3}} has been shipped.

Courier: {{4}}
Tracking number: {{5}}
Track your package: {{6}}

Team eClinicPro Store
```
Sample: Priya · Wellness Mart · ECS260929-7K3MQ · Delhivery · 1234567890 · https://shiprocket.co/tracking/1234567890

**`store_order_out_for_delivery`** — same parameters as `store_order_shipped`
```
Hi {{1}}, your package from {{2}} for order {{3}} is out for delivery today. Please keep your phone reachable for the delivery agent.

Courier: {{4}}
Tracking number: {{5}}
Track your package: {{6}}

Team eClinicPro Store
```

**`store_order_delivered`** — {{1}} first name · {{2}} order number · {{3}} order link (sent once, when the last package arrives)
```
Hi {{1}}, everything in your eClinicPro Store order {{2}} has now been delivered.

If an item is damaged, wrong or expired, you can request a return from your order page within the return window: {{3}}

Team eClinicPro Store
```

**`store_order_cancelled`** — {{1}} first name · {{2}} order number · {{3}} who cancelled ("as you requested" / "by the seller" / "by the eClinicPro team" / "because the seller did not confirm the order in time") · {{4}} refund amount · {{5}} refund reference
```
Hi {{1}}, items in your order {{2}} were cancelled {{3}}.

We have refunded {{4}} to your original payment method (refund reference {{5}}). Refunds usually reach your account in 5 to 7 working days, depending on your bank.

Team eClinicPro Store
```
Sample: Priya · ECS260929-7K3MQ · as you requested · ₹499 · RF260930-A1B2C3

**`store_refund_processed`** — {{1}} first name · {{2}} refund amount · {{3}} return number · {{4}} order number
```
Hi {{1}}, we have refunded {{2}} for your return {{3}} (order {{4}}) to your original payment method.

Refunds usually reach your account in 5 to 7 working days, depending on your bank.

Team eClinicPro Store
```

**`store_return_update`** — {{1}} first name · {{2}} return number · {{3}} order number · {{4}} the update (one sentence or two) · {{5}} order link
```
Hi {{1}}, there is an update on your return {{2}} for order {{3}}.

{{4}}

See the details: {{5}}

Team eClinicPro Store
```
Sample {{4}}: "The seller approved your return. A courier will collect the item from your delivery address. Please keep it packed with all tags and accessories."

**`store_order_expired`** — {{1}} first name · {{2}} order number · {{3}} order amount · {{4}} cart link
```
Hi {{1}}, we did not receive the payment for your eClinicPro Store order {{2}} of {{3}} in time, so the order was cancelled and nothing was charged.

Your cart is still saved if you want to check out again: {{4}}

Team eClinicPro Store
```

---

## Error codes (store)

| HTTP | `error` | Meaning / app action |
|------|---------|----------------------|
| 404 | `store_unavailable` | Store hidden: hide the Shop tab. |
| 503 | `store_temporarily_unavailable` | Server couldn't load the store services: "Please try again shortly". |
| 401 | `login_required` | OTP flow, then retry. |
| 404 | `not_found` · `item_not_found` · `product_not_found` | Stale screen: go back / refresh. |
| 404 | `pin_not_found` | Pincode not in our list: let the customer type city and state. |
| 409 | `cart_empty` · `cart_needs_attention` · `cannot_cancel` | Go back to the cart / refresh the order. |
| 422 | `cannot_add` · `coupon_invalid` · `invalid_address` · `address_required` · `invalid_contact` · `cannot_place` · `cannot_pay` · `payment_mismatch` · `cannot_review` · `cannot_return` | Show `message`. |
| 429 | `too_many_attempts` | Show `message`. Coupon: 10 / 10 min. Pay: 30 / 10 min. Pincode: 60 / 10 min (per IP). |
| 400 | `invalid_pin` | Show `message` (pincode must be 6 digits). |
| 400 | `unknown_action` · `unknown_scope` · `product_required` | Bug in the app call. |

---

## Endpoint → URL map (add to doc 11 §2)

| Feature | Method | URL |
|---------|--------|-----|
| Store home | GET | `/store.php?action=home` |
| All categories | GET | `/store.php?action=categories` |
| Listing / search / seller page | GET | `/store.php?action=listing&scope=…&slug=…` |
| Product | GET | `/store.php?action=product&slug=…` |
| Product reviews | GET | `/store.php?action=reviews&product_id=…` |
| Cart | GET/POST | `/store_cart.php?action=get · add · set · coupon` |
| Checkout summary | GET | `/store_checkout.php?action=summary` |
| Addresses | GET/POST | `/store_checkout.php?action=addresses · address_add · address_update · address_set_default · address_remove` |
| Pincode lookup (public) | GET | `/store_checkout.php?action=pincode&pin=…` |
| Place order | POST | `/store_checkout.php?action=place` |
| Pay | POST | `/store_checkout.php?action=pay_start · pay_verify` |
| My orders | GET | `/store_orders.php?action=list` |
| Order detail | GET | `/store_orders.php?action=detail&order_no=…` |
| Order actions | POST | `/store_orders.php?action=cancel · cancel_items · review · return` |
| Invoice (HTML) | GET | `/store_orders.php?action=invoice&order_no=…&doc=…` |
| Wishlist | GET/POST | `/store_wishlist.php?action=list · toggle` |

Orders placed from the app are stored with `source = 'mobile'` (the website
stores `web`), so admin can tell the channels apart.

---

## curl smoke tests (run on the server before coding)

```bash
B=https://eclinicpro.com/api/mobile/v1
P='X-Store-Preview: <store_preview_key>'      # only while the store is hidden
T='Authorization: Bearer <token from verify_otp>'

# 1. catalog (public)
curl -s -H "$P" "$B/store.php?action=home" | head -c 600
curl -s -H "$P" "$B/store.php?action=categories" | head -c 400
curl -s -H "$P" "$B/store.php?action=listing&scope=search&q=vitamin" | head -c 600
curl -s -H "$P" "$B/store.php?action=product&slug=<a live product slug>" | head -c 800
# hidden store without the preview header must be 404 store_unavailable
curl -s "$B/store.php?action=home"

# 2. guest cart → note cart.cart_token in the response
curl -s -H "$P" -H 'Content-Type: application/json' -X POST \
  -d '{"variant_id":<id>,"qty":1}' "$B/store_cart.php?action=add"
C='X-Cart-Token: <cart_token from above>'
curl -s -H "$P" -H "$C" "$B/store_cart.php?action=get"

# 3. log in, then merge: the guest line must now be in the patient's cart
curl -s -H "$P" -H "$C" -H "$T" "$B/store_cart.php?action=get"

# 4. checkout (creates a REAL pending order and reserves stock; cancel it after)
curl -s -H "$P" -H "$T" "$B/store_checkout.php?action=summary"
curl -s -H "$P" -H "$T" -H 'Content-Type: application/json' -X POST \
  -d '{"checkout_key":"<from summary>","address_id":<id>,"contact_name":"Test","contact_phone":"9xxxxxxxxx"}' \
  "$B/store_checkout.php?action=place"
curl -s -H "$P" -H "$T" -H 'Content-Type: application/json' -X POST \
  -d '{"order_no":"<ECS…>"}' "$B/store_checkout.php?action=pay_start"     # expect checkout.key + order_id

# 5. orders
curl -s -H "$P" -H "$T" "$B/store_orders.php?action=list"
curl -s -H "$P" -H "$T" "$B/store_orders.php?action=detail&order_no=<ECS…>"
curl -s -H "$P" -H "$T" -H 'Content-Type: application/json' -X POST \
  -d '{"order_no":"<ECS…>"}' "$B/store_orders.php?action=cancel"          # releases the test stock

# 6. auth checks: no token → 401; someone else's order_no → 404
curl -s -H "$P" "$B/store_orders.php?action=list"

# ---- 7. added 2026-10-05 (run the SQL patch 2026_10_05_store_whatsapp.sql first) ----
J='Content-Type: application/json'

# pincode (public: no token)
curl -s -H "$P" "$B/store_checkout.php?action=pincode&pin=380001"   # Ahmedabad, Gujarat, serviceable, eta_days
curl -s -H "$P" "$B/store_checkout.php?action=pincode&pin=500001"   # state must be "Telangana"
curl -s -H "$P" "$B/store_checkout.php?action=pincode&pin=38001"    # 400 invalid_pin
curl -s -H "$P" "$B/store_checkout.php?action=pincode&pin=999999"   # 404 pin_not_found
curl -s -H "$P" -X POST "$B/store_checkout.php?action=pincode&pin=380001"   # 405 method_not_allowed

# address edit + default (note an address id from ?action=addresses)
curl -s -H "$P" -H "$T" "$B/store_checkout.php?action=addresses"
curl -s -H "$P" -H "$T" -H "$J" -X POST -d '{"address_id":<id>,"landmark":"Near City Mall"}' \
  "$B/store_checkout.php?action=address_update"         # address.landmark changed, other fields kept
curl -s -H "$P" -H "$T" -H "$J" -X POST -d '{"address_id":<id>,"state":"Atlantis"}' \
  "$B/store_checkout.php?action=address_update"         # 422 invalid_address + message
curl -s -H "$P" -H "$T" -H "$J" -X POST -d '{"address_id":<id>,"phone":"12345"}' \
  "$B/store_checkout.php?action=address_update"         # 422 invalid_address + message
curl -s -H "$P" -H "$T" -H "$J" -X POST -d '{"address_id":<id>}' \
  "$B/store_checkout.php?action=address_set_default"    # addresses[0].id == <id>, is_default true
# foreign id → 404 (an address id that belongs to ANOTHER test customer)
curl -s -H "$P" -H "$T" -H "$J" -X POST -d '{"address_id":<other customer id>,"landmark":"x"}' \
  "$B/store_checkout.php?action=address_update"         # 404 not_found
curl -s -H "$P" -H "$T" -H "$J" -X POST -d '{"address_id":<other customer id>}' \
  "$B/store_checkout.php?action=address_set_default"    # 404 not_found
# no token → 401
curl -s -H "$P" -H "$J" -X POST -d '{"address_id":<id>}' "$B/store_checkout.php?action=address_update"
curl -s -H "$P" -H "$J" -X POST -d '{"address_id":<id>}' "$B/store_checkout.php?action=address_set_default"
# past orders keep their address: order detail must still show the OLD landmark
curl -s -H "$P" -H "$T" "$B/store_orders.php?action=detail&order_no=<an ECS… placed before the edit>"

# WhatsApp order updates: no API call. On /admin/store/email → "Customer WhatsApp updates":
#   send a test of each template to your own number, then place + pay a sandbox order
#   and check the log at the bottom of that page (Queued → Sent once the worker runs).
```
To test the full Razorpay path without real money, set Store settings → Payments
to *Sandbox* (needs `RAZORPAY_TEST_*` keys in `app/.env`). That switch applies
to the **website store too**, so only use it while the store is still hidden,
and switch back to Live before launch.
