# Remedoo Backend Migration Guide

**Goal:** Move off Supabase Cloud onto the user's own hosting in the future.
**Status:** Codebase is migration-ready. This doc is the runbook.

## Why this will be straightforward

The Flutter app never talks to Supabase directly except through three files:

| File | Role | Migration action |
|---|---|---|
| `lib/services/supabase_config.dart` | Backend URL + anon key (single source of truth) | Point at new server |
| `lib/services/supabase_repository.dart` | All data reads/writes (catalog, appointments, orders, etc.) | Swap for new backend client |
| `lib/services/auth_service.dart` | Sign-up, sign-in, sign-out, password reset | Swap for new auth |

No screen, widget, or state file hardcodes a backend URL (verified 2026-10-05).

## What the future backend must provide

### 1. Database — 89 tables
Full schema lives in `supabase/migration/` (apply in order):
- `schema_part_01.sql` → `schema_part_04.sql` — core tables
- `provider_roles.sql`, `provider_rls.sql` — roles + row-level security
- `provider_appointment_trigger.sql` — appointment status rules
- `upi_provider_ids.sql`, `upi_payment_toggles.sql` — payment fields
- `theme_packs.sql` — app themes
- `admin_panel_backend.sql` — admin config tables
- `profile_extra_fields.sql`, `security_hardening.sql` — extras
- `mig_data_*.sql` — seed catalog data (54 doctors, 48 hospitals, 31 labs, 31 pharmacies, 138 medicines, 33 lab tests)

Any PostgreSQL 15+ server works. Row-level security policies are in the
migration files — re-apply them or enforce the same rules in the API layer.

### 2. Auth — must support
- Email + password sign-up / sign-in / sign-out
- Email confirmation links (or OTP)
- Password reset emails
- JWT sessions the app can store and refresh
- A `user_roles` lookup (admin, doctor, pharmacy, lab, hospital)

Options: self-hosted Supabase (Docker, zero app changes beyond the URL),
or any backend (Firebase, Appwrite, custom API) with a rewritten
`supabase_repository.dart` / `auth_service.dart`.

### 3. Email sending
Auth emails (verification, password reset). Use the Gmail SMTP setup or
any transactional provider on the new host.

## Migration steps (when the user buys hosting)

1. Provision server (VPS with Docker, or managed Postgres).
2. Create database, apply `supabase/migration/*.sql` in order.
3. Export data from Supabase Cloud (dashboard → database → backups, or `pg_dump`).
4. Import into the new database.
5. Deploy auth (self-hosted Supabase Auth, or new provider).
6. Update `SupabaseConfig.url` (and key) in the app.
7. Rebuild website + all three APKs, redeploy.
8. Point domain DNS to new hosting.
9. Keep Supabase Cloud as read-only fallback for 1 week, then decommission.

## Website hosting (separate, trivial)
Flutter web builds to static files in `build/web/`. Upload to any host
(Hostinger, cPanel, S3, VPS+nginx). No server-side code needed.
