-- Remedoo admin panel backend: app config, provider applications, announcements.
-- Idempotent: safe to re-run.

-- 1. App-wide config key/value store (branding, fees, emergency numbers,
--    maintenance mode, etc.). Public read, admin write.
CREATE TABLE IF NOT EXISTS public.app_config (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "App config readable by everyone" ON public.app_config;
CREATE POLICY "App config readable by everyone"
  ON public.app_config FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage app config" ON public.app_config;
CREATE POLICY "Admins can manage app config"
  ON public.app_config FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Seed defaults (only where missing)
INSERT INTO public.app_config (key, value) VALUES
  ('branding', '{"app_name": "Remedoo", "tagline": "Healthcare, simplified"}'::jsonb),
  ('fees', '{"delivery_fee": 30, "free_delivery_threshold": 499, "currency": "INR"}'::jsonb),
  ('emergency', '{"numbers": [{"label": "Ambulance", "number": "108"}, {"label": "Emergency", "number": "112"}], "sos_message": "Emergency! I need help."}'::jsonb),
  ('maintenance', '{"enabled": false, "message": "Remedoo is under maintenance. Please check back soon."}'::jsonb),
  ('support', '{"phone": "", "email": "support@remedoo.app", "hours": "24x7"}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 2. Provider applications (onboarding). Applicants insert their own row;
--    admins read/update all.
CREATE TABLE IF NOT EXISTS public.provider_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  provider_type TEXT NOT NULL, -- doctor | hospital | lab | pharmacy
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  license_no TEXT NOT NULL,
  address TEXT NOT NULL,
  documents JSONB NOT NULL DEFAULT '[]'::jsonb, -- [{kind, name, size}]
  status TEXT NOT NULL DEFAULT 'pending', -- pending | approved | rejected
  decided_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.provider_applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Applicants can insert own application" ON public.provider_applications;
CREATE POLICY "Applicants can insert own application"
  ON public.provider_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Applicants can view own application" ON public.provider_applications;
CREATE POLICY "Applicants can view own application"
  ON public.provider_applications FOR SELECT
  USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Admins can manage applications" ON public.provider_applications;
CREATE POLICY "Admins can manage applications"
  ON public.provider_applications FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
CREATE INDEX IF NOT EXISTS idx_provider_applications_status
  ON public.provider_applications(status);

-- 3. Announcements (admin broadcast -> in-app). Public read, admin write.
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  audience TEXT NOT NULL DEFAULT 'all', -- all | users | providers
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Announcements readable by everyone" ON public.announcements;
CREATE POLICY "Announcements readable by everyone"
  ON public.announcements FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins can manage announcements" ON public.announcements;
CREATE POLICY "Admins can manage announcements"
  ON public.announcements FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- 4. Admin read access to profiles (user management)
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (has_role(auth.uid(), 'admin'::app_role));

-- 5. Admin access to operational tables
DROP POLICY IF EXISTS "Admins can manage all orders" ON public.orders;
CREATE POLICY "Admins can manage all orders"
  ON public.orders FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS "Admins can manage all appointments" ON public.appointments;
CREATE POLICY "Admins can manage all appointments"
  ON public.appointments FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS "Admins can manage emergency requests" ON public.emergency_requests;
CREATE POLICY "Admins can manage emergency requests"
  ON public.emergency_requests FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
DROP POLICY IF EXISTS "Admins can manage ambulances" ON public.ambulances;
CREATE POLICY "Admins can manage ambulances"
  ON public.ambulances FOR ALL
  USING (has_role(auth.uid(), 'admin'::app_role))
  WITH CHECK (has_role(auth.uid(), 'admin'::app_role));
