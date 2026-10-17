-- Remedoo Pay (Cloudflare Worker) — payment sessions table.
-- Run once in the Supabase SQL editor.
create table if not exists public.remedoo_pay_sessions (
  id uuid primary key default gen_random_uuid(),
  order_id text not null,
  amount_paise integer not null,
  status text not null default 'QUEUED'
    check (status in ('QUEUED','ACTIVE','SUCCESS','FAILED','EXPIRED','CANCELLED')),
  customer jsonb,
  description text,
  return_url text,
  utr text,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  paid_at timestamptz
);

alter table public.remedoo_pay_sessions enable row level security;
-- No public policies on purpose: only the service role (the Remedoo
-- Pay Worker and Supabase Edge Functions) can read/write sessions.

create index if not exists idx_rps_status_created
  on public.remedoo_pay_sessions (status, created_at);
