# Remedoo — Project Overview

> Single-point reference for understanding the entire project: what it is,
> how it's built, and how the pieces fit together.

---

## 1. What Remedoo Is

A **multi-vendor healthcare marketplace** (Practo + PharmEasy in one),
built for the Kashmir/J&K region. Three apps, one backend, one brand.

| App | Audience | Entry | APK / ID |
|---|---|---|---|
| **Remedoo** (patient) | Patients | `lib/main.dart` | `com.remedoo.remedoo_app` |
| **Remedoo Partner** | Doctors, pharmacies, labs, hospitals | `lib/main_partner.dart` | `com.remedoo.remedoo_partner` |
| **Remedoo Admin** | Platform operators | `lib/main_admin.dart` | `com.remedoo.remedoo_admin` |

**Website**: patient app compiled to Flutter web, hosted at
`https://remedoo-app.pages.dev/` (Cloudflare Pages, auto-deploy on push).

**Business model**: providers join the platform, receive bookings/orders,
platform takes commission (`platform_commission_config` table).

---

## 2. Patient App — Screens & Flows

Entry: `lib/main.dart` → splash → onboarding (once) → dashboard.

### Navigation
- **Bottom nav**: Home, Hospitals, (more), with slide+fade hide on drawer open
- **Sidebar drawer**: items visible in guest mode; protected items
  (Favorites, Orders, Appointments, Family, Reminders, Profile) show
  login toast + redirect when tapped by guests

### Guest rules (strict)
- Book Appointment buttons **hidden** in guest mode (not shown-then-blocked)
- Government hospitals: **no** Book button by design (list + detail)
- Open for guests: dashboard, lists, Emergency/SOS, Order Medicines, Smart Care
- Gated (toast + login redirect): detail screens, booking, favorites, checkout,
  support, dashboard tiles/stats, Settings

### Patient screens (44)
| Area | Screens |
|---|---|
| Onboarding/Auth | splash, onboarding, login, signup, forgot_password, reset_password |
| Home | dashboard, notifications, symptom_checker, care_match, emergency |
| Doctors | doctors (list), doctor_detail, booking, appointments, appointment_detail |
| Hospitals | hospitals (list), hospital_detail |
| Labs | labs (list), lab_detail, lab_reports, lab_report_detail |
| Pharmacy | pharmacies (list), pharmacy_detail, remedoo_pharmacy, cart, remedoo_checkout, online_payment, payment_failure, orders, order_tracking, refund_tracking |
| Account | profile, family, favorites, reminders, medical_history, settings |
| Support | support_tickets |
| Provider onboarding | provider_type, provider_register, pending_approval |
| Misc | analytics, maintenance, main_shell |

### Key patient flows
1. **Book appointment**: doctors list → detail → booking → confirm → appointments
2. **Order medicines**: pharmacy → cart → checkout → UPI/online payment → order tracking
3. **Lab tests**: labs list → detail → book → reports appear in lab_reports
4. **Emergency**: emergency screen → SOS trigger

---

## 3. Partner App — Provider Dashboards

Entry: `lib/main_partner.dart` → `PartnerRootGate` → provider login →
role-based dashboard (role read from `user_roles` table).

| Role | Dashboard file | Tabs / Features |
|---|---|---|
| doctor | `doctor_dashboard.dart` | **Visits** (today/upcoming, confirm/done/cancel), **Profile** (edit name, specialty, fee, hours, bio), **Payments** (UPI ID, accept-UPI toggle, pay-in-clinic toggle), **Reviews** (rating, count, comments) |
| pharmacy | `pharmacy_dashboard.dart` | Orders to fulfill: Confirm → Out for delivery → Delivered, Cancel; order items, totals, payment method, delivery address |
| lab | `lab_dashboard.dart` | Bookings: Confirm booking → Report ready, Cancel |
| hospital | `hospital_dashboard.dart` | Appointments: Confirm visit → Mark visit done, Cancel |

All dashboards use **provider-scoped queries** (RLS: `auth.uid() = user_id`
on own record; appointment/order policies scope to own provider ID).

---

## 4. Admin App — Back Office

Entry: `lib/main_admin.dart` → admin login (Supabase Auth + `user_roles`
admin check) → `admin_shell` with 7 sections:

| Section | Screens |
|---|---|
| Overview | admin_dashboard (stats, charts) |
| Catalog | admin_crud (doctors, hospitals, labs, lab tests, pharmacies, medicines) |
| Providers | admin_approvals (applications → approve creates provider record + role), provider payments |
| Orders & Care | admin_orders, admin_appointments, admin_payments, refunds, emergencies, ambulance |
| Content | admin_broadcast (announcements), reviews, support tickets |
| Settings | admin_app_settings, admin_config (branding, themes, fees, emergency numbers) |
| Insights | admin_analytics, admin_revenue, admin_users |

**Grant admin**: `INSERT INTO public.user_roles (user_id, role)
SELECT id, 'admin' FROM auth.users WHERE email = 'X'
ON CONFLICT DO NOTHING;`

---

## 5. UI System

### Themes — `lib/theme.dart` (891 lines)
6 theme packs, user-switchable in Settings → Appearance, persisted per-user
(`profiles.theme_pack`), synced live across devices via Supabase realtime:

1. **Sky Pulse** (default, locked primary) 2. **Ocean Sand**
3. **Lavender Mist** 4. **Blush Rose** 5. **Honey Glow** 6. **Emerald Heal**

**Rule**: every accent follows the active theme. No hardcoded orange.
`RemedooTheme.warning` is a theme getter. Brand logos excepted.

### Reusable widgets — `lib/widgets/widgets.dart` (2643 lines)
- `RDoctorCard`, `RHospitalCard`, `RAvatarCircle`, `RStarRating` (mockup-style cards)
- `RDenseRow`, `RDenseMeta`, `RDenseGroup` (dense list layouts — preferred)
- `RRibbon`, `InitialsAvatar`, `RQuickActionsGrid` (removed from desktop sidebar)
- `upi_payment_sheet.dart`, `upi_setup_dialog.dart` (provider UPI flows)
- `patient_sidebar.dart`, `theme_backdrop.dart`, `email_otp_field.dart`

### Design rules
- Dense list layouts everywhere
- Theme-tinted circular avatars, star ratings
- Plain-language UI for provider/admin screens ("easy understanding")
- No modal popups for guest gating (toast + redirect, matching reference site)

---

## 6. Data & Backend

**Supabase project**: `remedoo` (user-owned, Free plan, Mumbai ap-south-1)
- URL: `https://zjlznbgcfzpcveqyjglf.supabase.co`
- Config single source: `lib/services/supabase_config.dart`

### Code layers
| File | Lines | Role |
|---|---|---|
| `lib/services/auth_service.dart` | 363 | Sign-up/in/out, password reset, `currentUserRole()` |
| `lib/services/supabase_repository.dart` | 1192 | ALL data access: catalog, appointments, orders, favorites, profiles, provider ops |
| `lib/state/app_state.dart` | 2005 | Global state, auth listener, role routing |
| `lib/models.dart` | ~470 | 17 models: Doctor, Hospital, Lab, Pharmacy, Medicine, Appointment, MedOrder, etc. |

### Database — 89 tables (`supabase/migration/`)
- **Catalog**: doctors (54), hospitals (48), labs (31), pharmacies (31),
  medicines (138), lab_tests (33), departments, lab_test_packages
- **Transactions**: appointments, remedoo_orders, prescription_items,
  refunds, transactions, provider_earnings, provider_wallets
- **Users**: profiles, user_roles, family_members, favorites,
  health_reminders, medical_history, notifications
- **Providers**: provider_applications, provider_payment_accounts,
  delivery_drivers, driver_locations, delivery_orders
- **Platform**: app_config, announcements, theme_packs, platform_settings,
  platform_branding, platform_commission_config, ads, slider_media
- **Care**: emergency_requests, ambulance_trips, ambulances,
  support_tickets, reviews, symptom_* tables

### Auth & roles
- `app_role` enum: admin, moderator, user, doctor, pharmacy, lab,
  hospital, driver
- Roles in `public.user_roles`; provider records link via `user_id` FK
- RLS: provider-scoped policies (17 policies); appointment trigger allows
  providers to confirm/complete own bookings, patients can only cancel
- Emails from `noreply@mail.app.supabase.io` (default SMTP)

---

## 7. Demo Accounts

All password: `Khanday@7006#` — emails confirmed, roles assigned:

| Email | Role | Linked record |
|---|---|---|
| admin@remedoo.com | admin | — (Admin app) |
| doctor@remedoo.com | doctor | Dr. Ghulam Nabi Lone (Partner app) |
| pharmacy@remedoo.com | pharmacy | Kashmir Medicos (Partner app) |
| hospital@remedoo.com | hospital | SKIMS (Partner app) |
| lab@remedoo.com | lab | Kashmir Clinical Lab (Partner app) |
| patient@remedoo.com | user | — (Patient app) |
| user@remedoo.com | user | — (Patient app) |
| driver@remedoo.com | driver | — (driver flows) |

User's own: noorkhanjan0055@gmail.com → Dr. M. S. Khuroo (doctor role).

---

## 8. Build & Deploy

| Target | Workflow | Output |
|---|---|---|
| Website | `deploy-web.yml` (push → Cloudflare Pages) | remedoo-app.pages.dev |
| Patient APK | `build-patient-apk.yml` | `com.remedoo.remedoo_app` |
| Admin APK | `build-admin-apk.yml` | `com.remedoo.remedoo_admin` |
| Partner APK | `build-partner-apk.yml` | `com.remedoo.remedoo_partner` |

- One persistent release keystore (GitHub secrets) — all APKs share signature
- Version 1.0.0+2; concurrency cancel-in-progress on all workflows
- Logos: `assets/logo/` — teal (patient), indigo (admin), emerald (partner);
  flavor-specific launcher icons in `android/app/src/{main,admin,partner}/`

---

## 9. Standing Rules (don't break)

- Government hospitals: no Book Appointment button (intentional)
- Book buttons hidden in guest mode (not shown-then-blocked)
- Onboarding shows once; no forced login after onboarding
- Smart Care lives under Services, not dashboard top
- Every color follows the active theme (no hardcoded orange)
- "Do everything on website only" — exceptions: Admin APK, Partner APK
- "App means apk" — always deliver installable APKs, not just code
- Remove demo/fake data; everything must be real
- If built externally, rebuild as own
