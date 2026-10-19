-- Cancel-OTP refunds + customer UPI capture (owner order 2026-10-19).
--
-- Adds refund tracking and payment-reference columns so that:
--  * cancelling a paid-online order/appointment records a refund
--    request the provider can act on,
--  * the customer's own UPI ID (for the refund) is stored with the
--    order/appointment and with the Remedoo Pay session,
--  * the Remedoo Pay session records which UPI the money was received
--    on (vpa, already present) and who paid (payer_vpa / payer_name).
--
-- Idempotent: safe to run more than once in the Supabase SQL editor
-- (Dashboard > SQL Editor > New query > paste > Run).

alter table public.orders
  add column if not exists refund_status text,
  add column if not exists refund_amount numeric,
  add column if not exists refund_at timestamptz,
  add column if not exists refund_utr text,
  add column if not exists refund_requested_at timestamptz,
  add column if not exists customer_upi text,
  add column if not exists payment_ref text;

alter table public.appointments
  add column if not exists refund_status text,
  add column if not exists refund_amount numeric,
  add column if not exists refund_at timestamptz,
  add column if not exists refund_utr text,
  add column if not exists refund_requested_at timestamptz,
  add column if not exists customer_upi text,
  add column if not exists payment_ref text;

alter table public.remedoo_pay_sessions
  add column if not exists payer_vpa text,
  add column if not exists payer_name text,
  add column if not exists refund_status text,
  add column if not exists refund_at timestamptz,
  add column if not exists refund_utr text,
  add column if not exists refund_requested_at timestamptz;

-- Lookups by payment reference (panelist refund actions join on it).
create index if not exists idx_orders_payment_ref
  on public.orders (payment_ref);
create index if not exists idx_appointments_payment_ref
  on public.appointments (payment_ref);
