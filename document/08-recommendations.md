# 08 — Recommendations

Practical recommendations for building the eClinicPro **patient-only** Flutter app against `eclinicpro.com` / `api/mobile`.

---

## 1. Product & scope

1. **Ship patient app only** — keep doctor/clinic as separate apps later; share API docs, not UI code.
2. **OTP-first auth** — lowest friction for healthcare in India/similar markets; skip password v1.
3. **Health locker as differentiator** — treat Records + Rx + Labs + Vitals as a first-class tab, not a buried menu.
4. **Family members early** — caregivers drive retention; include in Phase 2 at latest, ideally with booking.
5. **Don’t overbuild Home** — first viewport: greeting, search, next appointment, one CTA. Rest scrolls below.

---

## 2. Technical stack (opinionated)

| Decision | Recommendation | Alternative |
|----------|-----------------|-------------|
| State | **Riverpod** | Bloc (if team already expert) |
| Router | **go_router** | auto_route |
| HTTP | **dio** | http |
| Local DB | **Drift** for locker/appointments | Hive for simpler KV-only |
| Models | **freezed** | hand-written equatable |
| Video | **Managed provider** (Agora/Daily) + our waiting room | Full custom WebRTC (avoid v1) |
| Payments | Native SDK / web checkout via backend order | Never raw card APIs in app |

---

## 3. API design

1. Use **`/api/mobile/v1`** versioning from day one.
2. Provide **`GET /home`** aggregate endpoint — critical for perceived performance.
3. **Idempotency-Key** on booking & payment initiate.
4. **Signed URLs** for medical PDFs (short TTL).
5. Return **cancel/reschedule policy** text from API so app doesn’t hardcode clinic rules.
6. Align phone/OTP with existing eClinicPro web auth if possible (same patient identity).

---

## 4. UX / design

1. Material 3 + calm healthcare palette (teal/blue trust) — avoid generic purple gradients.
2. Shared **Loading / Empty / Error / Offline / Success** components before feature sprawl.
3. Professional SVG illustrations set (one visual language).
4. Skeleton loaders > spinners for lists.
5. Waiting room should feel clinical and clear: countdown, doctor name, “Join” enablement rules, support contact.

---

## 5. Offline

1. Cache: profile, upcoming appointments, locker metadata, downloaded files, reminders.
2. Booking, chat send, payments: **online required** (with clear messaging).
3. Show **last synced** on Health hub.
4. Medicine local notifications must work without network.

---

## 6. Security & compliance

1. Tokens in **secure storage**; logout wipes PHI cache.
2. Optional **biometric app lock** for locker (Phase 1.5).
3. Minimize PHI in crash/analytics logs.
4. Explicit privacy policy, terms, and consent for notifications/location.
5. Confirm regulatory posture for your markets (e.g. DPDP in India) with legal — don’t invent compliance claims in UI.

---

## 7. Phased delivery

### Phase 0 — Foundation (1–2 weeks)
- Flutter project, flavors, theme, router, dio, Riverpod, core state widgets  
- Splash + empty Home shell  

### Phase 1 — Auth & discovery (2–3 weeks)
- Onboarding, Login, OTP  
- Home (partial), Search, Listing, Detail  
- Basic profile  

### Phase 2 — Booking (2–3 weeks)
- Slots, Book, Confirmation  
- Upcoming / History, Cancel, Reschedule  
- Directions  
- Notifications (basic)  

### Phase 3 — Health locker (2–3 weeks)
- Records hub, Rx, Labs, Documents, Allergies, Vaccination  
- Timeline, Vitals  
- Offline cache for locker  

### Phase 4 — Engagement & care (2 weeks)
- Medicine reminders  
- Family members  
- Blogs + tips  
- Saved doctors  
- Settings, Help  

### Phase 5 — Realtime & money (2–3 weeks)
- Video waiting room + provider join  
- Chat with clinic  
- Payments  

### Phase 6 — Polish
- Animations, illustrations, empty/error coverage audit  
- Performance, accessibility, store listing, force-update  

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| API not ready | Mock server (Prism/Mockoon) from OpenAPI; feature flags |
| Double booking | Idempotency + server-side slot lock |
| Video flaky networks | Waiting room states + retry + clinic phone fallback |
| Scope creep (doctor features) | Strict patient-only backlog |
| PHI leak via logs | Logging redaction middleware |
| Play/App Store rejection | Privacy nutrition labels, account deletion path, support URL |

---

## 9. Account deletion & store readiness

Plan early:

- In-app **request account deletion** (Settings → Privacy)  
- Support email/URL on store listing: eclinicpro.com  
- Permission rationales: location (nearby), notifications (reminders), mic/camera (video)  

---

## 10. Naming & repo

| Item | Suggestion |
|------|------------|
| App name | eClinicPro Patient (store) / short: eClinicPro |
| Package | `com.eclinicpro.patient` |
| Repo | This repo `appmycliflut` → consider rename to `eclinicpro-patient` when convenient |
| Docs | Keep living docs in `/document` |

---

## 11. Immediate next steps

1. Review these docs with stakeholders (product + backend).  
2. Confirm API base path and OTP/payment/video vendors.  
3. Produce OpenAPI from [05-api-contract.md](./05-api-contract.md).  
4. Create Flutter project skeleton + theme + core widgets.  
5. Implement Phase 0–1 against mocks.  

---

## 12. What I would *not* do in v1

- Multi-role login in the same app  
- Custom WebRTC stack  
- Wearable sync  
- AI symptom checker as a blocker for launch  
- Heavy card-based “dashboard” Home that looks like admin analytics  
- Password + OTP both required  

---

## Summary recommendation

Build a **feature-first Flutter app** with Riverpod + go_router + dio + Drift, Material 3 healthcare UI, and a versioned mobile API at `eclinicpro.com/api/mobile/v1`. Prioritize **OTP → Home → Doctors → Book → Locker**, with shared loading/empty/error/offline/success from day one. Keep the product **patient-only** until the patient funnel is solid.
