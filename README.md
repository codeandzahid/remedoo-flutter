# Remedoo — Patient Health App (Flutter)

A complete Flutter rebuild of the Remedoo health super-app: patient app,
admin back-office, and role portals (doctor, driver, pharmacy, lab, hospital)
in one codebase. **Zero third-party dependencies** — pure Flutter + Material.

## Quick start

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd ~/workspace/remedoo-app

# Static analysis (must be clean)
flutter analyze

# Widget tests
flutter test

# Run on a device / emulator
flutter run
```

## Build commands

```bash
# Android APK (release)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Android App Bundle (for Play Store)
flutter build appbundle --release

# Web (self-contained: CanvasKit bundled locally, no CDN needed)
flutter build web --release --no-web-resources-cdn
# → build/web/  (deploy the folder contents to any static host)

# iOS (needs macOS + Xcode)
flutter build ipa --release
```

## Demo credentials

| Role   | Login                          |
| ------ | ------------------------------ |
| Admin  | `admin@remedoo.app` / `admin123` (via the small **Admin** link on the login screen) |
| Patient| Any email/password, Google button, or **Skip, continue as guest** |

Role portals (doctor / driver / pharmacy / lab / hospital): **Settings → Switch role (demo)**.

## Project structure

```
lib/
  main.dart                 # RemedooApp + RootGate (splash → onboarding → login → shell)
  theme.dart                # Remedoo design system (parameterized brand color)
  models.dart               # All data models
  data/mock_data.dart       # Local demo data (the Supabase seam — see below)
  state/app_state.dart      # ChangeNotifier store + AppStateScope (InheritedNotifier)
  widgets/widgets.dart      # Shared UI: cards, sheets, dialogs, steppers, badges
  screens/                  # 44 patient screens + main_shell.dart
    admin/                  # Admin console (login, shell, CRUD, dashboard, ops, config)
    roles/                  # Doctor / driver / pharmacy / lab / hospital portals
test/
  widget_test.dart          # 6 widget smoke tests
FEATURE_CHECKLIST.md        # Every screen/feature with done status
```

## State & data

- `AppState` (in `lib/state/app_state.dart`) is the single store, exposed via
  `AppStateScope` (an `InheritedNotifier`). Screens read with
  `AppStateScope.of(context)` and mutate through methods that call
  `notifyListeners()`.
- All demo data is fictional (Indian names, J&K flavor: Srinagar/Jammu
  localities) and lives in `lib/data/mock_data.dart` as **mutable singleton
  lists** — so admin edits (doctors, hospitals, labs, pharmacies, medicines)
  are reflected live in the patient UI.
- A demo medicine order (`R049B076`), notifications, a support ticket,
  provider applications, SOS alerts, refund requests, lab reports and driver
  deliveries are seeded on startup so every screen has content.

## Wiring Supabase later (their repo uses Supabase)

`lib/data/mock_data.dart` is the data-layer seam. To go live:

1. Add `supabase_flutter` to `pubspec.yaml` and initialize with your project
   URL + anon key (via `--dart-define`).
2. Create a `SupabaseRepository` with the same shapes as the mock providers,
   e.g. `Future<List<Doctor>> fetchDoctors()`, `fetchHospitals()`,
   `fetchLabs()`, `fetchPharmacies()`, `fetchMedicines()`, etc.
   Table shapes map 1:1 to the model classes in `lib/models.dart`.
3. In `AppState`, replace reads of the mock lists with repository calls
   (keep the same method names the UI uses: `activeDoctors`,
   `activeHospitals`, …) and route writes (bookings, orders, cart, favorites)
   through Supabase tables + Row Level Security.
4. Admin CRUD specs (`doctorSpec()`, `hospitalSpec()`, … in
   `lib/state/app_state.dart`) already centralize create/update/delete —
   point those at Supabase and the whole admin console goes live.

Auth: replace the demo `login()`/`loginAsGuest()` with
`Supabase.instance.client.auth` (email/password, magic link, Google OAuth).
The `AppState.role` concept maps to a `role` column on the user profile.
