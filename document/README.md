# eClinicPro Patient App — Documentation

**Product:** Patient mobile application for [eclinicpro.com](https://eclinicpro.com)  
**Platform:** Flutter (iOS + Android)  
**Audience:** Patients only (v1)  
**API base (CONFIRMED):** `https://eclinicpro.com/api/mobile/v1` — see [11 — Mobile API Reference](./11-mobile-api-reference.md) for the frozen contract.

This folder is the source of truth for what we will build before writing Flutter code.

---

## Documents

| # | Document | Purpose |
|---|----------|---------|
| 01 | [Product Overview](./01-product-overview.md) | Vision, scope, personas, success metrics |
| 02 | [User Flows](./02-user-flows.md) | End-to-end journeys (auth → book → health locker) |
| 03 | [Screen Map](./03-screen-map.md) | All 30 screens + navigation + states |
| 04 | [Architecture](./04-architecture.md) | Flutter layers, packages, offline, security |
| 05 | [API Contract](./05-api-contract.md) | Mobile API modules, auth, endpoints sketch |
| 06 | [UI / UX States](./06-ui-ux-states.md) | Loading, empty, error, offline, success |
| 07 | [Feature Modules](./07-feature-modules.md) | Home, Doctors, Appointments, Health, Profile |
| 08 | [Recommendations](./08-recommendations.md) | Stack choices, phasing, risks, next steps |
| 09 | [Beginner Execution Guide](./09-beginner-execution-guide.md) | Setup, where config/images/theme go, run & test screen-by-screen |
| 10 | [Backend API Mapping](./10-backend-api-mapping.md) | Maps the app's needs onto the real eClinicPro PHP APIs, flags gaps, prioritised backend build list |
| 11 | [Mobile API Reference](./11-mobile-api-reference.md) | **Frozen v1 contract — code the app against this.** The built `/api/mobile/v1` façade: exact request/response JSON + curl smoke tests |
| 12 | [Store API Reference](./12-store-api-reference.md) | Shop tab: the eClinicPro Store (marketplace) endpoints — catalog, guest cart, checkout + Razorpay, orders/returns/invoices, wishlist |

---

## Scope (v1)

- **In:** Patient auth (OTP), find doctors, book/manage appointments, video consult waiting room, chat with clinic, digital health locker, reminders, family members, payments, profile/settings.
- **Out (for now):** Doctor app, clinic admin app, pharmacy fulfillment, insurance claim filing, wearable sync (can be Phase 2).

---

## Suggested build order

1. Foundation (project, theme, networking, auth shell)
2. Auth + Onboarding
3. Home Dashboard
4. Doctors (search → detail → book)
5. Appointments (upcoming / history / cancel / reschedule)
6. Health Locker (records, Rx, labs, vitals)
7. Reminders + Notifications
8. Family, Profile, Settings, Support
9. Video waiting room + Chat + Payments
10. Offline polish + empty/error/success states everywhere

See [Recommendations](./08-recommendations.md) for phased delivery.
