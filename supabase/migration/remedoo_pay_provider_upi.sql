-- Remedoo Pay: per-provider UPI (panelists receive payments directly).
-- Sessions remember which UPI a payment belongs to; providers can read
-- and update (confirm/cancel) only their own sessions.
alter table public.remedoo_pay_sessions
  add column if not exists vpa text,
  add column if not exists payee_name text,
  add column if not exists provider_kind text,
  add column if not exists provider_id text,
  add column if not exists provider_user_id uuid;

create policy "Providers read own remedoo pay sessions"
  on public.remedoo_pay_sessions
  for select to authenticated using (provider_user_id = auth.uid());

create policy "Providers update own remedoo pay sessions"
  on public.remedoo_pay_sessions
  for update to authenticated
  using (provider_user_id = auth.uid())
  with check (provider_user_id = auth.uid());

-- Optional "name on the UPI account" per provider record (the UPI apps
-- show this name to the customer; it should match the bank record).
alter table public.doctors add column if not exists upi_payee_name text;
alter table public.pharmacies add column if not exists upi_payee_name text;
alter table public.labs add column if not exists upi_payee_name text;
alter table public.hospitals add column if not exists upi_payee_name text;
