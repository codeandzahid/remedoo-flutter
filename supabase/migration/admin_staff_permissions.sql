-- Staff (employee admin) system — owner orders 2026-10-18.
-- Super admin (role 'admin') = full authority over project + data.
-- Staff (role 'staff') = ONLY the admin sections the super admin
-- ticks for them, enforced in the database via RLS (not just hidden
-- menus). secure_settings is NEVER available to staff.

-- 1) New role value
alter type public.app_role add value if not exists 'staff';

-- 2) Per-staff section permissions
create table if not exists public.admin_permissions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sections jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.admin_permissions enable row level security;

drop policy if exists "Admins manage staff permissions" on public.admin_permissions;
create policy "Admins manage staff permissions" on public.admin_permissions
  for all to authenticated
  using (exists (select 1 from public.user_roles ur where ur.user_id = auth.uid() and ur.role = 'admin'))
  with check (exists (select 1 from public.user_roles ur where ur.user_id = auth.uid() and ur.role = 'admin'));

drop policy if exists "Staff read own permissions" on public.admin_permissions;
create policy "Staff read own permissions" on public.admin_permissions
  for select to authenticated using (user_id = auth.uid());

-- 3) Helper: does the signed-in staff user hold a section?
create or replace function public.staff_has_section(sec text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_permissions ap
    where ap.user_id = auth.uid() and ap.sections ? sec
  );
$$;

-- 4) Staff data policies, mapped section -> tables.
-- Section editors (full CRUD on their tables):
drop policy if exists "Staff section access" on public.doctors;
create policy "Staff section access" on public.doctors for all to authenticated
  using (public.staff_has_section('doctors')) with check (public.staff_has_section('doctors'));
drop policy if exists "Staff section access" on public.hospitals;
create policy "Staff section access" on public.hospitals for all to authenticated
  using (public.staff_has_section('hospitals')) with check (public.staff_has_section('hospitals'));
drop policy if exists "Staff section access" on public.labs;
create policy "Staff section access" on public.labs for all to authenticated
  using (public.staff_has_section('labs')) with check (public.staff_has_section('labs'));
drop policy if exists "Staff section access" on public.pharmacies;
create policy "Staff section access" on public.pharmacies for all to authenticated
  using (public.staff_has_section('pharmacies')) with check (public.staff_has_section('pharmacies'));
drop policy if exists "Staff section access" on public.lab_tests;
create policy "Staff section access" on public.lab_tests for all to authenticated
  using (public.staff_has_section('lab_tests')) with check (public.staff_has_section('lab_tests'));
drop policy if exists "Staff section access" on public.medicines;
create policy "Staff section access" on public.medicines for all to authenticated
  using (public.staff_has_section('medicines') or public.staff_has_section('inventory'))
  with check (public.staff_has_section('medicines') or public.staff_has_section('inventory'));
drop policy if exists "Staff section access" on public.provider_applications;
create policy "Staff section access" on public.provider_applications for all to authenticated
  using (public.staff_has_section('applications')) with check (public.staff_has_section('applications'));
drop policy if exists "Staff section access" on public.reviews;
create policy "Staff section access" on public.reviews for all to authenticated
  using (public.staff_has_section('reviews')) with check (public.staff_has_section('reviews'));
drop policy if exists "Staff section access" on public.orders;
create policy "Staff section access" on public.orders for all to authenticated
  using (public.staff_has_section('orders')) with check (public.staff_has_section('orders'));
drop policy if exists "Staff section access" on public.order_items;
create policy "Staff section access" on public.order_items for all to authenticated
  using (public.staff_has_section('orders')) with check (public.staff_has_section('orders'));
drop policy if exists "Staff section access" on public.appointments;
create policy "Staff section access" on public.appointments for all to authenticated
  using (public.staff_has_section('appointments')) with check (public.staff_has_section('appointments'));
drop policy if exists "Staff section access" on public.refunds;
create policy "Staff section access" on public.refunds for all to authenticated
  using (public.staff_has_section('refunds')) with check (public.staff_has_section('refunds'));
drop policy if exists "Staff section access" on public.emergency_requests;
create policy "Staff section access" on public.emergency_requests for all to authenticated
  using (public.staff_has_section('emergencies')) with check (public.staff_has_section('emergencies'));
drop policy if exists "Staff section access" on public.ambulances;
create policy "Staff section access" on public.ambulances for all to authenticated
  using (public.staff_has_section('ambulance')) with check (public.staff_has_section('ambulance'));
drop policy if exists "Staff section access" on public.support_tickets;
create policy "Staff section access" on public.support_tickets for all to authenticated
  using (public.staff_has_section('support')) with check (public.staff_has_section('support'));
drop policy if exists "Staff section access" on public.support_messages;
create policy "Staff section access" on public.support_messages for all to authenticated
  using (public.staff_has_section('support')) with check (public.staff_has_section('support'));
drop policy if exists "Staff section access" on public.announcements;
create policy "Staff section access" on public.announcements for all to authenticated
  using (public.staff_has_section('announcements')) with check (public.staff_has_section('announcements'));
drop policy if exists "Staff section access" on public.notifications;
create policy "Staff section access" on public.notifications for all to authenticated
  using (public.staff_has_section('announcements')) with check (public.staff_has_section('announcements'));
drop policy if exists "Staff section access" on public.app_config;
create policy "Staff section access" on public.app_config for all to authenticated
  using (public.staff_has_section('settings') or public.staff_has_section('branding') or public.staff_has_section('commission') or public.staff_has_section('subscriptions') or public.staff_has_section('corporate') or public.staff_has_section('packages') or public.staff_has_section('service_areas') or public.staff_has_section('featured') or public.staff_has_section('remedoo_pay'))
  with check (public.staff_has_section('settings') or public.staff_has_section('branding') or public.staff_has_section('commission') or public.staff_has_section('subscriptions') or public.staff_has_section('corporate') or public.staff_has_section('packages') or public.staff_has_section('service_areas') or public.staff_has_section('featured') or public.staff_has_section('remedoo_pay'));
drop policy if exists "Staff section access" on public.remedoo_pay_sessions;
create policy "Staff section access" on public.remedoo_pay_sessions for all to authenticated
  using (public.staff_has_section('remedoo_pay')) with check (public.staff_has_section('remedoo_pay'));

-- Provider UPI screen edits provider records: UPDATE only.
drop policy if exists "Staff provider payments update" on public.doctors;
create policy "Staff provider payments update" on public.doctors for update to authenticated
  using (public.staff_has_section('provider_payments')) with check (public.staff_has_section('provider_payments'));
drop policy if exists "Staff provider payments update" on public.hospitals;
create policy "Staff provider payments update" on public.hospitals for update to authenticated
  using (public.staff_has_section('provider_payments')) with check (public.staff_has_section('provider_payments'));
drop policy if exists "Staff provider payments update" on public.labs;
create policy "Staff provider payments update" on public.labs for update to authenticated
  using (public.staff_has_section('provider_payments')) with check (public.staff_has_section('provider_payments'));
drop policy if exists "Staff provider payments update" on public.pharmacies;
create policy "Staff provider payments update" on public.pharmacies for update to authenticated
  using (public.staff_has_section('provider_payments')) with check (public.staff_has_section('provider_payments'));

-- Users section: view profiles + roles, edit profiles; roles are
-- super-admin territory (no staff write on user_roles).
drop policy if exists "Staff users read" on public.user_roles;
create policy "Staff users read" on public.user_roles for select to authenticated
  using (public.staff_has_section('users'));
drop policy if exists "Staff users profiles" on public.profiles;
create policy "Staff users profiles" on public.profiles for select to authenticated
  using (public.staff_has_section('users'));
drop policy if exists "Staff users profiles update" on public.profiles;
create policy "Staff users profiles update" on public.profiles for update to authenticated
  using (public.staff_has_section('users')) with check (public.staff_has_section('users'));

-- Dashboard / Revenue / Analytics: read-only aggregates.
drop policy if exists "Staff insights read" on public.appointments;
create policy "Staff insights read" on public.appointments for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));
drop policy if exists "Staff insights read" on public.orders;
create policy "Staff insights read" on public.orders for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));
drop policy if exists "Staff insights read" on public.remedoo_pay_sessions;
create policy "Staff insights read" on public.remedoo_pay_sessions for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));
drop policy if exists "Staff insights read" on public.profiles;
create policy "Staff insights read" on public.profiles for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));
drop policy if exists "Staff insights read" on public.provider_applications;
create policy "Staff insights read" on public.provider_applications for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));
drop policy if exists "Staff insights read" on public.support_tickets;
create policy "Staff insights read" on public.support_tickets for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));
drop policy if exists "Staff insights read" on public.emergency_requests;
create policy "Staff insights read" on public.emergency_requests for select to authenticated
  using (public.staff_has_section('dashboard') or public.staff_has_section('revenue') or public.staff_has_section('analytics'));

-- Export Data section: read-only on the exportable datasets.
drop policy if exists "Staff export read" on public.doctors;
create policy "Staff export read" on public.doctors for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.hospitals;
create policy "Staff export read" on public.hospitals for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.labs;
create policy "Staff export read" on public.labs for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.lab_tests;
create policy "Staff export read" on public.lab_tests for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.pharmacies;
create policy "Staff export read" on public.pharmacies for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.medicines;
create policy "Staff export read" on public.medicines for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.appointments;
create policy "Staff export read" on public.appointments for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.orders;
create policy "Staff export read" on public.orders for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.order_items;
create policy "Staff export read" on public.order_items for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.profiles;
create policy "Staff export read" on public.profiles for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.user_roles;
create policy "Staff export read" on public.user_roles for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.remedoo_pay_sessions;
create policy "Staff export read" on public.remedoo_pay_sessions for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.support_tickets;
create policy "Staff export read" on public.support_tickets for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.reviews;
create policy "Staff export read" on public.reviews for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.announcements;
create policy "Staff export read" on public.announcements for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.provider_applications;
create policy "Staff export read" on public.provider_applications for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.refunds;
create policy "Staff export read" on public.refunds for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.emergency_requests;
create policy "Staff export read" on public.emergency_requests for select to authenticated using (public.staff_has_section('export_data'));
drop policy if exists "Staff export read" on public.notifications;
create policy "Staff export read" on public.notifications for select to authenticated using (public.staff_has_section('export_data'));
