# 10 — Backend API Mapping (eClinicPro Reality Check)

**Purpose:** Documents 01–09 describe the app we *want*. This document maps that
wishlist onto the eClinicPro backend that *actually exists* today, so nobody
builds the Flutter app against a contract the server does not honour.

Everything below is derived from reading the live PHP under `myclinic/api/*` and
`myclinic/partials/*`. Where the app doc and the real backend disagree, **the
backend as-built wins** unless we deliberately change it.

> **Backend repo:** `~/myclinic` &nbsp;•&nbsp; **App repo:** `~/appmycliflut`
> **Live host:** `https://eclinicpro.com`

---

## 0. TL;DR — the five things that are different from doc 05

| # | Doc 05 assumed | Backend reality | Impact |
|---|----------------|-----------------|--------|
| 1 | Response `{ success, data }` | **`{ ok: true, … }` / `{ ok:false, error:"code" }`** | Rewrite the app's `ApiResult` parser around `ok`. |
| 2 | `Authorization: Bearer <jwt>` | **httpOnly cookie `ecp_pid`** = a 64-char session token in `patient_sessions` | Needs a small backend change to accept the same token as a Bearer header for mobile (see §2). |
| 3 | OTP via MSG91/Twilio/Firebase | **WhatsApp OTP** (Meta), SMS fallback; dev mode writes to `storage/logs/otp.log` | No new provider needed. Beware WhatsApp WABA ban remediation is in progress. |
| 4 | REST `/v1/appointments` etc. | Flat PHP files with **`?action=` dispatch** (`/api/patient_auth.php?action=send_otp`) | Either wrap in a mobile router, or the app calls the existing files directly. |
| 5 | One `appointments` source | Bookings = **`appointments` (claimed clinics) + `directory_leads` (unclaimed)** merged | App's appointment list must render two shapes/states. |

**Bottom line:** ~70% of the patient app can ship against endpoints that already
exist. The rest needs new-but-small backend endpoints, listed in §7.

> ✅ **Update (2026-07-10):** The launch-critical façade is BUILT and DEPLOYED at
> `~/myclinic/api/mobile/v1/` — `auth.php`, `home.php`, `doctors.php`,
> `appointments.php`, plus shared `_bootstrap.php`. It implements the Bearer
> flow (§2) and the unified booking flow, delegating to the same `ecp_*`
> functions the website uses. **The frozen request/response contract is
> [11 — Mobile API Reference](./11-mobile-api-reference.md) — code the app
> against that.**
>
> **Smoke test:** public GET endpoints (`doctors search`, `doctors detail`,
> `auth me`) **verified live on eclinicpro.com (2026-07-10)** — correct envelope
> and shapes. Still to confirm via curl: the POST + Bearer flow (OTP → token →
> home/appointments/book) and logged-out `me`→`null` (browser test was masked by
> the website cookie). See doc 11's curl block.

---

## 1. Actual response & error envelope

Every patient API returns this shape (not `success/data`):

```jsonc
// success
{ "ok": true, "items": [ … ] }          // lists
{ "ok": true, "profile": { … } }         // singletons vary the key name
// failure
{ "ok": false, "error": "login_required" }
```

- HTTP status is *also* set correctly (401, 404, 429, 503…), so the app can
  branch on status first and read `error` for the specific code.
- **Key names are not uniform** — `items`, `profile`, `members`, `upcoming`,
  `patient`… Each endpoint documents its own. Don't assume a generic `data`.

**App action:** model `ApiResult` around `ok`; keep a small per-endpoint decoder
rather than one generic `{success,data}` wrapper.

### Known `error` codes seen in code

`login_required`, `method_not_allowed`, `server_error`, `unknown_action`,
`phone_required`, `phone_and_code_required`, `invalid_phone`, `invalid_code`,
`expired`, `no_code_issued`, `too_many_attempts`, `resend_too_soon`,
`otp_locked`, `account_not_found`, `account_exists`, `db_unavailable`.

---

## 2. Auth — the one real blocker, and how to fix it cheaply

### How web auth works today
1. `POST /api/patient_auth.php?action=send_otp` `{ phone, intent }` → WhatsApp OTP.
2. `POST …?action=verify_otp` `{ phone, code, name? }` → **creates a
   `patient_sessions` row** with a `bin2hex(random_bytes(32))` = 64-char hex
   token, and sets it as the **httpOnly `ecp_pid` cookie** (30-day rolling).
3. Every protected endpoint calls `ecp_patient_current()`, which reads the
   `ecp_pid` cookie, looks the token up in `patient_sessions`, and returns the
   `patient_identities` row. 401 if missing/expired.

### Why this matters for Flutter
Mobile apps *can* hold cookies (via `dio_cookie_manager`), and the cheapest path
is: **let the app keep the `ecp_pid` cookie and send it back** — zero backend
change. But cookies on native apps are fragile (domain rules, `SameSite`,
clearing on reinstall) and doc 04 already specifies secure-storage + a Bearer
interceptor.

### Recommended backend change (small, ~1 file)
The session token already *is* a bearer token — it's just delivered via cookie.
Add one helper so `ecp_patient_current()` also accepts it from a header:

```php
// in partials/patient_auth.php, inside ecp_patient_current()
$token = $_COOKIE[ECP_PAT_COOKIE] ?? '';
if ($token === '') {
    $hdr = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/Bearer\s+([0-9a-f]{64})/i', $hdr, $m)) {
        $token = $m[1];               // same table, same validation below
    }
}
```

Then `verify_otp` should **also return the raw token** in its JSON (today it only
sets the cookie), so the app can store it:

```jsonc
{ "ok": true, "is_new": false,
  "token": "…64 hex…",              // NEW: app puts this in secure storage
  "patient": { "id": 42, "name": "…", "phone": "+91…", "email": null } }
```

With those two edits the app uses the exact **Bearer flow doc 04 already
designed**, reusing the existing sessions table, OTP throttling, and `logout`
(which just deletes the session row). No JWT, no refresh-token machinery needed
for v1 — the 30-day rolling session is enough; add refresh later only if you want
short-lived access tokens.

> ⚠️ **Verify on server, not locally.** Per project memory there is no local PHP
> runtime here; these files run on the eclinicpro.com host. Confirm the cookie
> domain / `SameSite=Lax` behaviour there before relying on cookie mode.

---

## 3. Endpoint mapping — app need → what exists today

Legend: **✅ exists** • **🟡 partial / needs shaping** • **🔴 must build (see §7)**

### Auth
| App need | Status | Real endpoint |
|----------|--------|---------------|
| Request OTP | ✅ | `POST /api/patient_auth.php?action=send_otp` `{phone,intent}` |
| Verify OTP | ✅ | `POST …?action=verify_otp` `{phone,code,name?}` (add `token` to response, §2) |
| Current patient | ✅ | `GET …?action=me` |
| Logout | ✅ | `POST …?action=logout` |
| Token refresh | 🔴 | Not needed if using rolling session; else build |

### Doctors / discovery
| App need | Status | Real endpoint |
|----------|--------|---------------|
| Search doctors | ✅ | `GET /api/search_doctors.php?q&country&state&city&area&spec&min_rating&sort&lat&lng&max_km&page&per_page` |
| Nearby | ✅ | same endpoint with `lat,lng,max_km,sort=distance` |
| Doctor detail | 🟡 | `find-a-doctor` renders detail server-side; needs a JSON `?action=detail&id=` (small) |
| Reviews | 🟡 | Check `directory_doctors` review fields; likely 🔴 dedicated list endpoint |
| Slots / availability | 🔴 | **No slot API exists** — see §5, biggest booking gap |
| Save / unsave doctor | ✅ | `api/wishlist.php` (verify verbs & shape) |
| Saved list | ✅ | `api/wishlist.php` |
| Specialties / locations | ✅ | `api/locations.php` (+ specialty taxonomy in search filters) |

### Appointments
| App need | Status | Real endpoint |
|----------|--------|---------------|
| Book (claimed clinic) | 🟡 | `api/book.php` exists (thin) — confirm it writes `appointments`; may need payload alignment |
| Book (unclaimed doctor) | ✅ | `api/lead.php` → writes `directory_leads` (patient ack + doctor SMS alert, 10/mo cap) |
| Upcoming / Past | ✅ | `GET /api/patient_bookings.php` → `{upcoming, past, pending_leads}` |
| Appointment detail | 🟡 | Derivable from list; add `?id=` for a single row if needed |
| Cancel | 🔴 | No patient-facing cancel endpoint found — build |
| Reschedule | 🔴 | Build (depends on slots, §5) |
| Video session token | 🔴 | No video backend yet — provider decision pending |

### Health locker
| App need | Status | Real endpoint |
|----------|--------|---------------|
| Prescriptions list / detail / file | ✅ | `api/patient_prescriptions.php` (`?action=file&id=` streams PDF/image, ownership-checked) |
| Upload prescription | ✅ | `…?action=add` (multipart) |
| Profile medical notes | ✅ | `api/patient_profile.php` (medical/lifestyle fields live on `patient_identities`) |
| Labs, Documents, Invoices, Vaccination, Allergies, Vitals, Timeline, Medicine history | 🔴 | **Not built** — these are locker features the web panel doesn't expose yet |

### Family
| App need | Status | Real endpoint |
|----------|--------|---------------|
| List / add / update / remove members | ✅ | `api/family.php` (`?action=save_member` / `remove_member`) |
| Records scoped to member | 🟡 | Data model supports it; needs read endpoints once locker (§ above) exists |

### Profile & settings
| App need | Status | Real endpoint |
|----------|--------|---------------|
| Get / save profile | ✅ | `api/patient_profile.php` (`?action=save`, partial writes) |
| Avatar upload / stream | ✅ | `…?action=photo` (POST upload / GET stream) |
| Change phone (OTP) | ✅ | `…?action=send_phone_otp` / `verify_phone_otp` |
| Insurance, Addresses, Emergency contact | 🟡 | Some fields already on the identity row; confirm coverage vs app's needs |
| Language / notification prefs | 🔴 | Build a small preferences endpoint |

### Content & engagement
| App need | Status | Real endpoint |
|----------|--------|---------------|
| Blogs list / detail | 🟡 | Blogs live on a **separate WordPress server** (see `fetch_blog`); app hits WP REST API directly, not `/api/mobile` |
| Today's health tip | 🔴 | Build, or derive from WP category |
| Health packages | 🔴 | Only a static store mockup exists (`eclinicpro-health-store`); no DB/cart |
| Notifications feed | 🔴 | Build; FCM device registration also 🔴 |
| Chat with clinic | 🔴 | Not built |
| Payments | 🟡 | **Cashfree** is wired for *doctor* subscriptions, not patient appointment payments — no patient payment flow exists yet |

---

## 4. Data model notes the app team must know

- **Two-layer patient model.** `patient_identities` = the person/login (this is
  what `ecp_patient_current()` returns and what the whole app is scoped to).
  `patients` = a clinic's chart record. The app lives almost entirely in the
  identity layer. Bookings create the clinic-side copies.
- **Family** members are separate identity rows (`family_member_identities`),
  copied into `patient_family_members` only at booking time. "Booking as" a
  family member is a first-class concept — keep `activeFamilyMemberProvider`
  (doc 04) in the design.
- **Doctors span 4 tables.** The public directory the app searches is
  `directory_doctors`. Joined/claimed doctors also have `users` + `tenants` +
  `doctor_profiles` rows. Booking a *claimed* doctor targets `users`; an
  *unclaimed* directory doctor goes through the **lead** flow, not a real slot.
- **Directory phones** are normalised to `+91XXXXXXXXXX`. Reuse that format in
  the app for `tel:` links and WhatsApp deep links.
- **Prescriptions** are one table (`patient_prescriptions`) holding both
  patient-uploaded files and doctor-shared ones; files stream through PHP with an
  ownership re-check — the app should render them via the `?action=file&id=`
  URL (attach the Bearer token), not expect a public S3 URL.

---

## 5. The booking gap (read this before promising "Book Appointment")

The app's flagship flow — pick doctor → pick slot → confirm → pay — **is only
half-supported**:

- **Unclaimed directory doctors** (the vast majority of the directory) have **no
  calendar**. Booking them today = a *lead*: patient gets an acknowledgement,
  the doctor gets an SMS alert (capped 10/month), and an admin follows up. The
  app must present these as **"Request appointment"**, not a confirmed slot.
- **Claimed clinics** *can* have real appointments (`appointments` table), but
  there is **no public slot-availability API** and no patient cancel/reschedule
  endpoint. Those are the highest-value backend items to build (§7).
- **Patient payments** are not wired at all (Cashfree today only sells doctor
  subscriptions).

**Recommendation:** For v1, ship booking as the **lead/request model everywhere**
(it already works end-to-end), and treat real-time slot booking + payment as
**Phase 2** once the slot and payment endpoints exist. This lets the app launch
without waiting on the hardest backend work.

---

## 6. Two integration strategies — pick one

**A. App calls existing PHP files directly** (`/api/*.php?action=…`)
- ➕ Zero/near-zero backend work for the ✅ rows above; fastest to first build.
- ➖ Inconsistent response keys; `?action=` isn't the clean REST doc 05 wanted;
  auth needs the small Bearer patch (§2).

**B. Add a thin `/api/mobile/v1/*` façade** that internally calls the same
partials and returns a **uniform `{ok,data,error}` + Bearer auth**.
- ➕ Clean, versioned, matches docs 04/05; one place to add rate-limiting/logging.
- ➖ A few days of backend work up front.

**Recommendation:** **B, but incrementally.** Stand up the façade with just
`auth`, `home`, `doctors`, `appointments` first (the launch-critical set), each
delegating to existing partials. Add locker/notifications/payments routes as those
features get real backends. This gives the app the clean contract from doc 05
*and* reuses all the tested business logic already in `partials/`.

---

## 7. Backend build list (prioritised)

**P0 — needed for a coherent patient app**
1. Bearer-token acceptance + return `token` from `verify_otp` (§2). *~1 file.*
2. `GET /home` aggregate (greeting, next appointment, saved count, latest blogs,
   one health tip) to avoid a request waterfall on the dashboard.
3. Doctor **detail** JSON endpoint (`?action=detail&id=`), reviews list.
4. Device registration for FCM + a notifications feed.

**P1 — completes the core loops**
5. Slot availability API for claimed clinics (§5).
6. Patient **cancel / reschedule** appointment endpoints.
7. Preferences endpoint (language, notification toggles).

**P2 — locker depth & money**
8. Labs, documents, invoices, vaccination, allergies, vitals, medicine history,
   timeline read/write endpoints (currently none exist).
9. Patient appointment **payments** (extend Cashfree or add gateway).
10. Chat with clinic.
11. Video consultation backend (provider TBD — Agora/Daily/Zoom).

---

## 8. What to change in the existing docs

- **05-api-contract.md** — add a banner: "Target contract; see 10 for what exists
  today." Replace the `{success,data}` examples with `{ok,…}`. Note OTP =
  WhatsApp, auth token = reused session token.
- **08-recommendations.md** §3.6 already says "align phone/OTP with existing
  eClinicPro web auth" — this doc is the concrete answer: **reuse
  `patient_sessions`**.
- **README.md** — link this doc as the source of truth for backend integration.

---

## 9. Immediate next steps (mobile + backend, in order)

1. **Backend:** apply the Bearer patch (§2) and return `token` — unblocks the app
   entirely. *Smallest change, biggest unblock.*
2. **Backend:** stand up `/api/mobile/v1/{auth,home,doctors,appointments}` façade
   (strategy B, launch-critical subset).
3. **App:** wire `ApiResult` around `ok`, secure-storage the token, dio Bearer
   interceptor with 401→logout (refresh optional).
4. **App:** build Auth → Home → Doctors(search/detail) → Appointments(list +
   request/lead flow) against the façade.
5. **Defer** slot booking, payments, full locker, chat, video to Phase 2 per §5/§7.

> Keep this document updated as backend endpoints land — flip 🔴/🟡 rows to ✅ and
> record the final path/shape next to each.
