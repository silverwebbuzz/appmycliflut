# 09 — Beginner Execution Guide

**Who this is for:** First time with Flutter.  
**Goal:** Know where everything goes, how to run the app, and how to test **one screen at a time**.

Related docs: [Architecture](./04-architecture.md) · [Screen Map](./03-screen-map.md) · [Recommendations](./08-recommendations.md)

---

## A. One-time setup (your Mac)

### 1. Install Flutter

1. Install [Flutter](https://docs.flutter.dev/get-started/install/macos) (or via Homebrew: `brew install --cask flutter`).
2. Install **Xcode** (iOS Simulator) from the App Store.
3. Install **Android Studio** (Android Emulator) — optional at first; iOS Simulator is enough to start on Mac.
4. In Terminal:

```bash
flutter doctor
```

Fix anything marked with `✗` until Flutter looks healthy.

### 2. Create the project (when we scaffold)

From the repo root (`appmycliflut`):

```bash
flutter create --org com.eclinicpro --project-name eclinicpro_patient .
```

Or we create it for you in a later step. After create, the important folders look like this:

```text
appmycliflut/
  document/                 ← product docs (already here)
  lib/                      ← ALL Dart/Flutter code
  assets/                   ← images, logos, illustrations, fonts
  android/                  ← Android native config
  ios/                      ← iOS native config
  pubspec.yaml              ← packages + asset registration
  .env / .env.dev           ← API URLs & keys (we will add)
```

---

## B. Where do I put what?

### 1. Configuration (API URL, keys, flavors)

| What | Where to put it | Notes |
|------|-----------------|--------|
| API base URL | `.env` or `.env.dev` / `.env.staging` / `.env.prod` | e.g. `API_BASE_URL=https://eclinicpro.com/api/mobile/v1` |
| Env loader code | `lib/core/config/env.dart` | Reads `.env` at startup |
| App constants | `lib/core/config/app_constants.dart` | Timeouts, OTP length, join-window minutes |
| Feature flags | `lib/core/config/feature_flags.dart` | Optional |
| Android app id / name | `android/app/build.gradle` + `AndroidManifest.xml` | Package `com.eclinicpro.patient` |
| iOS bundle id / name | `ios/Runner.xcodeproj` + `Info.plist` | Same branding |
| Firebase (later) | `android/app/google-services.json` · `ios/Runner/GoogleService-Info.plist` | Push notifications |
| **Never commit secrets** | Use `.env` + `.gitignore` | No live payment/API secrets in git |

**Example `.env.dev` (you create this file at project root):**

```env
API_BASE_URL=https://eclinicpro.com/api/mobile/v1
APP_ENV=dev
```

**You edit config here when:**
- Backend URL changes
- Switching between dev / staging / production
- Adding Firebase or payment keys (via secure env, not hard-coded in UI)

---

### 2. Images, logo, illustrations

| Asset | Put file here | Register in |
|-------|---------------|-------------|
| App logo (splash / login) | `assets/images/logo.png` (also `@2x` / `@3x` if you have them) | `pubspec.yaml` → `assets:` |
| Onboarding art | `assets/images/onboarding/` | same |
| Empty / error / offline / success art | `assets/images/states/` | same |
| Icons (custom) | `assets/icons/` | same |
| Fonts | `assets/fonts/` | `pubspec.yaml` → `fonts:` |
| **Store icon / launcher** | Android: `android/app/src/main/res/mipmap-*` · iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset` | Use [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) later |
| **Splash screen native** | Use [flutter_native_splash](https://pub.dev/packages/flutter_native_splash) | Generated into android/ios |

**Folder layout to create:**

```text
assets/
  images/
    logo.png
    logo_white.png
    onboarding/
      onboarding_1.png
      onboarding_2.png
      onboarding_3.png
    states/
      empty_appointments.svg
      empty_records.svg
      error.svg
      offline.svg
      success.svg
  icons/
  fonts/
```

**In `pubspec.yaml` you must list folders** (Flutter will not see files until you do):

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/images/onboarding/
    - assets/images/states/
    - assets/icons/
  fonts:
    - family: AppFont
      fonts:
        - asset: assets/fonts/YourFont-Regular.ttf
        - asset: assets/fonts/YourFont-Bold.ttf
          weight: 700
```

After adding assets:

```bash
flutter pub get
```

**Use in code:**

```dart
Image.asset('assets/images/logo.png', height: 48)
```

**What you should prepare now (design files):**
1. Logo PNG/SVG (transparent background)
2. App icon 1024×1024
3. 3 onboarding illustrations
4. 5 state illustrations (empty, error, offline, success, empty search)

Drop them into `assets/...` when the Flutter project exists. Until then, keep a folder on your Mac like `~/Desktop/eclinicpro-branding/` and we copy them in.

---

### 3. Design — look and feel (theme)

**All look-and-feel lives in code under `lib/core/theme/`** — not in Figma alone.

| File | What you change |
|------|-----------------|
| `lib/core/theme/app_colors.dart` | Brand colors (primary teal/blue, backgrounds, error, success) |
| `lib/core/theme/app_typography.dart` | Font sizes / text styles |
| `lib/core/theme/app_spacing.dart` | Padding, gaps (8, 16, 24…) |
| `lib/core/theme/app_theme.dart` | Material 3 `ThemeData` (buttons, app bar, inputs) |
| `lib/core/widgets/` | Shared buttons, empty states, cards |

**If you have Figma / design screens:**
- Keep Figma as the visual reference.
- Implement colors/fonts into `app_colors.dart` + `app_typography.dart`.
- Do **not** paste random colors inside each screen — always use theme.

**Example — change brand color once, whole app updates:**

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  static const primary = Color(0xFF0D9488); // teal — replace with your brand
  static const background = Color(0xFFF8FAFC);
  static const error = Color(0xFFDC2626);
}
```

Wired in `lib/app.dart` via `theme: AppTheme.light`.

---

### 4. Screens (where each screen’s code goes)

| Screen | Folder |
|--------|--------|
| Splash | `lib/features/auth/presentation/splash_screen.dart` |
| Onboarding | `lib/features/onboarding/presentation/` |
| Login / OTP | `lib/features/auth/presentation/` |
| Home | `lib/features/home/presentation/` |
| Doctors | `lib/features/doctors/presentation/` |
| Appointments | `lib/features/appointments/presentation/` |
| Health locker | `lib/features/health/presentation/` |
| Profile | `lib/features/profile/presentation/` |
| Blogs | `lib/features/blogs/presentation/` |

Routes (which screen opens when): `lib/core/router/app_router.dart`

---

## C. How to run the app

### Start a simulator

**iOS (Mac):**

```bash
open -a Simulator
```

**Or list devices:**

```bash
flutter devices
```

### Run

From project root:

```bash
flutter pub get
flutter run
```

Pick a device if asked. Hot reload: press `r` in the terminal. Hot restart: `R`. Quit: `q`.

**VS Code / Cursor:** open the project → select device (bottom status bar) → press **F5** or Run → Start Debugging.

---

## D. How to test screen-by-screen (beginner workflow)

You do **not** need the full API or all 30 screens to test. Build and verify one screen, then move on.

### Recommended order (matches our phases)

| Step | Screen | What “done” means | How you test |
|------|--------|-------------------|--------------|
| 0 | Project + theme | App opens with brand colors | `flutter run` → see blank Home with theme |
| 1 | Splash | Logo shows ~2s then navigates | Launch app cold |
| 2 | Onboarding ×3 | Swipe / Next / Skip works | First launch (or clear app data) |
| 3 | Login | Phone field + Send OTP | Tap through; can use fake button at first |
| 4 | OTP | 6 boxes + Verify | Enter any code while API is mocked |
| 5 | Home shell | Bottom tabs + placeholder sections | Tap each tab |
| 6 | Search / Listing | Fake doctor list | Scroll, tap a doctor |
| 7 | Doctor Detail | Profile UI | Open from list |
| 8 | Book + Confirmation | Form → success screen | Complete flow with mock slots |
| … | Continue per [08-recommendations](./08-recommendations.md) | | |

### Trick: temporary “preview” route

While learning, we can add a **Dev Gallery** screen (only in debug) that lists buttons:

- Open Splash  
- Open Onboarding  
- Open Login  
- Open Home  
- …

So you can jump to any screen without finishing auth. That lives in something like:

`lib/features/dev/presentation/dev_gallery_screen.dart`

(We add this when scaffolding.)

### Mock vs real API

| Stage | Approach |
|-------|----------|
| UI only | Hard-coded fake data in the screen / repository |
| API ready | Point `.env` to real `API_BASE_URL` |
| Offline test | Turn on Airplane Mode → confirm banner + cached data |

### Checklist after each screen

1. Does it open without red error screen?  
2. Loading state visible?  
3. Empty state looks OK?  
4. Error + Retry works (temporarily force an error)?  
5. Looks fine on a small phone and a large phone?  
6. Back button / system back works?

---

## E. Daily commands cheat sheet

```bash
flutter doctor              # check setup
flutter devices             # list simulators/phones
flutter pub get             # after pubspec or package changes
flutter run                 # run app
flutter run -d chrome       # quick UI try in browser (limited)
flutter clean               # if build is weird, then pub get + run
flutter analyze             # static checks
```

---

## F. What you do vs what we do in Cursor

| You provide / decide | We implement in code |
|----------------------|----------------------|
| Logo, icon, illustrations files | Place under `assets/` + wire in `pubspec.yaml` |
| Brand hex colors / font files | Put into `lib/core/theme/` |
| API base URL when backend is ready | `.env` + `env.dart` |
| Figma or screenshots (optional) | Match layout screen by screen |
| Test on Simulator after each screen | Fix bugs you report |

---

## G. Your first action list (today)

1. Install Flutter + run `flutter doctor` until clean.  
2. Collect branding into one folder: logo, app icon, 3 onboarding images, state illustrations.  
3. Note your brand primary color (hex) and preferred font.  
4. Tell me when ready → we scaffold the Flutter project + theme + Splash first.  
5. You run `flutter run` and confirm Splash looks right.  
6. We build the next screen; you test; repeat.

---

## H. Quick map (print this mentally)

```text
Configuration  →  .env  +  lib/core/config/
Look & feel    →  lib/core/theme/
Logo & images  →  assets/images/  (+ pubspec.yaml)
Each screen    →  lib/features/<name>/presentation/
Navigation     →  lib/core/router/
Run & test     →  flutter run  (+ Simulator)
```

You never put the logo inside `lib/`. You never put API URLs only inside a random screen. Theme colors go in `app_colors.dart`, not copy-pasted per page.
