# 06 — UI / UX States

Every data-driven screen must handle these states consistently using shared Material components and healthcare illustrations.

---

## State matrix

| State | When | UI pattern |
|-------|------|------------|
| **Loading** | First fetch / pull-to-refresh | Skeleton (preferred) or centered `CircularProgressIndicator` |
| **Empty** | Success but no items | Illustration + title + short copy + primary CTA |
| **Error** | Network/API/business failure | Illustration + message + **Retry** |
| **Offline** | No connectivity | Persistent banner + cached content if any; disable net-only actions |
| **Success** | Action completed | Full-screen success (booking) or snackbar/dialog (save, cancel) |

---

## Shared widgets (build once)

| Widget | Role |
|--------|------|
| `AppLoadingSkeleton` | List/card placeholders matching layout |
| `AppEmptyState` | illustration, title, subtitle, CTA |
| `AppErrorState` | illustration, message, retry |
| `AppOfflineBanner` | “You’re offline · showing saved data” |
| `AppSuccessView` | check animation, title, actions |
| `AppNetworkGate` | Wraps actions that require online |

Place under `lib/core/widgets/`.

---

## Per-screen expectations (summary)

| Screen | Loading | Empty | Error | Offline | Success |
|--------|---------|-------|-------|---------|---------|
| Splash | Brand + spinner | — | Config fail | Cached route if session | → next route |
| Onboarding | — | — | — | OK offline | — |
| Login | Button loading | — | Invalid phone | Block send + message | → OTP |
| OTP | Verify loading | — | Invalid/expired | Block verify | → Home |
| Home | Section skeletons | Per-section empty CTAs | Section retry | Cached home + banner | — |
| Search | Suggestions load | No recent | Fail suggestions | Local recent only | — |
| Listing | Skeleton list | No doctors match | Retry | Cached last query optional | — |
| Detail | Skeleton | Doctor missing | Retry | Limited cached profile | Saved toast |
| Book | Slots loading | No slots | Slot taken / fail | Block confirm | → Confirmation |
| Confirmation | — | — | — | Show local confirm if saved | Primary success screen |
| Upcoming | Skeleton | Book CTA | Retry | Cached list | Cancel/reschedule toasts |
| History | Skeleton | No past visits | Retry | Cached | — |
| Records hub | Skeleton tiles | Start care CTA | Retry | Cached hub | — |
| Rx / Labs | Skeleton | No documents | Retry | Cached + downloaded files | Share sheet |
| Reminders | Skeleton | Add medicine CTA | Retry | Local reminders work | Saved |
| Timeline | Skeleton | Empty timeline | Retry | Cached | — |
| Vitals | Skeleton / chart shimmer | Add first reading | Retry | Cached charts | Saved |
| Family | Skeleton | Add member | Retry | Cached | Saved |
| Notifications | Skeleton | All caught up | Retry | Cached | — |
| Blogs | Skeleton | No posts | Retry | Cached list | — |
| Blog detail | Skeleton | — | Retry | Cached article if opened | — |
| Saved doctors | Skeleton | Browse doctors CTA | Retry | Cached | — |
| Waiting room | Connecting states | — | Join fail | Cannot join | In-call handoff |
| Chat | Skeleton | Start conversation | Retry | Queue + banner | Sent |
| Payments | Skeleton | No transactions | Retry | Cached history | Payment success |
| Profile | Skeleton | — | Retry | Cached | — |
| Edit profile | Saving overlay | — | Validation / API | Queue or block | Saved |
| Settings | — | — | Save fail | Prefs local | Saved |
| Support | FAQ load | No FAQs | Retry | Cached FAQs | Ticket sent |

---

## Copy guidelines (examples)

**Empty — Upcoming**  
Title: *No upcoming visits*  
Body: *Book a doctor to see your next appointment here.*  
CTA: *Find doctors*

**Empty — Prescriptions**  
Title: *No prescriptions yet*  
Body: *After your consultation, digital prescriptions will appear in your health locker.*  
CTA: *View appointments*

**Error**  
Title: *Something went wrong*  
Body: *We couldn’t load this right now. Please try again.*  
CTA: *Retry*

**Offline**  
Banner: *You’re offline. Showing last saved information.*

**Success — Booking**  
Title: *Appointment confirmed*  
Body: *You’re booked with {doctor} on {date}.*  
CTAs: *View appointment* · *Back to home*

Keep tone calm, clear, non-alarmist. Avoid blame (“You failed…”).

---

## Animations (intentional, not noisy)

1. **Shared axis / fade-through** between main tabs  
2. **Staggered list** entrance on Home sections (subtle)  
3. **Success check** Lottie/Rive or Material motion on booking confirm  
4. **Pull-to-refresh** on lists  
5. **Hero** doctor photo from listing → detail (optional)  

Do not animate every tile; 2–3 signature motions are enough for polish.

---

## Illustrations

Use a consistent set (SVG):

- Empty calendar / empty locker / empty search  
- Offline cloud  
- Error / retry  
- Success / confirmed  
- Medicine / vitals / family  

Style: professional healthcare line or soft flat — not cartoonish emoji collages.

---

## Accessibility

- Min tap target 48dp  
- Contrast AA for text on backgrounds  
- Screen reader labels on icon-only buttons  
- Don’t rely on color alone for appointment status (use icons + text)  
- Reduce motion: respect OS setting where feasible  

---

## Material components to standardize

- `NavigationBar` / `NavigationDestination`  
- `SearchBar` / `SearchAnchor`  
- `FilterChip` / `AssistChip`  
- `Card` only where interaction needs a container (lists of doctors/appointments)  
- `FilledButton` / `OutlinedButton` / `TextButton` hierarchy  
- `SnackBar`, `Banner`, `Dialog`, `BottomSheet` (filters, cancel reasons)  
- `DatePicker` / time slots as custom chip grid  
- `Badge` on notifications  
