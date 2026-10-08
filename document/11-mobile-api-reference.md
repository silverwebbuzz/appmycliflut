# 11 — Mobile API Reference (v1, as built)

**This is the frozen contract.** These endpoints exist in the backend today at
`~/myclinic/api/mobile/v1/*.php` and are the ones to code the Flutter app
against. Every route is a thin adapter over the same `ecp_*` functions the
website uses, so **app and web behave identically** and future server changes
(booking notifications, quotas, OTP channel) reflect in the app with no app
update.

- **Base URL (CONFIRMED — use this exact value):** `https://eclinicpro.com/api/mobile/v1`
  This is the single production base URL for v1. No dev/staging flavor split for
  now. When Flutter coding starts, put this in one config constant (e.g.
  `kApiBaseUrl`) and reference it everywhere — do not hardcode per-call.
- **Envelope:** success `{ "ok": true, … }` · failure `{ "ok": false, "error": "code" }`
- **Auth:** `Authorization: Bearer <token>` where `<token>` is the 64-char hex
  session token returned by `auth.php?action=verify_otp`. Store it in secure
  storage. On `401 login_required`, clear it and route to Login.
- **Content-Type:** send `application/json` for POST bodies.
- **Paths include `.php`** (e.g. `/auth.php?action=send_otp`). That's the
  canonical form and needs no rewrite rules. (A pretty-URL rewrite can be added
  later without changing behaviour.)

> **Smoke test status (2026-07-10, live on eclinicpro.com):**
> - ✅ `doctors.php?action=search` (with/without `city`), `?action=detail` — correct.
> - ✅ `send_otp` — sends a **real WhatsApp OTP** (server is in `mode:"live"`,
>   `dev_code:null`). `verify_otp` — returns a valid 64-char token + patient.
> - ✅ Logged-out `me` (no token) → `patient:null`. Token via **cookie** → works.
>   So the auth *logic* is fully correct.
> - ✅ **Bearer auth FIXED & VERIFIED (deployed).** The Apache header-stripping
>   bug is resolved via `api/mobile/.htaccess` + hardened `ecp_m_bearer_token()`.
>   Confirmed live: `me`, `home.php`, and `appointments.php?action=list` all
>   return correct data when called with `Authorization: Bearer <token>`.
>
> **Net: the full launch-critical flow (OTP → token → authed reads) is verified
> live on eclinicpro.com.** Save/unsave and `book` share the same verified auth
> path and delegate to already-proven server functions.

> **Added 2026-09-23 — NOT yet smoke-tested on the server:** `queue.php`,
> `prescriptions.php`, `lab_reports.php`, `family.php`, `profile.php`. They are
> thin adapters over the same `ecp_*` functions the website's patient panel
> already uses in production, and they sit under `api/mobile/` so the verified
> Bearer-header fix applies. Still: **run the curl checks below before coding
> against them.** They were written without a local PHP runtime, so they have not
> been executed anywhere yet.
>
> **Deliberately NOT built (waiting on Thyrocare's mobile support):** the lab
> catalog and lab booking/checkout endpoints. The app's Labs tab is out of scope
> for this round — `lab_reports.php` is the *patient's own uploaded reports*
> vault and is unrelated to booking.

---

## Auth — `auth.php`

> 📱 **OTP is delivered via WhatsApp** (not SMS). The app UI MUST say so:
> - Login screen: "We'll send a verification code to your **WhatsApp**."
> - OTP screen: "Enter the 6-digit code from **WhatsApp**." (code expires in 10 min)
> - Disclose WhatsApp OTP in the store privacy/permission rationale.
> The number must be a real WhatsApp-registered number. (Server is in live mode;
> `dev_code` is only returned when the server runs in dev mode.)

### `POST ?action=send_otp`
Body: `{ "phone": "9374249829", "intent": "signin"|"signup"|"" }`
`intent` is optional; when set, the server rejects a mismatch
(`account_not_found` / `account_exists`).

```json
{ "ok": true, "phone": "+919374249829", "mode": "live",
  "exists": true, "name_hint": "Ravi", "dev_code": null }
```
- `exists` → app knows whether to ask for a name on the next step.
- `dev_code` is the OTP **only in dev mode** (`mode:"dev"`); `null` in live.
- Errors: `phone_required`(400), `account_not_found`(404), `account_exists`(409),
  `invalid_phone`(400), `resend_too_soon`/`otp_locked`(429), `db_unavailable`(503).

### `POST ?action=verify_otp`
Body: `{ "phone": "9374249829", "code": "123456", "name": "Ravi", "referral_code": "ECP-RAHUL7K" }`
`name` is used only when creating a brand-new identity.
`referral_code` (optional, added 2026-10-07) is Refer & Earn: show an optional
"Referral code" field on the **sign-up** step only (when `send_otp` said
`exists: false`). It's attached only to a brand-new account and is silently
ignored if it isn't valid, so never block sign-up on it. See doc 12 → Points.

```json
{ "ok": true, "token": "<64-hex>", "is_new": false,
  "patient": { "id": 42, "name": "Ravi Kumar", "first_name": "Ravi",
               "phone": "+919374249829", "email": null } }
```
- **Store `token`** → send as `Authorization: Bearer <token>` on every
  authenticated call afterwards.
- Errors: `phone_and_code_required`(400), `invalid_code`(400), `expired`(410),
  `no_code_issued`(410), `too_many_attempts`(429), `db_unavailable`(503).

### `GET ?action=me`  *(Bearer optional)*
```json
{ "ok": true, "patient": { "id": 42, "name": "…", … } }   // or "patient": null
```
Use on Splash to restore session (null → go to Onboarding/Login).

### `POST ?action=logout`  *(Bearer)*
Revokes the session row for that token. `{ "ok": true }`.

---

## Home — `home.php`

### `GET`  *(Bearer)*
One aggregate call for the dashboard.
```json
{ "ok": true,
  "patient": { "id": 42, "first_name": "Ravi", … },
  "next_appointment": { "kind":"appointment"|"lead", … } | null,
  "counts": { "upcoming": 1, "pending_requests": 2, "saved_doctors": 3 },
  "content_sources": { "blogs": "wordpress_rest", "tips": "wordpress_rest" } }
```
- `next_appointment` uses the same shape as an item in the appointments list.
- **Blogs & today's tip are NOT here** — fetch them directly from the WordPress
  REST API (separate server; see doc 10). This keeps Home fast.

---

## Doctors — `doctors.php`

### `GET ?action=search`  *(public)*
Query params: `q, country(=IN), state, city, area, spec, min_rating,
sort(relevance|distance|rating|fee_asc|fee_desc|claimed), lat, lng, max_km,
page(=1), per_page(=20)`.
```json
{ "ok": true, "items": [ { doctor card… } ],
  "page": 1, "per_page": 20, "has_more": true, "total": 137 }
```
Each card includes: `id, name, doctorName, clinicName, spec, specLabel,
verified, is_claimed, rating, reviews, area, city, state, country, fee,
currency, phone, website, gmaps_url, lat, lng, address, photo_url,
avatar_gradient, distance_km, next`.

### `GET ?action=detail&id=123`  *(public)*
```json
{ "ok": true, "doctor": { …same fields as a card, plus
   "initials", "can_request_appointment": true } }
```
Errors: `doctor_id_required`(400), `not_found`(404).

### `GET ?action=saved`  *(Bearer)*
```json
{ "ok": true, "items": [ { "id","name","specLabel","area","city","phone",
   "gmaps_url","rating","reviews","added_at","note" } ], "count": 3, "max": 5 }
```

### `POST ?action=save`  *(Bearer)* — Body `{ "doctor_id": 123, "note": "opt" }`
```json
{ "ok": true, "doctor_id": 123, "in_wishlist": true }
```
Errors: `doctor_id_required`(400), `limit_reached`(409, includes `"limit":5`).

### `POST ?action=unsave`  *(Bearer)* — Body `{ "doctor_id": 123 }`
```json
{ "ok": true, "doctor_id": 123, "in_wishlist": false }
```

---

## Appointments — `appointments.php`

### `GET ?action=list`  *(Bearer)*
```json
{ "ok": true,
  "count": { "upcoming": 1, "past": 4, "pending": 2 },
  "upcoming": [ { appt… } ],
  "past": [ { appt… } ],
  "pending_leads": [ { lead… } ] }
```
- **Appointment item** (`kind:"appointment"`): `id, when_iso, when_date,
  when_time, status, is_followup, token_number, reason, doctor_name,
  doctor_spec, clinic_name, clinic_slug, clinic_phone, clinic_address`.
- **Lead item** (`kind:"lead"` / pending): request to an unclaimed clinic that
  hasn't been confirmed. Shape from `_patient_shape_lead()`.

### `POST ?action=book`  *(Bearer)* — **the unified booking call**
Body: `{ "doctor_id":123, "preferred_date":"2026-07-14",
"preferred_time":"17:30", "reason":"Back pain" }`
```json
{ "ok": true, "lead_id": 987, "sms_status": "sent",
  "message": "We've notified the clinic. They'll call you within 24 hours." }
```
- This records a `book_submitted` request and fires the doctor alert through the
  **same** SMS/WhatsApp + quota + quiet-hours pipeline as the website. The app
  should show `message` verbatim (it already reflects quota/quiet outcomes).
- `sms_status` ∈ `sent | suppressed_quota | suppressed_quiet | suppressed_paused
  | not_applicable`.
- Rules enforced (same as web): date within **next 7 days**, not in past; **max 5
  requests/hour** per patient.
- Errors: `doctor_id_required`, `date_required`, `time_required`,
  `date_in_past`, `date_out_of_window` (all 400), `too_many_requests`(429).

### `POST ?action=track`  *(Bearer optional)* — Body `{ "doctor_id":123, "type":"view"|"call" }`
Lightweight analytics event. `{ "ok": true, "sms_status": … }`.

> **v1 scope:** booking = request/lead for *all* doctors (matches web). Confirmed
> slot booking, **cancel**, **reschedule**, **video**, and **patient payments**
> are not built yet — see doc 10 §7 for the backend build list.

---

## Queue — `queue.php`

Backs the design's live token screen ("now serving A-09 · you are A-14").

> **How tokens really work** (`AppointmentService::nextTokenNumber`): tokens are
> per **clinic, per day** — *not* per doctor — and are assigned only when
> reception moves a visit to `in_progress`. A scheduled/confirmed appointment
> has **no token yet**, so the app must handle `has_token:false`.

### `GET ?action=status`  *(Bearer)*
Optional `&appointment_id=123` — otherwise the soonest upcoming appointment.
Only the patient's own appointments are considered; a foreign id → `404 not_found`.

```json
{ "ok": true,
  "in_queue": true, "reason": null,
  "appointment": { "appointment_id": 41, "when_iso": "2026-09-23T17:40:00+05:30",
                   "status": "confirmed", "doctor_name": "Dr. Arjun Shah",
                   "clinic_id": 7, "clinic_name": "Shah Family Clinic",
                   "clinic_phone": "+91…" },
  "queue": { "has_token": true, "my_token": 14, "now_serving": 9, "ahead": 5,
             "waiting": 12, "token_scope": "clinic_day",
             "checked_at": "2026-09-23T17:05:11+05:30", "poll_seconds": 30 } }
```
- `in_queue:false` + `reason:"appointment_not_today"` → show the appointment
  card, not the queue. `reason:"no_upcoming_appointment"` → empty state.
- `ahead` is an **estimate** and is `null` until both `my_token` and
  `now_serving` exist. It is never negative.
- Poll only while the Queue screen is open; `poll_seconds` (30) is the hint.

---

## Prescriptions — `prescriptions.php`

The patient-owned Rx vault (`patient_prescriptions`). Two sources in one table:
`upload` = the patient added a photo/PDF · `clinic` = a doctor shared it.

> ⚠️ **Design gap — read before building the Rx detail screen.** The DB stores a
> **file + label snapshot**. It does **not** store structured medicine lines
> (name / `1-0-1` / duration), diagnosis or advice text. The design's itemised
> Rx card **cannot be rendered from this data**. Show the metadata below plus the
> file itself in a PDF/image viewer.

### `GET ?action=list`  *(Bearer)* → `{ count, items:[…] }`
### `GET ?action=detail&id=123`  *(Bearer)* → `{ item }`
```json
{ "id": 12, "family_member_id": null, "label": "Dr. Shah — 12 Aug — Diabetes",
  "doctor_name": "Dr. Arjun Shah", "clinic_name": "Shah Family Clinic",
  "notes": null, "issued_on": "2026-08-12", "source": "upload",
  "is_clinic": false, "has_file": true, "file_mime": "application/pdf",
  "is_pdf": true,
  "file_url": "api/mobile/v1/prescriptions.php?action=file&id=12",
  "created_at": "2026-08-12 10:04:11" }
```
### `GET ?action=file&id=123`  *(Bearer)* → raw PDF/image bytes
Not public. `file_url` is **relative** — prefix `kApiBaseUrl`'s host and send the
Bearer header (so a plain `Image.network` will NOT work; use an authed fetch).

### `POST ?action=add`  *(Bearer)* — **multipart/form-data**
Fields: `label`\* · `doctor_name` · `clinic_name` · `notes` · `issued_on`
(`YYYY-MM-DD`) · `family_member_id` — file part named **`file`** (optional).
Max **10 MB**; PDF/JPEG/PNG/WebP. → `201 { id, item }`.
Errors: `label_required` 400 · `member_not_found` 400 · `file_too_large` 413
(+`max_mb`) · `file_type_not_allowed` 415 (+`allowed`).

### `POST ?action=remove`  *(Bearer)* — Body `{ "id": 12 }` → soft delete.

---

## Lab reports — `lab_reports.php`

The patient's lab-report vault (`patient_lab_reports`). Identical shape to
prescriptions.

> ⚠️ **PATIENT UPLOADS ONLY.** There is no doctor/clinic lab module and no
> partner result feed, so every row is something the patient added themselves.
> **Thyrocare-booked tests never appear here.**
>
> ⚠️ **Design gap:** the DB stores a **file + label** — there are **no numeric
> results, units or reference ranges**. The design's trend chart
> (`values:[7.2, 6.8, …]`) **cannot be backed** and should be dropped from v1.

### `GET ?action=list` · `GET ?action=detail&id=` · `GET ?action=file&id=`  *(Bearer)*
```json
{ "id": 8, "label": "HbA1c — Aug 2026", "test_type": "Blood",
  "lab_name": "Thyrocare", "doctor_name": null, "notes": null,
  "reported_on": "2026-08-14", "source": "upload", "has_file": true,
  "file_mime": "application/pdf", "is_pdf": true,
  "file_url": "api/mobile/v1/lab_reports.php?action=file&id=8",
  "created_at": "2026-08-14 09:12:00" }
```
### `POST ?action=add`  *(Bearer)* — **multipart/form-data**
Fields: `label`\* · `test_type` · `lab_name` · `doctor_name` · `notes` ·
`reported_on` · `family_member_id` — file part **`file`**. Same limits/errors
as prescriptions. → `201 { id, item }`.

### `POST ?action=remove`  *(Bearer)* — Body `{ "id": 8 }`.

---

## Family — `family.php`

Family profiles (`family_member_identities`). A **"self"** row is auto-created on
first `list`, cannot be removed, and its relation is pinned to `self`.
**Max 6 members** including self.

### `GET ?action=list`  *(Bearer)*
```json
{ "ok": true, "count": 3, "can_add": true, "max_members": 6,
  "members": [ { "id": 5, "name": "Ananya Sharma", "initials": "AS",
                 "relation": "self", "is_self": true, "dob": "1997-03-02",
                 "age": 29, "gender": "F", "blood_group": "B+", "abha_id": null } ],
  "options": { "relations": ["spouse","mother","father","son","daughter","guardian","other"],
               "genders": ["M","F","Other"],
               "blood_groups": ["A+","A-","B+","B-","O+","O-","AB+","AB-"] } }
```
> ⚠️ **Relation mismatch with the design.** The design chips read
> *Mother/Father/**Husband/Wife**/Son/Daughter/Other*, but the DB enum has
> **`spouse`**, not husband/wife. Render from `options.relations` — do **not**
> hardcode — and map husband/wife → `spouse`. Unrecognised values store as
> `other`. `initials` and `age` are derived server-side so every client matches.

### `GET ?action=detail&id=12`  *(Bearer)* → `{ member }` (owner-scoped; foreign id → 404)
### `POST ?action=save`  *(Bearer)* — create **and** update
Body `{ member_id?, name*, relation, dob, gender, blood_group, abha_id }` —
omit `member_id` to create. → `{ member_id, member }`.
Errors: `name_required` 400 · `not_authorized` 404 · `member_limit_reached` 409
(+`max_members`).
### `POST ?action=remove`  *(Bearer)* — Body `{ "member_id": 12 }`.
Errors: `not_authorized` 404 · `cannot_remove_self` 409.

---

## Profile — `profile.php`

The logged-in person's own `patient_identities` row — contact, address,
emergency contact, medical notes, lifestyle, photo. **Everything is optional**
except `name`, which may be updated but never blanked.

> ⚠️ **Primary phone is READ-ONLY here** (`phone_editable:false`). It is the
> verified, unique account key; changing it runs through the OTP flow on the
> **web** endpoint, which v1 does not expose. Sending `phone` to `save` is
> silently ignored, not an error.

### `GET ?action=get`  *(Bearer)* → `{ profile, options }`
`profile` carries the identity columns plus derived `initials`, `age`,
`has_photo`, `photo_url`, `phone_verified`, `email_verified`, `phone_editable`,
and **`wa_opt_in`** (bool, see below).
`options` = `genders` · `blood_groups` · `veg_types` (`veg|nonveg|vegan|eggetarian`).

### `POST ?action=save`  *(Bearer)* — JSON, **partial**
Only keys present in the body are written, so a single field can be PATCHed
without resending the form. → `{ profile }`.
Errors: `name_required` 400 · `email_in_use` 409 · `db_unavailable` 503 ·
`invalid_wa_opt_in` 400 · `save_failed` 503 (WhatsApp switch not saved).

**"WhatsApp reminders" switch: `wa_opt_in`** (added 2026-10-05). Save it like any
other key: `{ "wa_opt_in": false }`. It accepts `true/false`, `1/0`, `"on"/"off"`.
- It applies to the account's **phone number**, not the profile row: the server
  stores it in the messaging opt-out list that every WhatsApp send checks.
- **Off** stops all WhatsApp messages to that number: clinic appointment and
  follow-up reminders, booking messages and Shop order updates. Those messages
  are skipped, not sent by SMS instead. Email still goes. The WhatsApp **OTP**
  is not affected, so login keeps working.
- **On** removes the block. If the person had replied STOP on WhatsApp earlier,
  turning it on re-enables WhatsApp only (SMS stays blocked).
- Default for everyone is `true` (on).

### `POST ?action=photo`  *(Bearer)* — **multipart**, file part **`file`**
Max **4 MB**; JPEG/PNG/WebP. → `{ has_photo, photo_url, photo_tag }`.
`photo_tag` is a cache-buster — append it so a replaced avatar refreshes.
Errors: `no_file` 400 · `file_too_large` 413 · `file_type_not_allowed` 415.
### `GET ?action=photo`  *(Bearer)* → raw image bytes (authed; not public).
### `POST ?action=photo_remove`  *(Bearer)* → `{ has_photo: false }`.

---

## App update check — `app_version.php` (public, added 2026-10-05)

Call it on every app start (and when the app comes back to the foreground after
a few hours). No token needed.

### `GET ?platform=android|ios&build=7`
`build` is the app's **integer build number**: the `7` in Flutter's `1.2.0+7`
(`PackageInfo.buildNumber`). Compare builds only, never version strings.
```json
{ "ok": true,
  "platform": "android",
  "update": "optional",
  "latest_version": "1.2.0",
  "latest_build": 7,
  "min_build": 5,
  "store_url": "https://play.google.com/store/apps/details?id=com.eclinicpro.eclinicpro_patient",
  "title": "Update available",
  "message": "A new version of eClinicPro is available with improvements and fixes.",
  "notes": ["Faster checkout", "Bug fixes"] }
```
| `update` | When | App does |
|----------|------|----------|
| `"required"` | `build < min_build` | Blocking dialog: `title`, `message`, `notes`, one **Update** button → open `store_url`. No way to dismiss. |
| `"optional"` | `build < latest_build` | Dismissible dialog: **Update** / **Later**. Don't show again for the same `latest_build` once dismissed. |
| `"none"` | otherwise | Nothing. |

- When `update` is `"none"`, `title` and `message` are `null`.
- When nothing is set up for the platform (no latest build or no store link on
  `/admin/app-versions`), the answer is `"none"` with `latest_version`,
  `latest_build`, `min_build` and `store_url` all `null` and `notes: []`. The app
  must never block in that case.
- `min_build` is `null` when admin set no minimum. `notes` can be `[]`.
- If `title`/`message` were left empty in admin, the server sends defaults
  ("Update available" / "Update required" and a standard sentence).
- **Fail open:** on a network error, timeout or any non-`ok` response, show
  nothing and let the user carry on.
- Responses carry `Cache-Control: public, max-age=300`, so an admin change reaches
  every app within about 5 minutes.

Errors: `400 build_required` + `message` (missing, `0`, negative, or not a whole
number) · `400 invalid_platform` + `message` · `405 method_not_allowed` (not GET).

---

## curl smoke tests (run on server before coding)

```bash
BASE=https://eclinicpro.com/api/mobile/v1

# 1. request OTP (dev mode returns dev_code)
curl -s -X POST "$BASE/auth.php?action=send_otp" \
  -H 'Content-Type: application/json' -d '{"phone":"9374249829"}'

# 2. verify → capture token
curl -s -X POST "$BASE/auth.php?action=verify_otp" \
  -H 'Content-Type: application/json' \
  -d '{"phone":"9374249829","code":"123456","name":"Ravi"}'

TOKEN=<paste 64-hex token>

# 3. authed calls
curl -s "$BASE/auth.php?action=me"       -H "Authorization: Bearer $TOKEN"
curl -s "$BASE/home.php"                 -H "Authorization: Bearer $TOKEN"
curl -s "$BASE/doctors.php?action=search&city=Mumbai&spec=dermatologist"
curl -s "$BASE/doctors.php?action=detail&id=123"
curl -s "$BASE/appointments.php?action=list" -H "Authorization: Bearer $TOKEN"

# 4. book (unified lead flow)
curl -s -X POST "$BASE/appointments.php?action=book" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"doctor_id":123,"preferred_date":"2026-07-14","preferred_time":"17:30","reason":"Back pain"}'

# ---- 5. endpoints added 2026-09-23 (verify these before coding) ----
A="Authorization: Bearer $TOKEN"

# queue (expect in_queue:false + reason when nothing is booked today)
curl -s "$BASE/queue.php?action=status"          -H "$A"

# records — both vaults list-then-detail
curl -s "$BASE/prescriptions.php?action=list"    -H "$A"
curl -s "$BASE/lab_reports.php?action=list"      -H "$A"

# family — first call auto-creates the "self" row
curl -s "$BASE/family.php?action=list"           -H "$A"

# profile
curl -s "$BASE/profile.php?action=get"           -H "$A"

# partial save must not wipe untouched fields
curl -s -X POST "$BASE/profile.php?action=save"  -H "$A" \
  -H 'Content-Type: application/json' -d '{"address_city":"Ahmedabad"}'

# ---- 6. WhatsApp switch (added 2026-10-05) ----
curl -s -X POST "$BASE/profile.php?action=save"  -H "$A" \
  -H 'Content-Type: application/json' -d '{"wa_opt_in":false}'     # expect profile.wa_opt_in:false
curl -s "$BASE/profile.php?action=get" -H "$A" | grep -o '"wa_opt_in":[a-z]*'   # false
curl -s -X POST "$BASE/profile.php?action=save"  -H "$A" \
  -H 'Content-Type: application/json' -d '{"wa_opt_in":"maybe"}'   # 400 invalid_wa_opt_in
curl -s -X POST "$BASE/profile.php?action=save"  -H "$A" \
  -H 'Content-Type: application/json' -d '{"wa_opt_in":true}'      # back on
curl -s -X POST "$BASE/profile.php?action=save" \
  -H 'Content-Type: application/json' -d '{"wa_opt_in":false}'     # no token → 401 login_required

# multipart upload (note: -F, NOT a JSON body; part name must be "file")
curl -s -X POST "$BASE/lab_reports.php?action=add" -H "$A" \
  -F 'label=HbA1c — Aug 2026' -F 'lab_name=Thyrocare' \
  -F 'reported_on=2026-08-14' -F 'file=@/tmp/report.pdf'

# authed file read (must be 200 + application/pdf, NOT the JSON envelope)
curl -s -o /dev/null -w '%{http_code} %{content_type}\n' \
  "$BASE/lab_reports.php?action=file&id=1" -H "$A"

# IDOR check — someone else's row must 404, never leak
curl -s "$BASE/prescriptions.php?action=detail&id=999999" -H "$A"

# no-token check — every authed route must 401 login_required
curl -s "$BASE/profile.php?action=get"

# ---- 7. app update check (public; added 2026-10-05) ----
# First set Android on /admin/app-versions: latest version 1.2.0, latest build 7,
# minimum build 5, a Play Store URL. Leave iOS empty.
curl -s "$BASE/app_version.php?platform=android&build=7"    # update:"none"     (= latest)
curl -s "$BASE/app_version.php?platform=android&build=6"    # update:"optional" (< latest)
curl -s "$BASE/app_version.php?platform=android&build=4"    # update:"required" (< min)
curl -s "$BASE/app_version.php?platform=ios&build=1"        # update:"none", nulls (iOS not set up)
curl -s "$BASE/app_version.php?platform=android"            # 400 build_required
curl -s "$BASE/app_version.php?platform=android&build=abc"  # 400 build_required
curl -s "$BASE/app_version.php?platform=android&build=0"    # 400 build_required
curl -s "$BASE/app_version.php?platform=windows&build=7"    # 400 invalid_platform
curl -s -X POST "$BASE/app_version.php?platform=android&build=7"   # 405 method_not_allowed
curl -s -o /dev/null -D - "$BASE/app_version.php?platform=android&build=7" | grep -i cache-control
                                                            # Cache-Control: public, max-age=300
```

**What "pass" looks like:** every authed call returns `ok:true` (or a correct
`401 login_required` with no token); `?action=file` returns real bytes with the
file's own content-type rather than JSON; a foreign id returns `404 not_found`;
and the partial save leaves untouched columns alone.

---

## Flutter mapping notes

- **`ApiResult<T>`**: decode `ok`; on `false` read `error` (+ status) into a typed
  failure. Do **not** expect a generic `data` key — each endpoint names its own
  payload keys (`items`, `patient`, `doctor`, `upcoming`, …).
- **Auth interceptor (dio):** attach `Authorization: Bearer <token>` from secure
  storage; on `401 login_required` clear token + redirect to Login. No refresh
  endpoint in v1 (30-day rolling session).
- **Dates:** appointment items give both machine (`when_iso`) and pretty
  (`when_date`, `when_time`) — bind the pretty ones directly; keep `when_iso`
  for sorting/countdowns.
- **Booking UX:** label the CTA "Request appointment" and show the returned
  `message`. Don't build a slot picker in v1.
- **Blogs/tips:** separate WordPress REST client, not this base URL.

Keep this file in lockstep with `~/myclinic/api/mobile/v1/*`. If a route changes,
update here first, then the app.

---

## Configuration (what the Flutter coding step must set up)

### 1. Base URL — one constant, referenced everywhere
```dart
// lib/core/config/api_config.dart
const String kApiBaseUrl = 'https://eclinicpro.com/api/mobile/v1';
```
Single confirmed production value. No dev/staging split for v1. Every request is
`'$kApiBaseUrl/doctors.php?action=search'` etc. Never hardcode the host per call.

### 2. Endpoint → URL map (the ONLY URLs the app calls)
| Feature | Method | URL |
|---------|--------|-----|
| Request OTP | POST | `/auth.php?action=send_otp` |
| Verify OTP → token | POST | `/auth.php?action=verify_otp` |
| Restore session | GET | `/auth.php?action=me` |
| Logout | POST | `/auth.php?action=logout` |
| Home dashboard | GET | `/home.php` |
| Search doctors | GET | `/doctors.php?action=search&…` |
| Doctor detail | GET | `/doctors.php?action=detail&id=…` |
| Saved doctors | GET | `/doctors.php?action=saved` |
| Save / unsave | POST | `/doctors.php?action=save` · `?action=unsave` |
| Appointment list | GET | `/appointments.php?action=list` |
| Book (request) | POST | `/appointments.php?action=book` |
| Track view/call | POST | `/appointments.php?action=track` |
| Queue status | GET | `/queue.php?action=status` |
| Prescriptions list | GET | `/prescriptions.php?action=list` |
| Prescription detail | GET | `/prescriptions.php?action=detail&id=…` |
| Prescription file | GET | `/prescriptions.php?action=file&id=…` |
| Add / remove Rx | POST | `/prescriptions.php?action=add` (multipart) · `?action=remove` |
| Lab reports list | GET | `/lab_reports.php?action=list` |
| Lab report detail | GET | `/lab_reports.php?action=detail&id=…` |
| Lab report file | GET | `/lab_reports.php?action=file&id=…` |
| Add / remove report | POST | `/lab_reports.php?action=add` (multipart) · `?action=remove` |
| Family list | GET | `/family.php?action=list` |
| Family detail | GET | `/family.php?action=detail&id=…` |
| Save / remove member | POST | `/family.php?action=save` · `?action=remove` |
| Profile read | GET | `/profile.php?action=get` |
| Profile save | POST | `/profile.php?action=save` |
| Avatar get / set | GET/POST | `/profile.php?action=photo` |
| Avatar clear | POST | `/profile.php?action=photo_remove` |
| Store (Shop tab) | GET/POST | `/store*.php` — full map in [doc 12](./12-store-api-reference.md) |
| App update check (public) | GET | `/app_version.php?platform=android\|ios&build=…` |

> The app talks to **`/api/mobile/v1/` ONLY**. It must NEVER call the website's
> older `/api/*.php` files (lead.php, patient_bookings.php, wishlist.php, …) —
> those authenticate by cookie, not Bearer, so the app's token wouldn't work.
> The mobile files internally reuse the same server logic, so behaviour matches.

### 3. dio client rules
```dart
final dio = Dio(BaseOptions(
  baseUrl: kApiBaseUrl,
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 15),
  headers: {'Accept': 'application/json'},
));
```
- **DO send** `Authorization: Bearer <token>` (from secure storage) on every call
  once the token exists. Public calls (search/detail) work without it.
- **DO NOT attach a cookie jar** (`dio_cookie_manager`). The server accepts a
  cookie as a fallback, but the app must authenticate purely by Bearer so login
  state is explicit and reinstall-safe. No cookies in the app.
- POST bodies: `Content-Type: application/json`, JSON-encoded.
- **Except uploads.** `prescriptions.php?action=add`, `lab_reports.php?action=add`
  and `profile.php?action=photo` are **`multipart/form-data`** (`FormData`), with
  the binary part named **`file`**. Do not force a JSON content-type on those.
- **Authed file reads.** `?action=file` and `?action=photo` return raw bytes and
  need the Bearer header, so `Image.network(url)` will **not** work — fetch the
  bytes through `dio` and render from memory, or use a cached-image provider that
  accepts custom headers.

### 4. Envelope & error handling
- Success = `ok:true`; read the endpoint's own payload key (`items`, `doctor`,
  `patient`, `upcoming`…). There is **no generic `data` key**.
- Failure = `ok:false` + `error` string (+ correct HTTP status). Map to typed
  failures. Treat `401 login_required` as "clear token → go to Login".

### 5. Session / token lifecycle
- After `verify_otp`, store `token` in `flutter_secure_storage`.
- On app launch (Splash), call `/auth.php?action=me` with the stored token:
  `patient != null` → Home; `patient == null` or `401` → Onboarding/Login.
- Logout: call `/auth.php?action=logout`, then wipe token + any cached PHI.
- No refresh endpoint in v1 (30-day rolling session; a 401 = re-login).

### 6. Content NOT on this base URL
Blogs and today's health tip come from the **separate WordPress REST API**
(see doc 10), fetched with a different client — not `kApiBaseUrl`.
