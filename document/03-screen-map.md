# 03 — Screen Map

All patient screens for v1. Each screen must support **loading / empty / error / offline** where data is fetched, plus **success** where an action completes.

---

## Navigation model (recommended)

**Root:** Auth stack vs Main shell  

**Main shell — bottom navigation (4 tabs):**

| Tab | Default screen | Also reachable |
|-----|----------------|----------------|
| Home | Home Dashboard (5) | Blogs, tips, packages |
| Doctors | Search / Listing entry (6/7) | Detail, Saved |
| Appointments | Upcoming (11) | History (12), Waiting Room |
| Health | Medical Records hub (13) | Vitals, Timeline, Reminders |
| Profile | Profile (27) | *Optional 5th tab; or via avatar on Home* |

**Recommendation:** 4 tabs (Home, Doctors, Appointments, Health) + Profile via avatar. Avoid 5+ tabs.

**Stack navigation:** Material / GoRouter nested routes for Detail, Book, OTP, Settings, etc.

---

## Screen inventory

| # | Screen | Route (suggested) | Primary data | Key actions |
|---|--------|-------------------|--------------|-------------|
| 1 | Splash | `/splash` | Session, config | Route to onboarding / login / home |
| 2 | Onboarding (×3) | `/onboarding` | Local | Next, Skip, Get started |
| 3 | Login | `/login` | — | Send OTP |
| 4 | OTP Verification | `/otp` | — | Verify, Resend |
| 5 | Home Dashboard | `/home` | Aggregated feed | Navigate to all modules |
| 6 | Search Doctors | `/doctors/search` | Query suggestions | Search, recent searches |
| 7 | Doctor Listing | `/doctors` | Doctor list | Filters, sort, open detail |
| 8 | Doctor Detail | `/doctors/:id` | Profile, reviews, slots | Book, Save, Chat, Call clinic |
| 9 | Book Appointment | `/book/:doctorId` | Slots, family | Confirm booking |
| 10 | Appointment Confirmation | `/book/success/:id` | Booking result | Upcoming, Home, Calendar |
| 11 | Upcoming Appointment | `/appointments/upcoming` | Upcoming list | Cancel, Reschedule, Join, Directions |
| 12 | Appointment History | `/appointments/history` | Past list | Rebook, Invoice, Rx |
| 13 | Medical Records | `/health/records` | Locker index | Open sub-sections |
| 14 | Digital Prescription | `/health/prescriptions` | Rx list/detail | Download/share PDF |
| 15 | Lab Reports | `/health/labs` | Lab list/detail | View/download |
| 16 | Medicine Reminder | `/health/reminders` | Reminders | Add, edit, snooze, mark taken |
| 17 | Health Timeline | `/health/timeline` | Timeline events | Filter by type |
| 18 | Health Vitals | `/health/vitals` | BP, sugar, weight, BMI | Add reading, charts |
| 19 | Family Members | `/family` | Members | Add, edit, remove, switch |
| 20 | Notifications | `/notifications` | Inbox | Open deep link, mark read |
| 21 | Health Blogs | `/blogs` | Blog list | Open detail, search |
| 22 | Blog Detail | `/blogs/:id` | Article | Share, related |
| 23 | Saved Doctors | `/doctors/saved` | Favorites | Unsave, book |
| 24 | Video Waiting Room | `/video/:appointmentId` | Session status | Join, cancel wait |
| 25 | Chat with Clinic | `/chat/:clinicId` | Messages | Send text (media Phase 2) |
| 26 | Payments | `/payments` | Transactions | Pay pending, view receipt |
| 27 | Profile | `/profile` | Patient profile | Edit, settings entry |
| 28 | Edit Profile | `/profile/edit` | Profile form | Save |
| 29 | Settings | `/settings` | Prefs | Language, privacy, notif |
| 30 | Help & Support | `/support` | FAQs, tickets | Contact, FAQ |

---

## Home Dashboard composition (5)

One scrollable composition (not a dense admin dashboard):

1. Greeting + profile avatar + notification bell  
2. Search bar → Search Doctors  
3. **Upcoming appointment** card (or empty CTA to book)  
4. **Continue treatment** (last doctor / open care plan)  
5. **Nearby doctors** horizontal list  
6. **Medicine reminder** today strip  
7. **Today’s health tip**  
8. **Popular specialties**  
9. **Health packages**  
10. **Featured doctors**  
11. **Latest blogs**  

Keep first viewport light: greeting, search, next appointment, one CTA.

---

## Doctors module

- Search (6) → Listing (7) with specialties + filters  
- Filters: specialty, city/nearby, gender, fee range, availability today, video/in-clinic, rating  
- Detail (8): bio, clinic, fees, languages, reviews, availability calendar, Save, Book  
- Saved Doctors (23)

---

## Appointments module

- Upcoming (11): status chips (Confirmed, Pending payment, Ready to join)  
- Past (12): Completed, Cancelled, No-show  
- Cancel / Reschedule with policy messaging from API  
- Video → Waiting Room (24)  
- Directions → Google/Apple Maps  

---

## Health locker module

Hub (13) tiles:

| Tile | Screen / section |
|------|------------------|
| Medical History | Records / Timeline |
| Prescriptions | (14) |
| Invoices | under Records or Payments |
| Lab Reports | (15) |
| Vaccination | Records subsection |
| Medicine History | Records / Reminders |
| Allergies | Records subsection |
| Vitals | (18) — BP, Sugar, Weight, BMI |
| Documents | Records subsection |
| Emergency Contact | Profile / Family |
| Family Members | (19) |

---

## Profile module

- Personal information  
- Insurance  
- Saved Doctors  
- Addresses  
- Notifications prefs  
- Language  
- Privacy  
- Support  
- Logout  

---

## Shared UI chrome

| Component | Usage |
|-----------|--------|
| App bar | Title, back, actions |
| Bottom nav | Main shell |
| FAB | Rare — e.g. add vital / add reminder |
| Snackbars / banners | Soft errors, offline |
| Full-screen success | Booking confirm, profile saved (optional) |
| Dialogs | Cancel appointment, logout, permissions |

---

## Deep links (plan)

Examples:

- `eclinicpro://appointments/:id`
- `eclinicpro://doctors/:id`
- `eclinicpro://prescriptions/:id`
- `eclinicpro://video/:appointmentId`
- `https://eclinicpro.com/app/...` (App Links / Universal Links)

Map notification payloads → these routes.
