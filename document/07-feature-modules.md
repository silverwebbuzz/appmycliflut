# 07 — Feature Modules

Feature breakdown mapped to screens and capabilities. Patient-only.

---

## 1. Auth & Onboarding

**Screens:** Splash, Onboarding ×3, Login, OTP  

**Includes**
- Session restore, force-update gate  
- Phone OTP login  
- First-run onboarding value props (book, locker, video)

**Out of scope v1:** Social login (optional later)

---

## 2. Home

**Screen:** Home Dashboard  

**Includes**
- Search entry  
- Nearby doctors  
- Continue treatment  
- Upcoming appointment card  
- Medicine reminder strip  
- Today’s health tip  
- Popular specialties  
- Health packages  
- Featured doctors  
- Latest blogs  
- Notification bell  

Prefer single `GET /home` aggregate API.

---

## 3. Doctors

**Screens:** Search, Listing, Detail, Saved  

**Includes**
- Text search + specialties  
- Filters (specialty, nearby, fee, gender, type, availability)  
- Doctor profile + reviews  
- Save / unsave  
- Entry to book & chat  

---

## 4. Appointments

**Screens:** Book, Confirmation, Upcoming, History, Video Waiting Room  

**Includes**
- In-clinic & video booking  
- Cancel / reschedule (policy from API)  
- Directions  
- Join video within window  
- Link out to Rx / invoice after visit  

---

## 5. Health (Digital Health Locker)

**Screens:** Medical Records, Prescriptions, Lab Reports, Timeline, Vitals, Medicine Reminder  

**Locker contents**

| Area | Capabilities |
|------|----------------|
| Medical History | Conditions, past visits summary |
| Prescriptions | List, detail, PDF |
| Invoices | View / pay link |
| Lab Reports | List, detail, PDF |
| Vaccination | Records list |
| Medicine History | Past medicines |
| Allergies | List + severity |
| Vitals | BP, Sugar, Weight, BMI — log + charts |
| Documents | Uploaded/clinic docs |
| Emergency Contact | View/edit |
| Family Members | Linked profiles |

**Medicine Reminder:** schedules, local notifications, mark taken, optional sync from Rx.

---

## 6. Family

**Screen:** Family Members  

**Includes**
- CRUD members  
- Book / view records “as” member when allowed  
- Clear indicator of active profile context  

---

## 7. Notifications & Blogs

**Screens:** Notifications, Health Blogs, Blog Detail  

**Includes**
- In-app inbox + FCM  
- Deep links to appointment / Rx / reminder / blog  
- Tip of the day (Home) may deep-link to blog  

---

## 8. Chat with Clinic

**Screen:** Chat  

**Includes**
- Text thread with clinic  
- Unread badges  
- Offline queue  

**Later:** images, reports attach, chatbot triage

---

## 9. Payments

**Screen:** Payments  

**Includes**
- History, pending dues  
- Initiate gateway payment  
- Receipts / invoices  

---

## 10. Profile & Settings

**Screens:** Profile, Edit Profile, Settings, Help & Support  

**Includes**
- Personal information  
- Insurance  
- Addresses  
- Saved doctors shortcut  
- Notification preferences  
- Language  
- Privacy / policies  
- Support (FAQ + contact / ticket)  
- Logout  

---

## Cross-cutting

| Concern | Owner |
|---------|--------|
| Offline cache | core/offline + health/appointments repos |
| Analytics events | core + each feature |
| Illustrations & empty states | core/widgets |
| Localization | l10n |
| Permissions | location, camera (video), notifications, photos |

---

## Module dependency (simplified)

```text
auth → all
home → doctors, appointments, health, blogs, notifications
appointments → doctors, video, payments
health → family, appointments (context)
profile → family, payments, settings, saved doctors
```
