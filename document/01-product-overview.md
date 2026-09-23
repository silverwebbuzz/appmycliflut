# 01 — Product Overview

## Vision

eClinicPro Patient App is the patient’s **digital front door** to clinics on eclinicpro.com: discover doctors, book visits (in-clinic or video), manage care, and keep a **digital health locker** (records, prescriptions, labs, vitals, family) in one place.

Tagline direction: *Your clinic, in your pocket.*

---

## Goals (v1)

1. Let a patient register/login with phone OTP in under 60 seconds.
2. Find a doctor (search, specialty, nearby, filters) and book an appointment.
3. See upcoming care and act on it (directions, video waiting room, cancel/reschedule).
4. Store and view medical history, Rx, labs, invoices, allergies, vaccinations, vitals.
5. Remind medicines and surface health tips / blogs.
6. Work gracefully offline for previously loaded locker data and appointment summaries.

---

## Persona

| Persona | Needs |
|---------|--------|
| **Primary patient** (25–55) | Book fast, see next appointment, keep Rx/labs handy |
| **Caregiver** | Manage family members’ appointments & records |
| **Chronic care patient** | Vitals trends, medicine reminders, continue treatment |

---

## Product principles

1. **Trust first** — calm healthcare UI, clear privacy, no dark patterns.
2. **One job per screen** — especially booking and health locker.
3. **Always recoverable** — every list has loading / empty / error / offline.
4. **Clinic-connected** — data comes from eClinicPro clinics, not a generic marketplace-only feel.
5. **Patient-only v1** — no doctor/clinic staff surfaces in this app.

---

## Brand & platform

| Item | Value |
|------|--------|
| Website | https://eclinicpro.com |
| Mobile API (planned) | `https://eclinicpro.com/api/mobile` |
| App type | Flutter patient app |
| Design system | Material Design 3, healthcare-tuned palette |
| Illustrations | Professional medical (undraw / custom SVG), not emoji-heavy |

---

## Success metrics (product)

| Metric | Target (early) |
|--------|----------------|
| Auth completion rate | > 70% of OTP starts |
| Time to first booking | < 5 minutes for new user |
| Crash-free sessions | > 99.5% |
| Offline open of last appointment / Rx | Works without network |
| App Store / Play rating | ≥ 4.5 after soft launch |

---

## Explicit non-goals (v1)

- Doctor or receptionist apps
- In-app medicine delivery / e-pharmacy checkout (beyond viewing Rx)
- Full telemedicine SDK build (use a provider; waiting room is ours)
- Multi-language beyond English + 1 regional language (expand later)
- Wearables / Apple Health / Google Fit sync (Phase 2)

---

## Related docs

- Flows → [02-user-flows.md](./02-user-flows.md)
- Screens → [03-screen-map.md](./03-screen-map.md)
- Architecture → [04-architecture.md](./04-architecture.md)
