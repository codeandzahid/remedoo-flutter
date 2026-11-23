-- Remedoo Pay as a standalone, reusable payment system (owner order
-- 2026-11-23): other projects can use Remedoo Pay through its API,
-- not only the Remedoo app. Run once in the Supabase SQL editor.
--
-- Backward compatible: existing sessions keep working; project_id
-- is nullable and the Remedoo app needs no changes (it sends no
-- projectId and is treated as the built-in 'remedoo' project).

-- Which project/merchant a session belongs to (null/'remedoo' =
-- the Remedoo app itself).
alter table public.remedoo_pay_sessions
  add column if not exists project_id text;

create index if not exists idx_rps_project_created
  on public.remedoo_pay_sessions (project_id, created_at);

-- One row per project/merchant that uses Remedoo Pay. The Worker
-- reads this with the service role; the admin console manages it.
create table if not exists public.remedoo_pay_projects (
  id text primary key,
  name text not null,
  vpa text,
  payee_name text,
  api_key text,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.remedoo_pay_projects enable row level security;

drop policy if exists "Admins manage remedoo pay projects"
  on public.remedoo_pay_projects;
create policy "Admins manage remedoo pay projects"
  on public.remedoo_pay_projects
  for all to authenticated
  using (exists (select 1 from public.user_roles ur
                 where ur.user_id = auth.uid() and ur.role = 'admin'))
  with check (exists (select 1 from public.user_roles ur
                      where ur.user_id = auth.uid() and ur.role = 'admin'));

-- The built-in project: the Remedoo app itself. Its UPI still comes
-- from app_config payment_gateways.youpi (unchanged); this row only
-- names it in the projects list.
insert into public.remedoo_pay_projects (id, name, enabled)
values ('remedoo', 'Remedoo App', true)
on conflict (id) do nothing;
