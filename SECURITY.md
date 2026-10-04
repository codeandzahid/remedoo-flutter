# Remedoo Security Posture

Last audited: 2026-10-04. This document describes how the project is
protected. Keep it current when the data model or auth flow changes.

## Architecture

- **Backend:** Supabase (Postgres + Auth + Storage), project `remedoo`
  (`zjlznbgcfzpcveqyjglf`, Mumbai). All client data access goes through
  PostgREST with Row Level Security — RLS is the primary defense.
- **Client:** Flutter (web + mobile). Ships with the **anon/publishable key
  only** (`lib/services/supabase_config.dart`). The anon key is public by
  design; it grants nothing by itself. **No service_role key exists anywhere
  in the client, repo, or deploys.** Never add one.
- **No custom backend / edge functions** holding secrets.

## Authentication

- Supabase Auth: email+password, email OTP (registration), password reset.
- Passwords are never stored, logged, or transmitted except inside the
  TLS-encrypted Auth API calls. No `debugPrint` of credentials anywhere.
- OTP resend has a 30s in-app cooldown; Supabase enforces its own
  auth-endpoint rate limits (brute-force protection on login/OTP).
- Admin access: Supabase sign-in **plus** the `admin` role in `user_roles`.
  The old hardcoded `admin@remedoo.app / admin123` bypass is removed.
  Roles are granted only via SQL by the project owner:
  ```sql
  INSERT INTO public.user_roles (user_id, role)
  SELECT id, 'admin'::app_role FROM auth.users
  WHERE email = 'OWNER_EMAIL'
  ON CONFLICT (user_id, role) DO NOTHING;
  ```
- `user_roles` SELECT is scoped to the caller's own rows; INSERT has no
  user-facing policy (the dead self-assign policy was dropped in
  `security_hardening.sql`), so privilege escalation via the API is not
  possible. The `app_role` enum is `('admin','moderator','user')`.

## Row Level Security rules (enforced in Postgres, not in app code)

- **Catalog** (doctors, hospitals, labs, lab_tests, pharmacies, medicines):
  public read; insert/update/delete require the `admin` role
  (`has_role(auth.uid(), 'admin')`).
- **User data** (profiles, appointments, orders, favorites, family,
  prescriptions, payments, refunds, notifications, support tickets):
  strictly scoped to `auth.uid() = user_id` (or `patient_id`).
- **Appointments:** patients may ONLY cancel their own (`status='cancelled'`
  policy + `trg_patient_appointment_cancel` trigger that rejects any other
  column change or status value; admins bypass the trigger).
- **Orders:** patients cannot update at all (admin-only).
- **Support tickets:** patients create + read own; only admins update
  (prevents forging `admin_response`).
- **Provider applications:** applicants insert/view own; admins manage all.
- **Announcements / app_config:** public read; admin-only write.
- **Storage:** avatars public-read but writes folder-scoped to the user's own
  `user_id`; prescriptions and lab reports are private buckets with
  folder-scoped policies.

## What's intentionally public

Catalog listings, theme packs, announcements, app config, branding assets.
These contain no personal data.

## Operational rules

1. Never commit secrets (service_role keys, API tokens, passwords) — the
   repo contains none.
2. Schema/RLS changes go through `supabase/migration/*.sql` files AND must be
   applied to production; keep both in sync.
3. When adding a table, default to: RLS enabled, no public write, narrowest
   USING/WITH CHECK. Review with the checklist above.
4. Admin role grants are manual SQL by the owner — never build a UI for it.
5. UPI deep links (`upi://pay`) prove nothing about payment — never mark an
   order paid without gateway/webhook verification.
