# 05 — API Contract (Mobile)

**Base URL (CONFIRMED):** `https://eclinicpro.com/api/mobile/v1` — see [11 — Mobile API Reference](./11-mobile-api-reference.md), the frozen contract. (This doc 05 is the original wishlist; 11 is what's built.)  
**Format:** JSON over HTTPS  
**Auth:** Bearer access token (except auth endpoints)  
**Audience:** Patient app only

This is a **contract sketch** for backend alignment. Adjust paths to match existing eClinicPro conventions when the API is finalized.

> ⚠️ **Read [10 — Backend API Mapping](./10-backend-api-mapping.md) first.** It maps
> this wishlist onto the backend that *actually exists*. Key reality checks: the
> real envelope is **`{ ok: true, … }` / `{ ok:false, error }`** (not
> `{success,data}`); auth is a **session token** in `patient_sessions` (reuse it as
> the Bearer token), not a JWT; OTP is **WhatsApp**; and endpoints are today flat
> `/api/*.php?action=…` files. This doc is the *target*; doc 10 is *what's built*.

---

## Conventions

| Topic | Recommendation |
|-------|----------------|
| Versioning | Prefix `/v1/` now: `/api/mobile/v1/...` |
| Time | ISO-8601 UTC; app localizes |
| Pagination | `?page=1&per_page=20` + `meta: { total, page, per_page }` |
| Errors | `{ "success": false, "error": { "code": "...", "message": "..." } }` |
| Success | `{ "success": true, "data": { ... } }` |
| IDs | Opaque strings/UUIDs |
| Files | Signed URLs for Rx/lab PDFs (time-limited) |
| Locale | `Accept-Language` header |

**Error codes (examples):** `UNAUTHORIZED`, `OTP_INVALID`, `OTP_EXPIRED`, `SLOT_TAKEN`, `VALIDATION_ERROR`, `NOT_FOUND`, `PAYMENT_REQUIRED`, `FORBIDDEN`, `RATE_LIMITED`

---

## Auth

| Method | Path | Notes |
|--------|------|-------|
| POST | `/auth/otp/request` | `{ phone, country_code }` |
| POST | `/auth/otp/verify` | `{ phone, country_code, otp }` → tokens + patient |
| POST | `/auth/token/refresh` | `{ refresh_token }` |
| POST | `/auth/logout` | Invalidate refresh |
| GET | `/auth/me` | Current patient profile |

---

## Home / content

| Method | Path | Notes |
|--------|------|-------|
| GET | `/home` | Aggregated dashboard payload (preferred for speed) |
| GET | `/specialties` | Popular + all |
| GET | `/packages` | Health packages |
| GET | `/blogs` | List |
| GET | `/blogs/{id}` | Detail |
| GET | `/tips/today` | Optional if not in `/home` |

**Recommendation:** One `GET /home` reduces waterfall calls on dashboard.

---

## Doctors

| Method | Path | Notes |
|--------|------|-------|
| GET | `/doctors` | Query: `q`, `specialty_id`, `lat`, `lng`, `radius`, `gender`, `min_fee`, `max_fee`, `available_today`, `consult_type`, `sort` |
| GET | `/doctors/{id}` | Profile + clinic + fees |
| GET | `/doctors/{id}/reviews` | Paginated |
| GET | `/doctors/{id}/slots` | `date`, `consult_type`, `clinic_id` |
| GET | `/doctors/nearby` | Geo required |
| GET | `/doctors/featured` | |
| POST | `/doctors/{id}/save` | Favorite |
| DELETE | `/doctors/{id}/save` | Unfavorite |
| GET | `/doctors/saved` | |

---

## Appointments

| Method | Path | Notes |
|--------|------|-------|
| POST | `/appointments` | Book: doctor, slot, type, patient/family member, notes |
| GET | `/appointments/upcoming` | |
| GET | `/appointments/history` | |
| GET | `/appointments/{id}` | |
| POST | `/appointments/{id}/cancel` | Reason optional |
| POST | `/appointments/{id}/reschedule` | New slot |
| GET | `/appointments/{id}/video-session` | Waiting room token / join URL / status |

Idempotency: send `Idempotency-Key` header on book to prevent double booking on retries.

---

## Health locker

| Method | Path | Notes |
|--------|------|-------|
| GET | `/health/summary` | Hub counts + last sync |
| GET | `/health/timeline` | Mixed events |
| GET | `/health/prescriptions` | |
| GET | `/health/prescriptions/{id}` | + file URL |
| GET | `/health/labs` | |
| GET | `/health/labs/{id}` | |
| GET | `/health/documents` | |
| GET | `/health/invoices` | Or under payments |
| GET | `/health/allergies` | |
| GET | `/health/vaccinations` | |
| GET | `/health/medicine-history` | |
| GET | `/health/vitals` | Type filter: bp, sugar, weight, bmi |
| POST | `/health/vitals` | Patient-entered readings |
| GET | `/health/medical-history` | Conditions / surgeries summary |

---

## Medicine reminders

| Method | Path | Notes |
|--------|------|-------|
| GET | `/reminders` | |
| POST | `/reminders` | |
| PUT | `/reminders/{id}` | |
| DELETE | `/reminders/{id}` | |
| POST | `/reminders/{id}/taken` | Adherence log |

Server may seed reminders from active prescriptions (optional).

---

## Family

| Method | Path | Notes |
|--------|------|-------|
| GET | `/family` | |
| POST | `/family` | |
| PUT | `/family/{id}` | |
| DELETE | `/family/{id}` | |
| GET | `/family/{id}/records` | Scoped locker access |

---

## Chat & notifications

| Method | Path | Notes |
|--------|------|-------|
| GET | `/clinics/{id}/chat` | Thread |
| POST | `/clinics/{id}/chat` | Send message |
| GET | `/notifications` | |
| POST | `/notifications/{id}/read` | |
| POST | `/notifications/read-all` | |
| POST | `/devices` | FCM token register |

Realtime chat: WebSocket or polling (v1 polling/FCM is fine).

---

## Payments

| Method | Path | Notes |
|--------|------|-------|
| GET | `/payments` | History |
| GET | `/payments/{id}` | |
| POST | `/payments/{id}/initiate` | Returns gateway payload / URL |
| POST | `/payments/webhook` | Server-only |

Never put gateway secrets in the app. Use Razorpay/Stripe/etc. per market.

---

## Profile & settings

| Method | Path | Notes |
|--------|------|-------|
| GET | `/profile` | |
| PUT | `/profile` | Personal info |
| GET/PUT | `/profile/insurance` | |
| GET/PUT | `/profile/addresses` | |
| GET/PUT | `/profile/emergency-contact` | |
| GET/PUT | `/profile/preferences` | Language, notification toggles |
| POST | `/support/tickets` | Help & support |
| GET | `/support/faqs` | |

---

## App config

| Method | Path | Notes |
|--------|------|-------|
| GET | `/config` | `min_ios_version`, `min_android_version`, feature flags, support phone |

Call from Splash.

---

## Sample: book appointment

**Request**

```http
POST /api/mobile/v1/appointments
Authorization: Bearer ...
Idempotency-Key: 8f3c2a1e-...
Content-Type: application/json

{
  "doctor_id": "doc_123",
  "clinic_id": "cli_9",
  "slot_id": "slot_456",
  "consult_type": "video",
  "patient_member_id": null,
  "notes": "Follow-up for BP"
}
```

**Response**

```json
{
  "success": true,
  "data": {
    "appointment": {
      "id": "apt_789",
      "status": "confirmed",
      "starts_at": "2026-07-12T10:30:00Z",
      "consult_type": "video",
      "doctor": { "id": "doc_123", "name": "Dr. Mehta" },
      "payment": { "status": "paid", "amount": 500, "currency": "INR" }
    }
  }
}
```

---

## Backend alignment checklist

- [ ] Confirm `/api/mobile` vs existing routes on eclinicpro.com  
- [ ] OTP provider (MSG91 / Twilio / Firebase Auth)  
- [ ] Slot locking rules & timezone per clinic  
- [ ] Signed URL TTL for medical files  
- [ ] Family member consent / linking rules  
- [ ] Payment gateway + refund policy for cancel  
- [ ] Video provider (Daily / Agora / Zoom / custom)  
- [ ] Rate limits on OTP  
- [ ] CORS not required for mobile; focus on auth & abuse  

Until the real OpenAPI lands, treat this doc as the mobile team’s proposed contract and iterate with backend.
