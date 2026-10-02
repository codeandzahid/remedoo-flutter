# Remedoo Flutter — Feature Checklist

All patient, admin and role-portal screens. Status: **done** = implemented,
wired to `AppState`, `flutter analyze` clean, widget tests passing.

## Patient app (44 screens)

- [x] `splash_screen.dart` — orange splash, auto-advance (1.5s)
- [x] `onboarding_screen.dart` — 4 slides, PageView + dots + Skip
- [x] `login_screen.dart` — Password | Magic Link tabs, Google (demo), guest, **Admin** link
- [x] `signup_screen.dart` — password strength bars
- [x] `forgot_password_screen.dart` — reset link (demo) → reset screen
- [x] `reset_password_screen.dart` — strength bars, confirm match
- [x] `provider_register_screen.dart` — role selector + license → pending approval
- [x] `pending_approval_screen.dart` — application ID from state
- [x] `dashboard_screen.dart` — gradient header, greeting, search, Smart Care Finder,
      categories, promo carousel, feature trio, live stats, upcoming appointments,
      popular doctors/hospitals/medicines (ADD→stepper), benefits, explore, services,
      health tips, sponsored, "?" help FAB
- [x] `doctors_screen.dart` — search, 13 specialty chips, 6 sorts, 3 quick filters,
      promo banner, live count, fee band cards
- [x] `doctor_detail_screen.dart` — profile, about, hospital, hours, sticky booking
- [x] `booking_screen.dart` — doctor/hospital/lab modes, 7-day chips, time pills,
      notes, payment cards, confirm → state + toast; reschedule prefill mode
- [x] `appointments_screen.dart` — Upcoming/Past tabs, reschedule + cancel (working)
- [x] `appointment_detail_screen.dart` — summary, status pill, cancel/reschedule, review CTA
- [x] `hospitals_screen.dart` — search, sort, 4 quick filters, promo, 48 hospitals,
      ICU/Government bands, book → booking (hospital mode)
- [x] `hospital_detail_screen.dart` — departments, facilities, doctors at hospital, sticky booking
- [x] `labs_screen.dart` — 31 labs, 4 quick filters, offers band, compare picker
- [x] `lab_detail_screen.dart` — NABL badge, test list with ADD, Book Tests → booking (lab mode)
- [x] `lab_reports_screen.dart` — search, All/In Progress/Completed chips
- [x] `lab_report_detail_screen.dart` — results table with flags, Download (demo)
- [x] `pharmacies_screen.dart` — 31 pharmacies, filters, Remedoo Pharmacy hero card
- [x] `pharmacy_detail_screen.dart` — category chips, sort, Rx badges, ADD→stepper,
      medicine detail bottom sheet, sticky cart bar
- [x] `remedoo_pharmacy_screen.dart` — own store, grid, cart bar
- [x] `cart_screen.dart` — steppers, Rx upload (demo), GPS address, payment, bill summary
- [x] `remedoo_checkout_screen.dart` — address, prescription, payment, bill
- [x] `orders_screen.dart` — Active/Past tabs → tracking
- [x] `order_tracking_screen.dart` — ETA, vertical timeline, pharmacy card, bill
- [x] `payment_failure_screen.dart` — Try Again / Choose Different Method
- [x] `refund_tracking_screen.dart` — refund cards with 4-step timelines
- [x] `care_match_screen.dart` — symptom input + chips, care-type/urgency radios,
      budget & distance sliders, ranked matches, disclaimer
- [x] `symptom_checker_screen.dart` — 5-step chat flow → 3 condition cards + Find Care
- [x] `emergency_screen.dart` — red SOS (confirm dialog, no url_launcher), 6 quick
      contacts, nearby hospitals with Call/Directions/Book
- [x] `notifications_screen.dart` — Read all (working), 4 tabs, unread dots
- [x] `favorites_screen.dart` — from state, empty state + Explore
- [x] `family_screen.dart` — add/delete family members
- [x] `reminders_screen.dart` — Upcoming/Completed tabs, add form, complete toggle
- [x] `profile_screen.dart` — edit profile, GPS address, change password (demo), guest gate
- [x] `settings_screen.dart` — dark mode (real ThemeMode), notification toggle,
      language, privacy/about dialogs, **Switch role (demo)**, logout, v1.0.0
- [x] `medical_history_screen.dart` — All/Appointments/Prescriptions/Lab Reports chips
- [x] `support_tickets_screen.dart` — list + new ticket form (state)
- [x] `driver_dashboard_screen.dart` — online toggle, deliveries Accept→Picked Up→Delivered,
      Earnings + History tabs
- [x] `analytics_screen.dart` — stat cards, CustomPainter bar chart, top categories
- [x] `maintenance_screen.dart` — wired to `AppState.maintenanceMode` flag (default off)
- [x] `main_shell.dart` — bottom nav: Home, Hospitals, Labs, Pharmacy (cart badge), Orders

Shared: medicine detail bottom sheet, review dialog (stars + comment → state),
lab compare sheet (side-by-side), help dialog, confirm dialog.

## Admin console (`lib/screens/admin/`)

- [x] `admin_login_screen.dart` — demo auth `admin@remedoo.app` / `admin123`
- [x] `admin_shell.dart` — sectioned drawer (Overview/Management/Content/Operations/
      Configuration/Insights), content swaps, logout
- [x] `admin_crud_screen.dart` — generic search + Add/Edit dialog (field specs) +
      delete confirm + active toggle; instantiated for: Doctors, Hospitals, Labs,
      Pharmacies, Medicines, Users, Coupons, Promo Banners, Health Tips, FAQs,
      Slider items, Service Areas, Team members — all mutating the same mock data
      the patient UI reads (edits reflect live)
- [x] `admin_dashboard_screen.dart` — stat cards, revenue bar chart + orders donut
      (CustomPainter), recent activity
- [x] `admin_approvals_screen.dart` — Approve/Reject provider applications
- [x] `admin_orders_screen.dart` — filter + status-change dropdown
- [x] `admin_appointments_screen.dart` — filter + cancel action
- [x] `admin_emergencies_screen.dart` — Acknowledge/Dispatch SOS alerts
- [x] `admin_support_tickets_screen.dart` — reply box appends response
- [x] `admin_reviews_screen.dart` — Hide/Show toggle
- [x] `admin_broadcast_screen.dart` — compose → patient notification
- [x] `admin_revenue_screen.dart` — cards + chart + transactions table
- [x] `admin_analytics_screen.dart` — growth chart, top specialties/medicines
- [x] `admin_config_screens.dart` — OTP settings, commission %, subscriptions CRUD,
      corporate plans CRUD, healthcare packages CRUD, API keys (+regenerate),
      branding (name/tagline/**5 color swatches → live re-theme**), service areas CRUD,
      quick actions toggles, category actions toggles, info cards CRUD,
      quick access CRUD, featured doctors/medicines/providers pickers
- [x] `admin_ops_screens.dart` — payouts, refunds (Approve/Reject → patient
      RefundTracking), ambulance fleet status, delivery drivers (+assign),
      Remedoo Pharmacy inventory editor, sessions, login logs, suspicious activity

## Role portals (`lib/screens/roles/`)

- [x] `doctor_portal_screen.dart` — appointments (detail + Complete/Cancel),
      day-wise slot manager (add/remove), earnings
- [x] `driver_portal_screen.dart` — full delivery flow + Earnings + History tabs
- [x] `pharmacy_portal_screen.dart` — inventory (stock stepper + price edit),
      incoming orders (Placed → Packed → Out for Delivery → Delivered)
- [x] `lab_portal_screen.dart` — test catalog CRUD, bookings, report upload (demo)
- [x] `hospital_portal_screen.dart` — overview cards, doctors, appointments

## State

- [x] Global `role` (patient/doctor/admin/driver/pharmacy/lab/hospital) + `switchRole()`
- [x] Deep-link-free navigation (plain `Navigator` pushes; RootGate branches on role)

## Verification

- [x] `flutter analyze` — **No issues found**
- [x] `flutter test` — **6/6 widget tests pass** (+ 60-screen QA sweep, all clean)
