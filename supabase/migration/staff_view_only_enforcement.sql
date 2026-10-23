-- Staff view-only enforcement (owner order 2026-10-23).
--
-- The Team access picker now gives every option a level: no
-- access, view only, or full access. View-only is stored in
-- staff_permissions.sections as the base key plus a 'view:<key>'
-- marker, so staff_has_section() (read access) keeps working
-- unchanged. This migration adds the write-side helper and
-- converts every "Staff section access" policy: SELECT keeps
-- staff_has_section(...); INSERT/UPDATE/DELETE switch to
-- staff_can_write(...), which is false for view-only options.
--
-- Until this runs, view-only is enforced by the app (change
-- buttons hidden); afterwards the database enforces it too.
-- The super admin's own policies are separate and untouched.

create or replace function public.staff_can_write(sec text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.staff_permissions ap
    where ap.user_id = auth.uid()
      and ap.sections ? sec
      and not (ap.sections ? ('view:' || sec))
  );
$$;


drop policy if exists "Staff section access" on public.doctors;
drop policy if exists "Staff section read" on public.doctors;
drop policy if exists "Staff section insert" on public.doctors;
drop policy if exists "Staff section update" on public.doctors;
drop policy if exists "Staff section delete" on public.doctors;
create policy "Staff section read" on public.doctors for select to authenticated
  using (public.staff_has_section('doctors'));
create policy "Staff section insert" on public.doctors for insert to authenticated
  with check (public.staff_can_write('doctors'));
create policy "Staff section update" on public.doctors for update to authenticated
  using (public.staff_can_write('doctors')) with check (public.staff_can_write('doctors'));
create policy "Staff section delete" on public.doctors for delete to authenticated
  using (public.staff_can_write('doctors'));

drop policy if exists "Staff section access" on public.hospitals;
drop policy if exists "Staff section read" on public.hospitals;
drop policy if exists "Staff section insert" on public.hospitals;
drop policy if exists "Staff section update" on public.hospitals;
drop policy if exists "Staff section delete" on public.hospitals;
create policy "Staff section read" on public.hospitals for select to authenticated
  using (public.staff_has_section('hospitals'));
create policy "Staff section insert" on public.hospitals for insert to authenticated
  with check (public.staff_can_write('hospitals'));
create policy "Staff section update" on public.hospitals for update to authenticated
  using (public.staff_can_write('hospitals')) with check (public.staff_can_write('hospitals'));
create policy "Staff section delete" on public.hospitals for delete to authenticated
  using (public.staff_can_write('hospitals'));

drop policy if exists "Staff section access" on public.labs;
drop policy if exists "Staff section read" on public.labs;
drop policy if exists "Staff section insert" on public.labs;
drop policy if exists "Staff section update" on public.labs;
drop policy if exists "Staff section delete" on public.labs;
create policy "Staff section read" on public.labs for select to authenticated
  using (public.staff_has_section('labs'));
create policy "Staff section insert" on public.labs for insert to authenticated
  with check (public.staff_can_write('labs'));
create policy "Staff section update" on public.labs for update to authenticated
  using (public.staff_can_write('labs')) with check (public.staff_can_write('labs'));
create policy "Staff section delete" on public.labs for delete to authenticated
  using (public.staff_can_write('labs'));

drop policy if exists "Staff section access" on public.pharmacies;
drop policy if exists "Staff section read" on public.pharmacies;
drop policy if exists "Staff section insert" on public.pharmacies;
drop policy if exists "Staff section update" on public.pharmacies;
drop policy if exists "Staff section delete" on public.pharmacies;
create policy "Staff section read" on public.pharmacies for select to authenticated
  using (public.staff_has_section('pharmacies'));
create policy "Staff section insert" on public.pharmacies for insert to authenticated
  with check (public.staff_can_write('pharmacies'));
create policy "Staff section update" on public.pharmacies for update to authenticated
  using (public.staff_can_write('pharmacies')) with check (public.staff_can_write('pharmacies'));
create policy "Staff section delete" on public.pharmacies for delete to authenticated
  using (public.staff_can_write('pharmacies'));

drop policy if exists "Staff section access" on public.lab_tests;
drop policy if exists "Staff section read" on public.lab_tests;
drop policy if exists "Staff section insert" on public.lab_tests;
drop policy if exists "Staff section update" on public.lab_tests;
drop policy if exists "Staff section delete" on public.lab_tests;
create policy "Staff section read" on public.lab_tests for select to authenticated
  using (public.staff_has_section('lab_tests'));
create policy "Staff section insert" on public.lab_tests for insert to authenticated
  with check (public.staff_can_write('lab_tests'));
create policy "Staff section update" on public.lab_tests for update to authenticated
  using (public.staff_can_write('lab_tests')) with check (public.staff_can_write('lab_tests'));
create policy "Staff section delete" on public.lab_tests for delete to authenticated
  using (public.staff_can_write('lab_tests'));

drop policy if exists "Staff section access" on public.medicines;
drop policy if exists "Staff section read" on public.medicines;
drop policy if exists "Staff section insert" on public.medicines;
drop policy if exists "Staff section update" on public.medicines;
drop policy if exists "Staff section delete" on public.medicines;
create policy "Staff section read" on public.medicines for select to authenticated
  using (public.staff_has_section('medicines') or public.staff_has_section('inventory'));
create policy "Staff section insert" on public.medicines for insert to authenticated
  with check (public.staff_can_write('medicines') or public.staff_can_write('inventory'));
create policy "Staff section update" on public.medicines for update to authenticated
  using (public.staff_can_write('medicines') or public.staff_can_write('inventory')) with check (public.staff_can_write('medicines') or public.staff_can_write('inventory'));
create policy "Staff section delete" on public.medicines for delete to authenticated
  using (public.staff_can_write('medicines') or public.staff_can_write('inventory'));

drop policy if exists "Staff section access" on public.provider_applications;
drop policy if exists "Staff section read" on public.provider_applications;
drop policy if exists "Staff section insert" on public.provider_applications;
drop policy if exists "Staff section update" on public.provider_applications;
drop policy if exists "Staff section delete" on public.provider_applications;
create policy "Staff section read" on public.provider_applications for select to authenticated
  using (public.staff_has_section('applications'));
create policy "Staff section insert" on public.provider_applications for insert to authenticated
  with check (public.staff_can_write('applications'));
create policy "Staff section update" on public.provider_applications for update to authenticated
  using (public.staff_can_write('applications')) with check (public.staff_can_write('applications'));
create policy "Staff section delete" on public.provider_applications for delete to authenticated
  using (public.staff_can_write('applications'));

drop policy if exists "Staff section access" on public.reviews;
drop policy if exists "Staff section read" on public.reviews;
drop policy if exists "Staff section insert" on public.reviews;
drop policy if exists "Staff section update" on public.reviews;
drop policy if exists "Staff section delete" on public.reviews;
create policy "Staff section read" on public.reviews for select to authenticated
  using (public.staff_has_section('reviews'));
create policy "Staff section insert" on public.reviews for insert to authenticated
  with check (public.staff_can_write('reviews'));
create policy "Staff section update" on public.reviews for update to authenticated
  using (public.staff_can_write('reviews')) with check (public.staff_can_write('reviews'));
create policy "Staff section delete" on public.reviews for delete to authenticated
  using (public.staff_can_write('reviews'));

drop policy if exists "Staff section access" on public.orders;
drop policy if exists "Staff section read" on public.orders;
drop policy if exists "Staff section insert" on public.orders;
drop policy if exists "Staff section update" on public.orders;
drop policy if exists "Staff section delete" on public.orders;
create policy "Staff section read" on public.orders for select to authenticated
  using (public.staff_has_section('orders'));
create policy "Staff section insert" on public.orders for insert to authenticated
  with check (public.staff_can_write('orders'));
create policy "Staff section update" on public.orders for update to authenticated
  using (public.staff_can_write('orders')) with check (public.staff_can_write('orders'));
create policy "Staff section delete" on public.orders for delete to authenticated
  using (public.staff_can_write('orders'));

drop policy if exists "Staff section access" on public.order_items;
drop policy if exists "Staff section read" on public.order_items;
drop policy if exists "Staff section insert" on public.order_items;
drop policy if exists "Staff section update" on public.order_items;
drop policy if exists "Staff section delete" on public.order_items;
create policy "Staff section read" on public.order_items for select to authenticated
  using (public.staff_has_section('orders'));
create policy "Staff section insert" on public.order_items for insert to authenticated
  with check (public.staff_can_write('orders'));
create policy "Staff section update" on public.order_items for update to authenticated
  using (public.staff_can_write('orders')) with check (public.staff_can_write('orders'));
create policy "Staff section delete" on public.order_items for delete to authenticated
  using (public.staff_can_write('orders'));

drop policy if exists "Staff section access" on public.appointments;
drop policy if exists "Staff section read" on public.appointments;
drop policy if exists "Staff section insert" on public.appointments;
drop policy if exists "Staff section update" on public.appointments;
drop policy if exists "Staff section delete" on public.appointments;
create policy "Staff section read" on public.appointments for select to authenticated
  using (public.staff_has_section('appointments'));
create policy "Staff section insert" on public.appointments for insert to authenticated
  with check (public.staff_can_write('appointments'));
create policy "Staff section update" on public.appointments for update to authenticated
  using (public.staff_can_write('appointments')) with check (public.staff_can_write('appointments'));
create policy "Staff section delete" on public.appointments for delete to authenticated
  using (public.staff_can_write('appointments'));

drop policy if exists "Staff section access" on public.refunds;
drop policy if exists "Staff section read" on public.refunds;
drop policy if exists "Staff section insert" on public.refunds;
drop policy if exists "Staff section update" on public.refunds;
drop policy if exists "Staff section delete" on public.refunds;
create policy "Staff section read" on public.refunds for select to authenticated
  using (public.staff_has_section('refunds'));
create policy "Staff section insert" on public.refunds for insert to authenticated
  with check (public.staff_can_write('refunds'));
create policy "Staff section update" on public.refunds for update to authenticated
  using (public.staff_can_write('refunds')) with check (public.staff_can_write('refunds'));
create policy "Staff section delete" on public.refunds for delete to authenticated
  using (public.staff_can_write('refunds'));

drop policy if exists "Staff section access" on public.emergency_requests;
drop policy if exists "Staff section read" on public.emergency_requests;
drop policy if exists "Staff section insert" on public.emergency_requests;
drop policy if exists "Staff section update" on public.emergency_requests;
drop policy if exists "Staff section delete" on public.emergency_requests;
create policy "Staff section read" on public.emergency_requests for select to authenticated
  using (public.staff_has_section('emergencies'));
create policy "Staff section insert" on public.emergency_requests for insert to authenticated
  with check (public.staff_can_write('emergencies'));
create policy "Staff section update" on public.emergency_requests for update to authenticated
  using (public.staff_can_write('emergencies')) with check (public.staff_can_write('emergencies'));
create policy "Staff section delete" on public.emergency_requests for delete to authenticated
  using (public.staff_can_write('emergencies'));

drop policy if exists "Staff section access" on public.ambulances;
drop policy if exists "Staff section read" on public.ambulances;
drop policy if exists "Staff section insert" on public.ambulances;
drop policy if exists "Staff section update" on public.ambulances;
drop policy if exists "Staff section delete" on public.ambulances;
create policy "Staff section read" on public.ambulances for select to authenticated
  using (public.staff_has_section('ambulance'));
create policy "Staff section insert" on public.ambulances for insert to authenticated
  with check (public.staff_can_write('ambulance'));
create policy "Staff section update" on public.ambulances for update to authenticated
  using (public.staff_can_write('ambulance')) with check (public.staff_can_write('ambulance'));
create policy "Staff section delete" on public.ambulances for delete to authenticated
  using (public.staff_can_write('ambulance'));

drop policy if exists "Staff section access" on public.support_tickets;
drop policy if exists "Staff section read" on public.support_tickets;
drop policy if exists "Staff section insert" on public.support_tickets;
drop policy if exists "Staff section update" on public.support_tickets;
drop policy if exists "Staff section delete" on public.support_tickets;
create policy "Staff section read" on public.support_tickets for select to authenticated
  using (public.staff_has_section('support'));
create policy "Staff section insert" on public.support_tickets for insert to authenticated
  with check (public.staff_can_write('support'));
create policy "Staff section update" on public.support_tickets for update to authenticated
  using (public.staff_can_write('support')) with check (public.staff_can_write('support'));
create policy "Staff section delete" on public.support_tickets for delete to authenticated
  using (public.staff_can_write('support'));

drop policy if exists "Staff section access" on public.support_messages;
drop policy if exists "Staff section read" on public.support_messages;
drop policy if exists "Staff section insert" on public.support_messages;
drop policy if exists "Staff section update" on public.support_messages;
drop policy if exists "Staff section delete" on public.support_messages;
create policy "Staff section read" on public.support_messages for select to authenticated
  using (public.staff_has_section('support'));
create policy "Staff section insert" on public.support_messages for insert to authenticated
  with check (public.staff_can_write('support'));
create policy "Staff section update" on public.support_messages for update to authenticated
  using (public.staff_can_write('support')) with check (public.staff_can_write('support'));
create policy "Staff section delete" on public.support_messages for delete to authenticated
  using (public.staff_can_write('support'));

drop policy if exists "Staff section access" on public.announcements;
drop policy if exists "Staff section read" on public.announcements;
drop policy if exists "Staff section insert" on public.announcements;
drop policy if exists "Staff section update" on public.announcements;
drop policy if exists "Staff section delete" on public.announcements;
create policy "Staff section read" on public.announcements for select to authenticated
  using (public.staff_has_section('announcements'));
create policy "Staff section insert" on public.announcements for insert to authenticated
  with check (public.staff_can_write('announcements'));
create policy "Staff section update" on public.announcements for update to authenticated
  using (public.staff_can_write('announcements')) with check (public.staff_can_write('announcements'));
create policy "Staff section delete" on public.announcements for delete to authenticated
  using (public.staff_can_write('announcements'));

drop policy if exists "Staff section access" on public.notifications;
drop policy if exists "Staff section read" on public.notifications;
drop policy if exists "Staff section insert" on public.notifications;
drop policy if exists "Staff section update" on public.notifications;
drop policy if exists "Staff section delete" on public.notifications;
create policy "Staff section read" on public.notifications for select to authenticated
  using (public.staff_has_section('announcements'));
create policy "Staff section insert" on public.notifications for insert to authenticated
  with check (public.staff_can_write('announcements'));
create policy "Staff section update" on public.notifications for update to authenticated
  using (public.staff_can_write('announcements')) with check (public.staff_can_write('announcements'));
create policy "Staff section delete" on public.notifications for delete to authenticated
  using (public.staff_can_write('announcements'));

drop policy if exists "Staff section access" on public.app_config;
drop policy if exists "Staff section read" on public.app_config;
drop policy if exists "Staff section insert" on public.app_config;
drop policy if exists "Staff section update" on public.app_config;
drop policy if exists "Staff section delete" on public.app_config;
create policy "Staff section read" on public.app_config for select to authenticated
  using (public.staff_has_section('settings') or public.staff_has_section('branding') or public.staff_has_section('commission') or public.staff_has_section('subscriptions') or public.staff_has_section('corporate') or public.staff_has_section('packages') or public.staff_has_section('service_areas') or public.staff_has_section('featured') or public.staff_has_section('remedoo_pay'));
create policy "Staff section insert" on public.app_config for insert to authenticated
  with check (public.staff_can_write('settings') or public.staff_can_write('branding') or public.staff_can_write('commission') or public.staff_can_write('subscriptions') or public.staff_can_write('corporate') or public.staff_can_write('packages') or public.staff_can_write('service_areas') or public.staff_can_write('featured') or public.staff_can_write('remedoo_pay'));
create policy "Staff section update" on public.app_config for update to authenticated
  using (public.staff_can_write('settings') or public.staff_can_write('branding') or public.staff_can_write('commission') or public.staff_can_write('subscriptions') or public.staff_can_write('corporate') or public.staff_can_write('packages') or public.staff_can_write('service_areas') or public.staff_can_write('featured') or public.staff_can_write('remedoo_pay')) with check (public.staff_can_write('settings') or public.staff_can_write('branding') or public.staff_can_write('commission') or public.staff_can_write('subscriptions') or public.staff_can_write('corporate') or public.staff_can_write('packages') or public.staff_can_write('service_areas') or public.staff_can_write('featured') or public.staff_can_write('remedoo_pay'));
create policy "Staff section delete" on public.app_config for delete to authenticated
  using (public.staff_can_write('settings') or public.staff_can_write('branding') or public.staff_can_write('commission') or public.staff_can_write('subscriptions') or public.staff_can_write('corporate') or public.staff_can_write('packages') or public.staff_can_write('service_areas') or public.staff_can_write('featured') or public.staff_can_write('remedoo_pay'));

drop policy if exists "Staff section access" on public.remedoo_pay_sessions;
drop policy if exists "Staff section read" on public.remedoo_pay_sessions;
drop policy if exists "Staff section insert" on public.remedoo_pay_sessions;
drop policy if exists "Staff section update" on public.remedoo_pay_sessions;
drop policy if exists "Staff section delete" on public.remedoo_pay_sessions;
create policy "Staff section read" on public.remedoo_pay_sessions for select to authenticated
  using (public.staff_has_section('remedoo_pay'));
create policy "Staff section insert" on public.remedoo_pay_sessions for insert to authenticated
  with check (public.staff_can_write('remedoo_pay'));
create policy "Staff section update" on public.remedoo_pay_sessions for update to authenticated
  using (public.staff_can_write('remedoo_pay')) with check (public.staff_can_write('remedoo_pay'));
create policy "Staff section delete" on public.remedoo_pay_sessions for delete to authenticated
  using (public.staff_can_write('remedoo_pay'));
